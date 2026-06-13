from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import traceback
from services.audio_service import process_lecture_audio

router = APIRouter()

@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(
    websocket: WebSocket,
    lecture_id: str,
    target_lang: str = "Korean"  # Flutter에서 ?target_lang=Korean 쿼리로 전달
):
    await websocket.accept()
    packet_count = 0
    total_bytes = 0

    try:
        while True:
            data = await websocket.receive_bytes()
            packet_count += 1
            total_bytes += len(data)

            if packet_count % 50 == 0:
                print(
                    f"[{lecture_id}] audio packets={packet_count}, "
                    f"total_bytes={total_bytes}, last_chunk={len(data)}"
                )

            await process_lecture_audio(data, lecture_id, target_lang)
    except WebSocketDisconnect:
        print(f"[{lecture_id}] 클라이언트 연결 종료")
    except Exception as e:
        print(f"WebSocket Error: {type(e).__name__} - {e}")
        traceback.print_exc()