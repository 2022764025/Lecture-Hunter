"""
<설명>
(1) 리소스 최적화: int8 양자화와 Semaphore(1)
    - compute_type="int8"와 asyncio.Semaphore(1)을 사용, 모델의 무게를 줄이고 
    세마포어(Semaphore)를 통해 동시에 여러 추론이 발생해 서버가 터지는 것을 막는 기능
(2) 지연 시간 제어: SILENCE_GAP 기반 트리거
    - SILENCE_GAP = 1.0 (1초 침묵 시 즉시 처리), 3~5초 이내 지연을 맞추는 핵심 로직이며, 
    교수님이 말을 멈추자마자 1초 만에 인식을 시작하므로, 실제 자막 노출까지 3초 내외면 충분하다.
(3) 무의미한 연산 차단: Silero VAD Gate
    - 소음만 있거나 아무 소리도 없을 때는 Whisper 모델을 아예 깨우지 않는다. GPU/CPU 자원을 아끼는 로직
(4) 맥락 유지와 단어 잘림 방지: OVERLAP_SIZE
    - OVERLAP_SIZE = 16000 (0.5초 오버랩), 오디오를 뚝뚝 끊어서 처리하면 단어가 잘릴 수 있는데, 
    이전 데이터의 끝부분을 살짝 겹쳐서 처리함으로써 문장의 연속성을 확보
(5) 논블로킹(Non-blocking) 후처리: asyncio.create_task
    - 번역, 임베딩, DB 저장을 별도 태스크로 던짐. STT 결과가 나오자마자 바로 다음 음성을 들을 준비를 하고, 
    시간이 걸리는 번역이나 DB 작업은 나중에 알아서 하라고 던져버린 기능 -> (실시간성 확보를 위한 선택)
"""

import numpy as np
import ollama
import asyncio
import time
import torch
import re # 정규표현식 추가
import json
from concurrent.futures import ThreadPoolExecutor
from core.config import settings
from core.database import get_supabase # 싱글턴 중앙화
from supabase import AsyncClient
from faster_whisper import WhisperModel
from services.translation_service import translation_engine
from silero_vad import load_silero_vad, get_speech_timestamps

# [1] 엔진 및 모델 초기화
# Medium 모델 + CPU 환경 최적화
stt_model = WhisperModel(
    settings.WHISPER_MODEL_SIZE,    # "medium"
    device=settings.WHISPER_DEVICE, # "auto"
    compute_type="int8"
)

# 추론용 스레드 풀 (메인 이벤트 루프 블로킹 방지)
executor = ThreadPoolExecutor(max_workers=2)

# [핵심 1] 세마포어: 동시 추론 개수를 제한하여 서버 안정성 확보
inference_semaphore = asyncio.Semaphore(1) 

ollama_client = ollama.AsyncClient()
vad_model = load_silero_vad()

# 강의별 리소스 관리
lecture_channels = {}
lecture_buffers = {}
last_received_times = {}

# [핵심 2] 민재님이 지정한 실시간 최적화 설정값
SAMPLE_RATE      = 16000
MIN_BUFFER_SIZE  = 160000   # 5초 (중간 모델 부하 감소 및 문맥 확보)
MAX_BUFFER_SIZE  = 320000   # 10초 (강제 처리 임계점)
SILENCE_GAP      = 1.0      # 1.0초 침묵 시 즉시 처리
OVERLAP_SIZE     = 16000    # 0.5초 오버랩 (단어 잘림 방지)

# Supabase Realtime 채널 관리
async def get_channel(client: AsyncClient, lecture_id: str):
    if lecture_id not in lecture_channels:
        channel = client.channel(f'lecture_{lecture_id}')
        # 비동기 구독 후 저장
        await channel.subscribe()
        lecture_channels[lecture_id] = channel
        print(f"[Realtime] {lecture_id} 채널 신규 구독 완료")
    return lecture_channels[lecture_id]

# Silero VAD 게이트
def silero_vad_gate(audio_np: np.ndarray) -> bool:
    """[핵심 3] VAD 게이트: 음성이 감지될 때만 Whisper 가동"""
    try:
        audio_tensor = torch.from_numpy(audio_np)
        return len(
            get_speech_timestamps(
                audio_tensor, vad_model, 
                sampling_rate=SAMPLE_RATE, 
                threshold=settings.VAD_THRESHOLD
            )
        ) > 0
    except: return True

# JSON 파싱 안전 함수 (신규 04.28 추가)
def safe_parse_glossary_json(raw: str) -> list:
    """
    Gemma-2 응답에서 JSON 배열만 안전하게 추출
    백틱, 단일 객체, 잘못된 형식 모두 방어
    """
    bt = chr(96) * 3
    raw = raw.replace(f"{bt}json", "").replace(bt, "").strip()

    start = raw.find("[")
    end = raw.rfind("]") + 1

    if start == -1 or end == 0:
        # 단일 객체로 왔을 경우 배열로 감싸기 시도
        start = raw.find("{")
        end = raw.rfind("}") + 1
        if start == -1 or end == 0:
            return []
        raw = f"[{raw[start:end]}]"
    else:
        raw = raw[start:end]

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return []

# 메인 STT 처리 함수
async def process_audio_and_broadcast(audio_data: bytes, lecture_id: str, target_lang: str) -> str:
    global lecture_buffers, last_received_times

    client = await get_supabase()

    if lecture_id not in lecture_buffers:
        lecture_buffers[lecture_id] = bytearray()

    current_time = time.time()
    silence_duration = current_time - last_received_times.get(lecture_id, current_time)
    last_received_times[lecture_id] = current_time
    lecture_buffers[lecture_id].extend(audio_data)

    # --- [트리거 체크] ---
    buffer_len = len(lecture_buffers[lecture_id])
    should_process = (
        (silence_duration > SILENCE_GAP and buffer_len > 32000) or
        buffer_len >= MIN_BUFFER_SIZE or
        buffer_len >= MAX_BUFFER_SIZE
    )
    if not should_process: return ""

    # 분석 데이터 복사 및 [핵심 4] 오버랩 적용
    process_data = bytes(lecture_buffers[lecture_id])
    lecture_buffers[lecture_id] = lecture_buffers[lecture_id][-OVERLAP_SIZE:] if buffer_len > OVERLAP_SIZE else bytearray()
    
    audio_np = np.frombuffer(process_data, dtype=np.int16).astype(np.float32) / 32768.0

    if not silero_vad_gate(audio_np): return ""

    initial_prompt = "실시간 자막 서비스입니다. 모든 용어를 문맥에 맞게 정확하게 기록하세요."

    # --- [핵심 5] 추론 로직 (에러 수정됨) ---
    def transcribe_sync():
        """스레드 안에서 실행될 동기 함수: 제너레이터를 리스트로 변환하여 안전하게 반환"""
        segments, info = stt_model.transcribe(
            audio_np, 
            beam_size=5, 
            initial_prompt=initial_prompt,
            language=None,
            vad_filter=True, 
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        return list(segments), info # 여기서 리스트로 변환해야 에러가 안 남

    async with inference_semaphore:
        loop = asyncio.get_event_loop()
        try:
            # result_segments(리스트)와 info(객체)를 정확히 언패킹함
            result_segments, info = await loop.run_in_executor(executor, transcribe_sync)
            
            # [추가] Whisper가 감지한 언어 코드(ko, en, ja 등) 추출
            detected_lang = info.language

            # 리스트화된 세그먼트에서 텍스트 추출
            original_text = "".join([s.text for s in result_segments if s.no_speech_prob < 0.6]).strip()
            
            if not original_text or any(p in original_text for p in ["구독", "좋아요"]): 
                return ""

            print(f"[{detected_lang}] 인식 성공: {original_text[:50]}...")

            # 후처리는 비동기로 던져서 STT 지연 최소화
            asyncio.create_task(handle_post_processing(client, lecture_id, original_text, target_lang, detected_lang))
            return original_text
            
        except Exception as e:
            print(f"[STT] 추론 내부 에러: {e}")
            return ""

# 전문 용어 추출 및 저장
async def extract_and_save_glossary(client: AsyncClient, lecture_id: str, text: str):
    """
    LLM을 이용해 전문 용어를 추출하고 정의하여 DB에 저장 (Non-blocking으로 호출됨)
    """
    if len(text) < 10:
        print("[Glossary] 문장이 너무 짧아 패스합니다.")
        return

    if not (re.search(r'[a-zA-Z]', text) or len(text) > 15):
        return

    print(f"[Glossary] 용어 추출 시도 중: {text[:20]}...")

    try:
        prompt = f"""
        당신은 AI 전공 용어 사전 편집자입니다.
        다음 문장에서 전공 용어를 추출하되, '용어'와 '정의'가 정확히 일치해야 합니다.
        반드시 JSON 리스트 형식으로만 답변하세요. 예: [{{"term": "용어", "definition": "설명"}}]
        
        문장: "{text}"
        """

        response = await ollama_client.generate(
            model=settings.LLM_MODEL,
            prompt=prompt,
            format='json'
        )

        # safe_parse_glossary_json 으로 통일 (구버전 json.loads 완전 제거)
        glossary_items = safe_parse_glossary_json(response['response'].strip())

        if not glossary_items:
            print("[Glossary] 추출된 용어 없음")
            return

        for item in glossary_items:
            if not (isinstance(item, dict) and 'term' in item):
                continue

            term_val = item['term']
            if isinstance(term_val, list):
                term_val = term_val[0] if term_val else "알 수 없음"
            term = str(term_val).strip()

            definition = item.get('definition', '핵심 전공 용어입니다.')
            if isinstance(definition, list):
                definition = " ".join(definition)

            await client.table("lecture_glossary").upsert({
                "lecture_id": lecture_id,
                "term": term,
                "definition": definition
            }, on_conflict="lecture_id, term").execute()

            print(f"[Glossary] '{term}' 저장 완료")

    except Exception as e:
        print(f"[Glossary] 에러 발생: {e}")

# 후처리 (번역 → DB 저장 → Realtime 브로드캐스트)
async def handle_post_processing(client, lecture_id: str, original: str, target_lang: str, source_lang: str):
    try:
        # --- [변경] 로그를 DB 저장 전으로 이동 ---
        print(f"\n[디버그] 인식된 텍스트: {original}")

        # 1. 번역 및 임베딩 (이 과정은 연결이 끊겨도 독립적으로 실행됨)
        translated = await translation_engine.translate(original, target_lang)
        embed = await ollama_client.embeddings(model='nomic-embed-text', prompt=original)
        
        # 2. DB 저장 (가장 중요: 연결과 상관없이 데이터는 남아야 함)
        await client.table("lecture_contents").insert({
            "lecture_id": lecture_id, 
            "original_text": original,
            "translated_text": translated, 
            "target_lang": target_lang,
            "source_lang": source_lang,
            "content_embedding": embed['embedding']
        }).execute()

        print(f"--- DB 저장 완료: {original[:20]}... ---")

        # [추가] 실시간 전문 용어 추출 태스크 실행
        # 비차단(Non-blocking)으로 실행하여 STT 흐름을 방해하지 않음
        asyncio.create_task(extract_and_save_glossary(client, lecture_id, original))

        # 3. 실시간 전송 (에러가 가장 많이 발생하는 구간)
        try:
            channel = await get_channel(client, lecture_id)
            # 전송 시도 시 에러가 나면 과감히 무시하고 넘어감
            await channel.send_broadcast('new_caption', {
                'original': original, 
                'translated': translated
            })
        except Exception as ws_err:
            # 연결이 이미 끊겼거나 타임아웃 난 경우 로그만 남김
            print(f"실시간 전송 건너뜀 (연결 종료됨): {ws_err}")

        # 로그 출력
        print("-" * 50)
        print(f"원본: {original[:40]}...")
        print(f"번역({target_lang}): {translated[:40]}...")
        print("-" * 50)

    except Exception as e:
        # 'Set of Tasks/Futures is empty' 같은 에러가 여기서 잡힘
        print(f"[STT] 후처리 에러 발생: {type(e).__name__} - {e}")