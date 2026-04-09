import os
from services.stt_service import process_audio_and_broadcast

async def process_lecture_audio(audio_data: bytes, lecture_id: str, target_lang: str = "Korean"):
    """
    이 함수는 그냥 통로입니다. 
    진짜 모델(잡음제거, STT, DB저장)은 stt_service가 다 합니다.
    이제 target_lang도 함께 배달합니다.
    """
    # stt_service 로직
    result = await process_audio_and_broadcast(audio_data, lecture_id, target_lang)
    return result