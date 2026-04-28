from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from core.connection_manager import manager
from services.stt_service import process_audio_and_broadcast

router = APIRouter()

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(websocket: WebSocket, lecture_id: str):
    await manager.connect(websocket, lecture_id)
    try:
        while True:
            data = await websocket.receive_bytes()
            # STT 처리 후 결과를 같은 강의실 전원에게 브로드캐스트
            await process_audio_and_broadcast(data, lecture_id, manager)
    except WebSocketDisconnect:
        await manager.disconnect(websocket, lecture_id)
    except Exception as e:
        print(f"WebSocket Error: {e}")
        await manager.disconnect(websocket, lecture_id)