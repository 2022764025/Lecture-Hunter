import numpy as np
import ollama
import asyncio
import time
from core.config import settings 
from supabase import create_async_client, AsyncClient
from faster_whisper import WhisperModel
from services.translation_service import translation_engine 

stt_model = WhisperModel("medium", device="cpu", compute_type="int8")

supabase_client: AsyncClient = None

# [핵심 수정 1] 전역 변수가 아닌 딕셔너리로 강의별 버퍼 관리
lecture_buffers = {}
last_received_times = {}

# 설정값 최적화
MIN_BUFFER_SIZE = 48000    # 1.5초 (medium 모델을 위한 최소 Context 확보)
MAX_BUFFER_SIZE = 160000   # 5초
SILENCE_GAP = 0.8          # [핵심 수정 3] 0.5에서 0.8로 상향 (문장 끊김 방지)

async def get_supabase() -> AsyncClient:
    global supabase_client
    if supabase_client is None:
        supabase_client = await create_async_client(settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY)
    return supabase_client

async def process_audio_and_broadcast(audio_data: bytes, lecture_id: str, target_lang: str):
    global lecture_buffers, last_received_times
    client = await get_supabase()
    
    # 해당 강의용 버퍼가 없으면 생성
    if lecture_id not in lecture_buffers:
        lecture_buffers[lecture_id] = bytearray()
    
    current_time = time.time()
    silence_duration = current_time - last_received_times.get(lecture_id, current_time)
    last_received_times[lecture_id] = current_time
    
    lecture_buffers[lecture_id].extend(audio_data)

    # 분석 시작 조건 체크
    should_process = False
    if silence_duration > SILENCE_GAP and len(lecture_buffers[lecture_id]) > 16000:
        should_process = True
    elif len(lecture_buffers[lecture_id]) >= MIN_BUFFER_SIZE:
        should_process = True

    if not should_process:
        return ""

    process_data = bytes(lecture_buffers[lecture_id])
    lecture_buffers[lecture_id] = bytearray()

    print(f"[Medium 분석] {len(process_data)} 바이트 (공백: {silence_duration:.2f}s)")

    audio_np = np.frombuffer(process_data, dtype=np.int16).astype(np.float32) / 32768.0
    
    # [핵심 수정 2] vad_filter 활성화로 환각 원천 차단
    segments, info = stt_model.transcribe(
        audio_np, 
        beam_size=5, 
        language=None,
        vad_filter=True, # Whisper 자체 VAD 가동
        vad_parameters=dict(min_silence_duration_ms=500),
        initial_prompt="전공 강의 실시간 자막입니다. This is a real-time lecture captioning service."
    )
    
    print(f"감지된 언어: {info.language} (확률: {info.language_probability:.2f})", flush=True)

    original_text = ""
    for segment in segments:
        # no_speech_prob가 너무 높으면(잡음일 확률이 높으면) 무시
        if segment.no_speech_prob < 0.6: 
            original_text += segment.text
            
    original_text = original_text.strip()
    
    # 환각 필터링 및 DB 저장 로직 (이하 동일)
    hallucination_phrases = ["이 영상은", "구독과 좋아요", "시청해 주셔서", "알림 설정"]
    if not original_text or any(phrase in original_text for phrase in hallucination_phrases):
        return ""

    translated_text = await translation_engine.translate(original_text, target_lang)
    
    # 임베딩 및 DB 저장
    try:
        embed_resp = ollama.embeddings(model='nomic-embed-text', prompt=original_text)
        await client.table("lecture_contents").insert({
            "lecture_id": lecture_id,
            "original_text": original_text,
            "translated_text": translated_text,
            "target_lang": target_lang,
            "content_embedding": embed_resp['embedding']
        }).execute()
    except Exception as e:
        print(f"오류: {e}")

    # 브로드캐스트
    channel = client.channel(f'lecture_{lecture_id}')
    await channel.subscribe() 
    await channel.send_broadcast('new_caption', {
        'original': original_text, 
        'translated': translated_text,
        'language': target_lang # 학생 앱에서 "아, 이건 영어 자막이구나"라고 알 수 있게 보냄
    })
    
    print(f"[최종] [{target_lang}] 결과: {original_text} -> {translated_text}")
    return original_text