"""
오디오 입력 통로.

WebSocket(api/v1/websocket.py)이 받은 PCM 청크를 STT 스트림 버퍼로 넘긴다.
나중에 "교수님 마이크 소리가 너무 지지직거려요" 같은 피드백이 오면,
stt_service로 넘기기 전에 여기서 잡음 제거(Denoising) 같은 전처리를 끼워 넣으면 된다.
"""

from services.stt_service import LectureStream


def process_lecture_audio(stream: LectureStream, conn_id: int, audio_data: bytes) -> bool:
    """
    16kHz / 16-bit / mono PCM 청크를 강의 스트림에 추가한다.
    실제 인식(VAD → Whisper → DB 저장)은 stt_service의 강의별 워커가 한다.
    스트림이 이미 끝났거나 이 연결이 더 최신 연결로 대체되었으면 False.
    """
    return stream.feed(conn_id, audio_data)
