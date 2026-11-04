"""
Ollama 공용 클라이언트.

서비스마다 따로 만들던 클라이언트를 하나로 모아 타임아웃과 keep_alive를 한 곳에서 관리한다.
타임아웃이 없으면 Ollama가 멈췄을 때 요청이 끝없이 기다린다.
"""

import asyncio
import heapq
from contextlib import asynccontextmanager
from typing import Any, Mapping, Optional, Sequence

import ollama

from core.config import settings

ollama_client = ollama.AsyncClient(
    host=settings.OLLAMA_HOST,
    timeout=settings.OLLAMA_TIMEOUT_SEC,
)


class PriorityLock:
    """
    대기자 중 우선순위가 높은(숫자가 작은) 쪽을 먼저 깨우는 asyncio 락.
    같은 우선순위끼리는 먼저 온 순서대로 깨운다.
    """

    def __init__(self):
        self._locked = False
        self._waiters: list[tuple[int, int, asyncio.Future]] = []
        self._seq = 0

    async def acquire(self, priority: int) -> None:
        if not self._locked and not self._waiters:
            self._locked = True
            return
        future = asyncio.get_running_loop().create_future()
        heapq.heappush(self._waiters, (priority, self._seq, future))
        self._seq += 1
        try:
            await future
        except asyncio.CancelledError:
            if future.done() and not future.cancelled():
                self.release()          # 락을 넘겨받은 직후 취소됨 → 다음 대기자에게 넘긴다
            raise

    def release(self) -> None:
        while self._waiters:
            _, _, future = heapq.heappop(self._waiters)
            if not future.done():
                future.set_result(True)  # 락을 바로 넘긴다 (_locked는 True 유지)
                return
        self._locked = False

    @asynccontextmanager
    async def hold(self, priority: int):
        await self.acquire(priority)
        try:
            yield
        finally:
            self.release()


# 자막마다 반복되는 작업(Whisper 추론, 자막 번역)을 번갈아 하나씩 돌리는 락.
# M1처럼 CPU와 GPU가 메모리를 같이 쓰는 기기에서는 LLM(GPU)이 도는 동안 Whisper(CPU)가 크게 느려졌다
# (실측: 번역이 없을 때 RTF 0.4 → 번역과 동시에 돌 때 RTF 1.1~1.7). 짧은 작업은 번갈아 돌리는 편이 전체적으로 빠르다.
# - Whisper가 번역보다 먼저 락을 받는다 (자막 지연이 번역 지연보다 중요).
# - 번역은 락을 최대 TRANSLATE_LOCK_SEC만 잡는다. Ollama가 다른 요청(용어 추출, 질문 답변 등) 때문에
#   늦어지면 락을 놓고 기다려서, 그동안 Whisper가 멈추지 않게 한다 (실측: 용어 추출 뒤에서 번역이 14초 대기).
# - 오래 걸리는 작업(용어 추출, 질문 답변, 요약, 화면 질문)은 이 락을 쓰지 않는다.
PRIORITY_STT = 0
PRIORITY_TRANSLATION = 1
TRANSLATE_LOCK_SEC = 4.0
pipeline_lock = PriorityLock()


async def run_bounded(coro, priority: int = PRIORITY_TRANSLATION, max_hold: float = TRANSLATE_LOCK_SEC):
    """pipeline_lock을 잡고 coro를 실행하되, max_hold초가 지나면 락을 놓고 결과만 기다린다."""
    task = asyncio.ensure_future(coro)
    async with pipeline_lock.hold(priority):
        await asyncio.wait({task}, timeout=max_hold)
    return await task


async def generate(
    prompt: str,
    *,
    model: Optional[str] = None,
    json_mode: bool = False,
    images: Optional[Sequence[bytes]] = None,
    options: Optional[Mapping[str, Any]] = None,
) -> str:
    kwargs: dict[str, Any] = {
        "model": model or settings.LLM_MODEL,
        "prompt": prompt,
        "keep_alive": settings.OLLAMA_KEEP_ALIVE,
    }
    if json_mode:
        kwargs["format"] = "json"
    if images:
        kwargs["images"] = list(images)
    if options:
        kwargs["options"] = dict(options)
    response = await ollama_client.generate(**kwargs)
    return (response["response"] or "").strip()


async def embed(text: str) -> list[float]:
    response = await ollama_client.embeddings(
        model=settings.EMBED_MODEL,
        prompt=text,
        keep_alive=settings.OLLAMA_KEEP_ALIVE,
    )
    return list(response["embedding"])


async def missing_models() -> list[str]:
    """설정된 LLM/임베딩/VLM 모델 중 Ollama에 설치되지 않은 것을 돌려준다."""
    listed = await ollama_client.list()
    installed = {m.model for m in listed.models}
    installed |= {name.split(":")[0] for name in installed if name.endswith(":latest")}

    missing = []
    for name in (settings.LLM_MODEL, settings.EMBED_MODEL, settings.VLM_MODEL):
        if name not in installed and f"{name}:latest" not in installed:
            missing.append(name)
    return missing
