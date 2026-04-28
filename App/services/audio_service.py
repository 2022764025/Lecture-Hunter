"""
앞으로의 활용 방안 (빌드업)
나중에 우리가 추가하기로 한 '3가지 신규 기능' 중에서, 오디오와 관련된 기능이 이 통로를 거치게 된다.

잡음 제거(Denoising): 나중에 "교수님 마이크 소리가 너무 지지직거려요"라는 피드백이 오면, 
                    stt_service로 넘기기 전에 여기서 잡음 제거 함수를 살짝 끼워 넣을 수 있는 '전략적 요충지'이다.
"""


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