import numpy as np
import ollama
import asyncio
import time
import torch
from concurrent.futures import ThreadPoolExecutor
from core.config import settings
from supabase import create_async_client, AsyncClient
from faster_whisper import WhisperModel
from services.translation_service import translation_engine
from silero_vad import load_silero_vad, get_speech_timestamps

# [1] 엔진 및 모델 초기화
# Medium 모델 + CPU 환경 최적화
stt_model = WhisperModel("medium", device="auto", compute_type="int8")

# 추론용 스레드 풀 (메인 이벤트 루프 블로킹 방지)
executor = ThreadPoolExecutor(max_workers=2)

# [핵심 1] 세마포어: 동시 추론 개수를 제한하여 서버 안정성 확보
inference_semaphore = asyncio.Semaphore(1) 

ollama_client = ollama.AsyncClient()
vad_model = load_silero_vad()
supabase_client: AsyncClient = None

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

async def get_supabase() -> AsyncClient:
    global supabase_client
    if supabase_client is None:
        supabase_client = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
    return supabase_client

async def get_channel(client: AsyncClient, lecture_id: str):
    global lecture_channels
    if lecture_id not in lecture_channels:
        channel = client.channel(f'lecture_{lecture_id}')
        # 비동기 구독 후 저장
        await channel.subscribe()
        lecture_channels[lecture_id] = channel
        print(f"[Realtime] {lecture_id} 채널 신규 구독 완료")
    return lecture_channels[lecture_id]

def silero_vad_gate(audio_np: np.ndarray) -> bool:
    """[핵심 3] VAD 게이트: 음성이 감지될 때만 Whisper 가동"""
    try:
        audio_tensor = torch.from_numpy(audio_np)
        return len(get_speech_timestamps(audio_tensor, vad_model, sampling_rate=SAMPLE_RATE, threshold=0.3)) > 0
    except: return True

async def process_audio_and_broadcast(audio_data: bytes, lecture_id: str, target_lang: str):
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
    should_process = False

    if silence_duration > SILENCE_GAP and buffer_len > 32000:
        should_process = True
    elif buffer_len >= MIN_BUFFER_SIZE:
        should_process = True
    elif buffer_len >= MAX_BUFFER_SIZE:
        should_process = True

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
            
            # 🔥 [추가] Whisper가 감지한 언어 코드(ko, en, ja 등) 추출
            detected_lang = info.language

            # 리스트화된 세그먼트에서 텍스트 추출
            original_text = "".join([s.text for s in result_segments if s.no_speech_prob < 0.6]).strip()
            
            if not original_text or any(p in original_text for p in ["구독", "좋아요"]): 
                return ""

            print(f"[{info.language}] 인식 성공: {original_text[:50]}...")

            # 후처리는 비동기로 던져서 STT 지연 최소화
            asyncio.create_task(handle_post_processing(client, lecture_id, original_text, target_lang, detected_lang))
            return original_text
            
        except Exception as e:
            print(f"추론 내부 에러: {e}")
            return ""

async def handle_post_processing(client, lecture_id, original, target_lang, source_lang):
    try:
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
        print(f"후처리 단계 에러 무시: {e}")