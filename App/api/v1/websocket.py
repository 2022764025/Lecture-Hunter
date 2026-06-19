from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import asyncio
from services.audio_service import process_lecture_audio
from services.stt_service import lecture_buffers, last_received_times

router = APIRouter()

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(
    websocket: WebSocket,
    lecture_id: str,
    target_lang: str = "Korean"  # Flutter에서 ?target_lang=Korean 쿼리로 전달
):
    await websocket.accept()
    print(f"[WebSocket] {lecture_id} 강의 실시간 오디오 스트림 연결 성공")

    try:
        while True:
            data = await websocket.receive_bytes()

            # [최적화] 오디오 처리를 비차단(Non-blocking) 태스크로 생성하여 
            # 웹소켓이 끊김 없이 다음 오디오 패킷을 즉시 수신하도록 보장 (자막 싱크 밀림 방지)
            asyncio.create_task(process_lecture_audio(data, lecture_id, target_lang))

    except WebSocketDisconnect:
        print(f"[WebSocket] {lecture_id} 클라이언트 정상 연결 종료")
    except Exception as e:
        print(f"[WebSocket] {lecture_id} 에러 발생: {e}")
    finally:
        # [메모리 최적화] 연결 종료 시 해당 강의의 찌꺼기 버퍼 자원 소거
        if lecture_id in lecture_buffers:
            del lecture_buffers[lecture_id]
        if lecture_id in last_received_times:
            del last_received_times[lecture_id]
        print(f"[WebSocket] {lecture_id} 메모리 버퍼 자원 정리 완료")