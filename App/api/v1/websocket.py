from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from services.audio_service import process_lecture_audio

router = APIRouter()

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(
    websocket: WebSocket,
    lecture_id: str,
    target_lang: str = "Korean"  # Flutter에서 ?target_lang=Korean 쿼리로 전달
):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_bytes()
            await process_lecture_audio(data, lecture_id, target_lang)
    except WebSocketDisconnect:
        print(f"[{lecture_id}] 클라이언트 연결 종료")
    except Exception as e:
        print(f"WebSocket Error: {e}")