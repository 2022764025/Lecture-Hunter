from fastapi import WebSocket
from collections import defaultdict
import asyncio

class ConnectionManager:
    def __init__(self):
        # {lecture_id: [websocket, websocket, ...]}
        self._rooms: dict[str, list[WebSocket]] = defaultdict(list)
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, lecture_id: str):
        await websocket.accept()
        async with self._lock:
            self._rooms[lecture_id].append(websocket)
        print(f"[+] 접속: lecture={lecture_id}, 현재 {len(self._rooms[lecture_id])}명")

    async def disconnect(self, websocket: WebSocket, lecture_id: str):
        async with self._lock:
            self._rooms[lecture_id].discard(websocket)  # 없어도 에러 안 남
            if not self._rooms[lecture_id]:
                del self._rooms[lecture_id]  # 빈 방 정리
        print(f"[-] 퇴장: lecture={lecture_id}")

    async def broadcast(self, lecture_id: str, message: dict):
        """
        한 강의실의 모든 접속자에게 동시 송신
        실패한 클라이언트는 자동으로 방에서 제거
        """
        if lecture_id not in self._rooms:
            return

        async with self._lock:
            targets = list(self._rooms[lecture_id])  # 복사본으로 순회

        # 전체 동시 발송 (asyncio.gather)
        results = await asyncio.gather(
            *[self._send(ws, message) for ws in targets],
            return_exceptions=True
        )

        # 실패한 연결 정리
        dead = [ws for ws, result in zip(targets, results) if isinstance(result, Exception)]
        if dead:
            async with self._lock:
                for ws in dead:
                    self._rooms[lecture_id].discard(ws)

    async def _send(self, websocket: WebSocket, message: dict):
        await websocket.send_json(message)

    def get_count(self, lecture_id: str) -> int:
        return len(self._rooms.get(lecture_id, []))


# 싱글턴으로 앱 전체에서 공유
manager = ConnectionManager()