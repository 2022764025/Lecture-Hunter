import os
from services.stt_service import process_audio_and_broadcast

async def process_lecture_audio(audio_data: bytes, lecture_id: str):
    """
    이 함수는 그냥 통로이다. 
    진짜 모델(잡음제거, STT, DB저장)은 stt_service가 다 한다.
    """
    # stt_service 로직
    result = await process_audio_and_broadcast(audio_data, lecture_id)
    return result