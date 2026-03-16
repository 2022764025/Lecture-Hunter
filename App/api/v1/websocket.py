from fastapi import APIRouter, WebSocket
from services.stt_service import process_audio_and_broadcast

router = APIRouter()

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(websocket: WebSocket, lecture_id: str):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_bytes()
            await process_audio_and_broadcast(data, lecture_id)
    except Exception as e:
        print(f"WebSocket Error: {e}")