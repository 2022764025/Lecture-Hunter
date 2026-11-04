"""
오디오 WebSocket 연결 확인용 테스트 클라이언트 (모델 추론 없이 연결만 확인)

사용법 (App 폴더에서, 서버 실행 중):
    python api/v1/mock_client.py
확인 항목: 연결 → ready 메시지 → ping/pong → 무음 1초 전송 → 정상 종료
"""

import asyncio
import json

import websockets

URI = "ws://127.0.0.1:8000/ws/audio/demo-lecture?target_lang=Korean"


async def test_connection():
    print(f"[테스트] {URI} 연결 시도 중...")
    async with websockets.connect(URI) as ws:
        ready = json.loads(await asyncio.wait_for(ws.recv(), 10))
        print(f"[테스트] 서버 준비 완료: {ready}")

        await ws.send("ping")
        pong = json.loads(await asyncio.wait_for(ws.recv(), 5))
        print(f"[테스트] heartbeat 응답: {pong}")

        silence = b"\x00\x00" * 1600          # 16kHz mono PCM 100ms
        for _ in range(10):
            await ws.send(silence)
            await asyncio.sleep(0.1)
        print("[테스트] 무음 1초 전송 완료, 연결 종료")


if __name__ == "__main__":
    asyncio.run(test_connection())
