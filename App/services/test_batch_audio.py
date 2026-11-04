"""
오디오 파일을 실시간 속도로 WebSocket에 흘려보내 자막 파이프라인을 직접 확인하는 스크립트.

사용법 (App 폴더에서, 백엔드 서버와 Ollama가 켜진 상태):
    python services/test_batch_audio.py ../test_samples/test_batch_es.mp3
    python services/test_batch_audio.py 강의.mp3 --lecture-id my-test --lang English --speed 2

- 어떤 형식이든 ffmpeg로 16kHz / 16-bit / mono PCM으로 바꿔 100ms 단위로 보낸다 (크롬 확장과 같은 조건).
- 결과 자막은 서버 로그와 Supabase lecture_contents 테이블에서 확인한다.
"""

import argparse
import asyncio
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

import websockets

SAMPLE_RATE = 16000
CHUNK_BYTES = 3200  # 100ms


def to_pcm16k(path: Path) -> bytes:
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg가 필요합니다: brew install ffmpeg")
    return subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1"],
        capture_output=True, check=True,
    ).stdout


async def main(args):
    path = Path(args.file).expanduser()
    if not path.exists():
        sys.exit(f"파일이 없습니다: {path}")
    pcm = to_pcm16k(path) + b"\x00\x00" * SAMPLE_RATE * 2   # 끝에 2초 무음
    url = f"{args.server}/ws/audio/{args.lecture_id}?target_lang={args.lang}"
    print(f"{path.name}: {len(pcm) / 2 / SAMPLE_RATE:.1f}초 → {url}")

    async with websockets.connect(url, max_size=None) as ws:
        ready = json.loads(await asyncio.wait_for(ws.recv(), 10))
        print(f"서버 준비: {ready}")
        t0 = time.perf_counter()
        for n, i in enumerate(range(0, len(pcm), CHUNK_BYTES), 1):
            await ws.send(pcm[i:i + CHUNK_BYTES])
            delay = t0 + n * 0.1 / args.speed - time.perf_counter()
            if delay > 0:
                await asyncio.sleep(delay)
            if n % 100 == 0:
                print(f"  전송 {n / 10:.0f}초 / {len(pcm) / 2 / SAMPLE_RATE:.0f}초")
    print("전송 완료. 남은 오디오는 서버가 마저 처리합니다 (서버 로그 확인).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("file")
    parser.add_argument("--server", default="ws://127.0.0.1:8000")
    parser.add_argument("--lecture-id", default=f"file-test-{int(time.time())}")
    parser.add_argument("--lang", default="Korean")
    parser.add_argument("--speed", type=float, default=1.0, help="전송 속도 배율 (1.0 = 실시간)")
    asyncio.run(main(parser.parse_args()))
