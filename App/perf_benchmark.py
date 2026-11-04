#!/usr/bin/env python3
"""
LiveLectureAI 성능 측정 스크립트 (보고서 7번 "주요 성능 지표" 실측용)

측정 항목
  1) latency : 실시간 자막 E2E 지연 (문장 종료 시각 → DB에 자막 행이 보인 시각)
  2) wer     : STT 정확도 (WER / CER)
  3) api     : REST API 응답시간 (DB 전용 / LLM 포함 분리)
  4) memory  : 장시간 연속 스트리밍 시 백엔드 메모리(RSS) 추이
  5) report  : 위 결과(JSON)를 모아 보고서용 마크다운 표 생성

사전 준비
  - 백엔드 서버 실행:  cd App && uvicorn main:app --host 0.0.0.0 --port 8000
    (메모리 측정 시 --reload 없이 실행해야 프로세스가 하나로 고정됩니다)
  - Ollama 실행 (gemma2:2b, nomic-embed-text)
  - pip install websockets==15.0.1 httpx==0.28.1 psutil==7.0.0
    (그래프가 필요하면 matplotlib, 이미 requirements.txt에 포함)

실행 예시 (App 폴더에서)
  python perf_benchmark.py make-audio                 # macOS TTS로 테스트 오디오 + 정답 스크립트 생성
  python perf_benchmark.py latency                    # E2E 지연 측정
  python perf_benchmark.py wer                        # TTS 오디오로 WER/CER (빠른 확인용)
  python perf_benchmark.py wer --audio lecture.mp3 --reference reference.txt   # 실제 강의 (보고서용)
  python perf_benchmark.py api                        # 직전 latency 테스트의 lecture_id로 API 측정
  python perf_benchmark.py memory --minutes 60        # 1시간 연속 스트리밍 + 메모리 기록
  python perf_benchmark.py report                     # bench_results/report.md 생성

결과는 모두 App/bench_results/ 에 JSON/CSV로 저장됩니다.
"""

from __future__ import annotations

import argparse
import array
import asyncio
import csv
import json
import math
import os
import platform
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import wave
from difflib import SequenceMatcher
from pathlib import Path

try:
    import httpx
    import websockets
except ImportError:
    sys.exit("필수 패키지가 없습니다: pip install websockets==15.0.1 httpx==0.28.1 psutil==7.0.0")

HERE = Path(__file__).resolve().parent
RESULTS = HERE / "bench_results"
SR = 16000
CHUNK_SEC = 0.1                       # Extension/YouTube 경로와 동일한 100ms 청크
CHUNK_BYTES = int(SR * CHUNK_SEC) * 2  # int16 mono → 3200 bytes

# 테스트 문장: 숫자/영어/필터 단어("구독", "좋아요")를 피해서 텍스트 매칭이 안정적이도록 구성
TEST_SENTENCES = [
    "오늘 수업에서는 인공신경망의 기본 구조에 대해 알아보겠습니다",
    "신경망은 입력층과 은닉층 그리고 출력층으로 구성됩니다",
    "각 층의 뉴런은 가중치와 편향을 가지고 있습니다",
    "활성화 함수는 신경망에 비선형성을 부여하는 역할을 합니다",
    "대표적인 활성화 함수로는 시그모이드와 렐루가 있습니다",
    "학습 과정에서는 손실 함수를 최소화하는 방향으로 가중치를 조정합니다",
    "이때 사용하는 방법이 바로 경사 하강법입니다",
    "역전파 알고리즘은 출력층의 오차를 입력층 방향으로 전달합니다",
    "학습률이 너무 크면 최적점을 지나쳐 버릴 수 있습니다",
    "반대로 학습률이 너무 작으면 학습 속도가 매우 느려집니다",
    "과적합은 모델이 훈련 데이터에만 지나치게 맞춰진 상태를 말합니다",
    "과적합을 막기 위해 드롭아웃이라는 기법을 자주 사용합니다",
    "검증 데이터는 모델의 일반화 성능을 확인하는 데 쓰입니다",
    "합성곱 신경망은 이미지 처리 분야에서 널리 활용됩니다",
    "합성곱 층은 필터를 이용해 이미지의 특징을 추출합니다",
    "풀링 층은 특징 맵의 크기를 줄여 연산량을 감소시킵니다",
    "순환 신경망은 순서가 있는 데이터를 처리하는 데 적합합니다",
    "트랜스포머는 셀프 어텐션 메커니즘을 핵심으로 사용합니다",
    "어텐션은 문장 안에서 중요한 단어에 더 집중하도록 도와줍니다",
    "사전 학습된 모델을 활용하면 적은 데이터로도 좋은 성능을 얻습니다",
    "이러한 방식을 전이 학습이라고 부릅니다",
    "모델을 평가할 때는 정확도뿐 아니라 재현율도 함께 살펴봐야 합니다",
    "다음 시간에는 실제 코드를 작성하면서 실습을 진행하겠습니다",
    "오늘 배운 내용은 꼭 복습해 주시기 바랍니다",
]


# ───────────────────────── 공통 유틸 ─────────────────────────

def load_env() -> dict:
    """App/.env 를 읽어서 dict로 반환 (값은 출력하지 않음). OS 환경변수가 우선."""
    env = {}
    env_path = HERE / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            v = v.strip()
            if v[:1] in ("'", '"'):
                v = v[1:].split(v[0], 1)[0]          # 따옴표 값
            else:
                v = re.split(r"\s+#", v, 1)[0].strip()  # 인라인 주석 제거 (python-dotenv와 동일)
            env[k.strip()] = v
    for k in ("SUPABASE_URL", "SUPABASE_ANON_KEY", "WHISPER_MODEL_SIZE", "WHISPER_DEVICE", "LLM_MODEL"):
        if os.environ.get(k):
            env[k] = os.environ[k]
    return env


def summarize(values: list[float]) -> dict:
    """평균 / 표준편차 / p50 / p95 / p99 / min / max"""
    if not values:
        return {"n": 0}
    s = sorted(values)

    def pct(p: float) -> float:
        k = (len(s) - 1) * p / 100
        f = math.floor(k)
        c = min(f + 1, len(s) - 1)
        return s[f] + (s[c] - s[f]) * (k - f)

    return {
        "n": len(s),
        "mean": statistics.fmean(s),
        "std": statistics.pstdev(s),
        "p50": pct(50),
        "p95": pct(95),
        "p99": pct(99),
        "min": s[0],
        "max": s[-1],
    }


def save_json(name: str, data: dict) -> Path:
    RESULTS.mkdir(exist_ok=True)
    path = RESULTS / f"{name}.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def load_json(name: str) -> dict | None:
    path = RESULTS / f"{name}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def make_lecture_id(prefix: str) -> str:
    lid = f"{prefix}-{int(time.time())}"
    # websocket.py 는 길이 11인 ID를 유튜브 영상 ID로 간주하므로 피한다
    assert len(lid) != 11
    return lid


def env_info(env: dict) -> dict:
    chip = ram_gb = None
    if platform.system() == "Darwin":
        try:
            chip = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                                  capture_output=True, text=True).stdout.strip()
            ram_gb = int(subprocess.run(["sysctl", "-n", "hw.memsize"],
                                        capture_output=True, text=True).stdout.strip()) / 1024**3
        except Exception:
            pass
    return {
        "platform": platform.platform(),
        "chip": chip or platform.processor(),
        "ram_gb": round(ram_gb, 1) if ram_gb else None,
        "whisper_model": env.get("WHISPER_MODEL_SIZE", "medium"),
        "whisper_device": env.get("WHISPER_DEVICE", "auto"),
        "whisper_compute_type": "int8",
        "llm_model": env.get("LLM_MODEL", "gemma2:2b"),
        "measured_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }


# ───────────────────────── 오디오 ─────────────────────────

def require_ffmpeg():
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg 가 필요합니다: brew install ffmpeg")


def to_pcm16k(path: Path) -> bytes:
    """임의 오디오/영상 파일 → 16kHz mono int16 PCM bytes"""
    require_ffmpeg()
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(SR), "pipe:1"],
        capture_output=True, check=True,
    )
    return out.stdout


def tts_pcm(text: str, voice: str) -> bytes:
    with tempfile.TemporaryDirectory() as td:
        aiff = Path(td) / "s.aiff"
        subprocess.run(["say", "-v", voice, "-o", str(aiff), text], check=True)
        return to_pcm16k(aiff)


def speech_bounds(pcm: bytes, thresh: int = 600, frame: int = 160) -> tuple[int, int]:
    """10ms 프레임 단위로 실제 음성이 시작/끝나는 샘플 인덱스 탐지"""
    samples = array.array("h", pcm)
    first = last = None
    for i in range(0, len(samples), frame):
        seg = samples[i:i + frame]
        if seg and max(abs(min(seg)), abs(max(seg))) > thresh:
            if first is None:
                first = i
            last = i + len(seg)
    if first is None:
        return 0, len(samples)
    return first, last


def silence(sec: float) -> bytes:
    return b"\x00\x00" * int(SR * sec)


def write_wav(path: Path, pcm: bytes):
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm)


def read_wav_pcm(path: Path) -> bytes:
    with wave.open(str(path), "rb") as wf:
        if wf.getframerate() == SR and wf.getnchannels() == 1 and wf.getsampwidth() == 2:
            return wf.readframes(wf.getnframes())
    return to_pcm16k(path)


def load_test_audio() -> tuple[bytes, dict]:
    wav = RESULTS / "test_sentences.wav"
    meta = RESULTS / "test_sentences.json"
    if not wav.exists() or not meta.exists():
        sys.exit("테스트 오디오가 없습니다. 먼저 `python perf_benchmark.py make-audio` 를 실행하세요.")
    return read_wav_pcm(wav), json.loads(meta.read_text(encoding="utf-8"))


# ───────────────────────── 서버 통신 ─────────────────────────

def ws_url(server: str, lecture_id: str, lang: str) -> str:
    base = server.replace("https://", "wss://").replace("http://", "ws://").rstrip("/")
    return f"{base}/ws/audio/{lecture_id}?target_lang={lang}"


async def preflight(server: str):
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            r = await c.get(f"{server}/health")
            r.raise_for_status()
    except Exception as e:
        sys.exit(f"백엔드 서버에 연결할 수 없습니다 ({server}/health): {e}")


async def stream_realtime(ws, pcm: bytes, speed: float = 1.0, t0: float | None = None) -> float:
    """
    실제 마이크 캡처처럼 전송: 오디오 구간 [τ, τ+0.1) 이 다 녹음된 시점(t0+τ+0.1)에 청크 전송.
    → 오디오 시각 τ 와 벽시계 t0+τ 가 1:1로 대응한다.
    """
    t0 = time.perf_counter() if t0 is None else t0
    n = 0
    for i in range(0, len(pcm), CHUNK_BYTES):
        n += 1
        delay = t0 + n * CHUNK_SEC / speed - time.perf_counter()
        if delay > 0:
            await asyncio.sleep(delay)
        await ws.send(pcm[i:i + CHUNK_BYTES])
    return t0


class CaptionPoller:
    """Supabase REST(PostgREST)로 lecture_contents 를 주기적으로 조회해 새 행이 '보인 시각'을 기록"""

    def __init__(self, env: dict, lecture_id: str, interval: float = 0.2):
        url, key = env.get("SUPABASE_URL"), env.get("SUPABASE_ANON_KEY")
        if not url or not key:
            sys.exit("App/.env 에 SUPABASE_URL / SUPABASE_ANON_KEY 가 필요합니다.")
        self.base = url.rstrip("/") + "/rest/v1"
        self.headers = {"apikey": key, "Authorization": f"Bearer {key}"}
        self.lecture_id = lecture_id
        self.interval = interval
        self.seen: dict = {}            # id -> row
        self.captions: list[dict] = []  # {"t": 스트림 시작 기준 초, "text": ..., "translated": ...}
        self.last_new_at = time.perf_counter()
        self.errors = 0

    async def fetch_all(self, client: httpx.AsyncClient) -> list[dict]:
        r = await client.get(
            f"{self.base}/lecture_contents",
            params={
                "select": "id,original_text,translated_text,created_at",
                "lecture_id": f"eq.{self.lecture_id}",
                "order": "created_at.asc",
            },
            headers=self.headers,
        )
        r.raise_for_status()
        return r.json()

    async def run(self, t0: float, stop: asyncio.Event):
        async with httpx.AsyncClient(timeout=10) as client:
            while not stop.is_set():
                try:
                    rows = await self.fetch_all(client)
                    t_seen = time.perf_counter() - t0
                    for row in rows:
                        if row["id"] not in self.seen:
                            self.seen[row["id"]] = row
                            self.captions.append({
                                "t": t_seen,
                                "text": row.get("original_text") or "",
                                "translated": row.get("translated_text") or "",
                            })
                            self.last_new_at = time.perf_counter()
                            print(f"  [{t_seen:7.2f}s] 자막 도착: {(row.get('original_text') or '')[:40]}")
                except Exception as e:
                    self.errors += 1
                    if self.errors <= 3:
                        print(f"  [poll 에러] {e}")
                await asyncio.sleep(self.interval)


async def wait_until_idle(poller: CaptionPoller, idle: float, max_wait: float):
    start = time.perf_counter()
    while time.perf_counter() - start < max_wait:
        if time.perf_counter() - poller.last_new_at > idle and time.perf_counter() - start > idle:
            return
        await asyncio.sleep(0.5)


async def stream_and_collect(args, env, pcm: bytes, lecture_id: str) -> tuple[CaptionPoller, float]:
    """오디오를 실시간 속도로 흘리면서 자막을 수집. 끝나면 꼬리 무음으로 버퍼를 비우고 idle까지 대기."""
    poller = CaptionPoller(env, lecture_id, args.poll_interval)
    stop = asyncio.Event()
    url = ws_url(args.server, lecture_id, args.lang)
    print(f"WebSocket 연결: {url}")
    async with websockets.connect(url, max_size=None, ping_interval=20, ping_timeout=60) as ws:
        await asyncio.sleep(1.0)  # 서버 측 lectures upsert 완료 대기
        t0 = time.perf_counter()
        poll_task = asyncio.create_task(poller.run(t0, stop))
        audio_sec = len(pcm) / 2 / SR
        print(f"오디오 {audio_sec:.1f}초 전송 시작 (x{args.speed})")
        await stream_realtime(ws, pcm, args.speed, t0)
        # 서버는 '청크 도착'으로만 트리거되므로, 남은 버퍼를 비우기 위해 무음을 계속 보낸다
        # (실제 Extension 도 무음 구간에 계속 전송하므로 동일 조건)
        await stream_realtime(ws, silence(args.tail_silence), args.speed)
        print(f"전송 완료. 자막이 {args.idle:.0f}초간 더 안 들어올 때까지 대기 (최대 {args.max_wait:.0f}초)...")
        await wait_until_idle(poller, args.idle, args.max_wait)
        stop.set()
        await poll_task
    return poller, t0


# ───────────────────────── 1. make-audio ─────────────────────────

def cmd_make_audio(args):
    if not shutil.which("say"):
        sys.exit("macOS `say` 명령이 필요합니다. 다른 OS라면 직접 녹음한 wav + 문장 종료 시각 JSON을 준비하세요.")
    RESULTS.mkdir(exist_ok=True)
    pcm = bytearray(silence(1.0))
    sentences = []
    for i, text in enumerate(TEST_SENTENCES, 1):
        raw = tts_pcm(text, args.voice)
        s, e = speech_bounds(raw)
        pad = int(SR * 0.05)
        clip = raw[max(0, s - pad) * 2:min(len(raw) // 2, e + pad) * 2]
        cs, ce = speech_bounds(clip)
        offset = len(pcm) // 2
        pcm += clip
        sentences.append({
            "idx": i,
            "text": text,
            "start": round((offset + cs) / SR, 3),
            "end": round((offset + ce) / SR, 3),   # 실제 음성이 끝나는 시각
        })
        pcm += silence(args.gap)
        print(f"  {i:2d}/{len(TEST_SENTENCES)} {sentences[-1]['start']:6.2f}~{sentences[-1]['end']:6.2f}s  {text}")

    write_wav(RESULTS / "test_sentences.wav", bytes(pcm))
    meta = {"voice": args.voice, "gap_sec": args.gap, "duration": len(pcm) / 2 / SR, "sentences": sentences}
    (RESULTS / "test_sentences.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    (RESULTS / "test_reference.txt").write_text(" ".join(TEST_SENTENCES), encoding="utf-8")
    print(f"\n생성 완료: {RESULTS/'test_sentences.wav'} ({meta['duration']:.1f}초, {len(sentences)}문장)")


# ───────────────────────── 2. latency ─────────────────────────

def norm_nospace(s: str) -> str:
    return re.sub(r"[\W_]+", "", s.lower())


def match_captions(sentences: list[dict], captions: list[dict]) -> list[dict]:
    """
    문장별로 '문장 끝부분(꼬리)이 포함된 첫 자막'을 찾아 지연을 계산.
    텍스트로 못 찾으면 문장 종료 이후 첫 자막으로 대체(method=time)하고 결과에 표시.
    """
    rows = []
    cursor = 0  # 자막은 시간순으로 생성되므로, 이전 문장이 매칭된 자막 이전으로는 되돌아가지 않는다
    for s in sentences:
        tail = norm_nospace(s["text"])[-10:]
        hit, method = None, None
        for ci in range(cursor, len(captions)):
            c = captions[ci]
            if c["t"] < s["end"]:
                continue
            ct = norm_nospace(c["text"])
            m = SequenceMatcher(None, tail, ct, autojunk=False).find_longest_match(0, len(tail), 0, len(ct))
            if tail and m.size / len(tail) >= 0.6:
                hit, method, cursor = c, "text", ci
                break
        if hit is None:
            after = [c for c in captions[cursor:] if c["t"] >= s["end"]]
            if after:
                hit, method = after[0], "time"
        rows.append({
            "idx": s["idx"],
            "sentence": s["text"],
            "sentence_end": s["end"],
            "caption_seen": round(hit["t"], 3) if hit else None,
            "latency": round(hit["t"] - s["end"], 3) if hit else None,
            "method": method or "missing",
            "caption": hit["text"] if hit else None,
        })
    return rows


async def cmd_latency(args):
    env = load_env()
    await preflight(args.server)
    if args.speed != 1.0:
        print("※ 지연 측정은 실시간(x1.0) 전송이 전제라 --speed 를 무시합니다.")
        args.speed = 1.0
    pcm, meta = load_test_audio()
    lecture_id = args.lecture_id or make_lecture_id("bench-lat")
    poller, _ = await stream_and_collect(args, env, pcm, lecture_id)

    rows = match_captions(meta["sentences"], poller.captions)
    lat_all = [r["latency"] for r in rows if r["latency"] is not None]
    lat_text = [r["latency"] for r in rows if r["method"] == "text"]
    stats_all, stats_text = summarize(lat_all), summarize(lat_text)

    print("\n문장별 지연")
    print(f"{'#':>3} {'종료(s)':>8} {'표시(s)':>8} {'지연(s)':>8}  매칭   문장")
    for r in rows:
        lat = f"{r['latency']:8.2f}" if r["latency"] is not None else "       -"
        seen = f"{r['caption_seen']:8.2f}" if r["caption_seen"] is not None else "       -"
        print(f"{r['idx']:>3} {r['sentence_end']:8.2f} {seen} {lat}  {r['method']:<6} {r['sentence'][:24]}")

    def line(name, st):
        if not st.get("n"):
            return f"{name}: 데이터 없음"
        return (f"{name}: n={st['n']}  평균 {st['mean']:.2f}s  p50 {st['p50']:.2f}s  "
                f"p95 {st['p95']:.2f}s  max {st['max']:.2f}s")

    missing = sum(r["method"] == "missing" for r in rows)
    print("\n=== E2E 지연 결과 (문장 종료 → DB 자막 행 조회 가능 시점) ===")
    print(line("텍스트 매칭 문장", stats_text))
    print(line("전체(시간 기반 포함)", stats_all))
    print(f"자막 행 수: {len(poller.captions)} / 누락 문장: {missing} / 폴링 해상도: {args.poll_interval}s")
    print("※ Flutter 1초 폴링을 쓰면 화면 표시까지 평균 +0.5초(최대 +1초)가 추가됩니다.")

    path = save_json("latency", {
        "env": env_info(env),
        "lecture_id": lecture_id,
        "audio": {"file": "test_sentences.wav", "duration": meta["duration"], "sentences": len(meta["sentences"])},
        "poll_interval": args.poll_interval,
        "stats_text_matched": stats_text,
        "stats_all": stats_all,
        "missing_sentences": missing,
        "caption_rows": len(poller.captions),
        "per_sentence": rows,
        "captions": poller.captions,
    })
    print(f"저장: {path}")


# ───────────────────────── 3. wer ─────────────────────────

def edit_distance(ref: list, hyp: list) -> int:
    """Levenshtein 거리 (메모리 O(len(hyp)))"""
    if not ref:
        return len(hyp)
    prev = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        cur = [i] + [0] * len(hyp)
        for j, h in enumerate(hyp, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r != h))
        prev = cur
    return prev[-1]


def norm_text(s: str) -> str:
    s = re.sub(r"[^\w\s]", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def wer_cer(reference: str, hypothesis: str) -> dict:
    ref, hyp = norm_text(reference), norm_text(hypothesis)
    rw, hw = ref.split(), hyp.split()
    rc, hc = list(ref.replace(" ", "")), list(hyp.replace(" ", ""))
    w_err = edit_distance(rw, hw)
    print(f"CER 계산 중 (문자 {len(rc)}개)...")
    c_err = edit_distance(rc, hc)
    return {
        "wer": w_err / max(len(rw), 1),
        "cer": c_err / max(len(rc), 1),
        "ref_words": len(rw), "hyp_words": len(hw), "word_errors": w_err,
        "ref_chars": len(rc), "hyp_chars": len(hc), "char_errors": c_err,
    }


async def fetch_transcript(env: dict, lecture_id: str) -> list[dict]:
    poller = CaptionPoller(env, lecture_id)
    async with httpx.AsyncClient(timeout=30) as c:
        return await poller.fetch_all(c)


async def cmd_wer(args):
    env = load_env()
    if args.audio:
        if not args.reference:
            sys.exit("--audio 를 쓸 때는 --reference (정답 스크립트 txt) 가 필요합니다.")
        audio_path, ref_path, source = Path(args.audio), Path(args.reference), "user_audio"
    elif args.lecture_id:
        if not args.reference:
            sys.exit("--lecture-id 를 쓸 때는 --reference 가 필요합니다.")
        audio_path, ref_path, source = None, Path(args.reference), "existing_lecture"
    else:
        audio_path, ref_path, source = RESULTS / "test_sentences.wav", RESULTS / "test_reference.txt", "tts_synthetic"
        if not audio_path.exists():
            sys.exit("테스트 오디오가 없습니다. 먼저 make-audio 를 실행하거나 --audio/--reference 를 지정하세요.")

    reference = ref_path.read_text(encoding="utf-8")

    if audio_path is not None:
        await preflight(args.server)
        lecture_id = make_lecture_id("bench-wer")
        pcm = read_wav_pcm(audio_path) if audio_path.suffix.lower() == ".wav" else to_pcm16k(audio_path)
        await stream_and_collect(args, env, pcm, lecture_id)
    else:
        lecture_id = args.lecture_id

    rows = await fetch_transcript(env, lecture_id)
    hypothesis = " ".join((r.get("original_text") or "").strip() for r in rows)
    if not hypothesis.strip():
        sys.exit(f"lecture_id={lecture_id} 에 인식 결과가 없습니다.")

    res = wer_cer(reference, hypothesis)
    print("\n=== STT 정확도 ===")
    print(f"소스: {source}  lecture_id: {lecture_id}  자막 행: {len(rows)}")
    print(f"WER: {res['wer']*100:.2f}%  ({res['word_errors']}/{res['ref_words']} 단어)")
    print(f"CER: {res['cer']*100:.2f}%  ({res['char_errors']}/{res['ref_chars']} 문자)")
    if source == "tts_synthetic":
        print("※ TTS 합성음은 실제 강의보다 깨끗합니다. 보고서에는 실제 강의 오디오 + 직접 작성한 정답으로 잰 값을 쓰세요.")

    (RESULTS / f"wer_hypothesis_{lecture_id}.txt").write_text(hypothesis, encoding="utf-8")
    path = save_json("wer", {
        "env": env_info(env), "source": source, "lecture_id": lecture_id,
        "audio": str(audio_path) if audio_path else None, "reference": str(ref_path),
        "caption_rows": len(rows), **res,
    })
    print(f"저장: {path}")


# ───────────────────────── 4. api ─────────────────────────

async def load_test(client: httpx.AsyncClient, method: str, url: str, params: dict,
                    n: int, concurrency: int, warmup: int) -> dict:
    for _ in range(warmup):  # 커넥션/모델 워밍업 (통계 제외)
        try:
            await client.request(method, url, params=params)
        except Exception:
            pass

    times, statuses, sample = [], {}, None
    counter = iter(range(n))

    async def worker():
        nonlocal sample
        for _ in counter:
            t = time.perf_counter()
            try:
                r = await client.request(method, url, params=params)
                code = r.status_code
                if sample is None:
                    sample = r.text[:200]
            except Exception as e:
                code = type(e).__name__
            dt = (time.perf_counter() - t) * 1000
            statuses[str(code)] = statuses.get(str(code), 0) + 1
            if code == 200:
                times.append(dt)

    wall = time.perf_counter()
    await asyncio.gather(*(worker() for _ in range(concurrency)))
    wall = time.perf_counter() - wall
    return {"latency_ms": summarize(times), "status": statuses, "rps": n / wall, "sample": sample,
            "n": n, "concurrency": concurrency}


async def cmd_api(args):
    env = load_env()
    await preflight(args.server)
    lecture_id = args.lecture_id
    if not lecture_id:
        prev = load_json("latency") or load_json("wer")
        if not prev:
            sys.exit("--lecture-id 를 지정하거나 먼저 latency 테스트를 실행하세요 (자막 데이터가 있는 강의가 필요).")
        lecture_id = prev["lecture_id"]
    print(f"대상 lecture_id: {lecture_id}")

    db_eps = [
        ("GET /health", "GET", "/health", {}),
        ("GET /lecture/glossary", "GET", "/lecture/glossary", {"lecture_id": lecture_id}),
        ("GET /lecture/status", "GET", "/lecture/status", {"lecture_id": lecture_id}),
    ]
    llm_eps = [
        ("GET /lecture/ask", "GET", "/lecture/ask",
         {"lecture_id": lecture_id, "question": args.question, "target_lang": "Korean"}),
        ("GET /lecture/summary/adaptive", "GET", "/lecture/summary/adaptive",
         {"lecture_id": lecture_id, "minutes": 30}),
    ]

    results = {"db": {}, "llm": {}}
    limits = httpx.Limits(max_connections=max(args.c_db, args.c_llm) + 2)
    async with httpx.AsyncClient(base_url=args.server, timeout=300, limits=limits) as client:
        for name, m, url, params in db_eps:
            print(f"[DB ] {name}  n={args.n_db} c={args.c_db} ...")
            results["db"][name] = await load_test(client, m, url, params, args.n_db, args.c_db, warmup=3)
        if not args.skip_llm:
            for name, m, url, params in llm_eps:
                print(f"[LLM] {name}  n={args.n_llm} c={args.c_llm} ...")
                results["llm"][name] = await load_test(client, m, url, params, args.n_llm, args.c_llm, warmup=1)
                if url == "/lecture/ask":
                    await client.post("/lecture/ask/reset", params={"lecture_id": lecture_id})

    print("\n=== REST API 응답시간 (ms, 성공 응답만) ===")
    print(f"{'구분':<4} {'엔드포인트':<30} {'n':>4} {'평균':>9} {'p50':>9} {'p95':>9} {'p99':>9} {'rps':>7}  상태")
    for group, eps in results.items():
        for name, r in eps.items():
            st = r["latency_ms"]
            if st.get("n"):
                print(f"{group.upper():<4} {name:<30} {st['n']:>4} {st['mean']:9.1f} {st['p50']:9.1f} "
                      f"{st['p95']:9.1f} {st['p99']:9.1f} {r['rps']:7.2f}  {r['status']}")
            else:
                print(f"{group.upper():<4} {name:<30}    0  (성공 응답 없음)  {r['status']}")
    adaptive = results["llm"].get("GET /lecture/summary/adaptive")
    if adaptive and adaptive["sample"] and "내용이 없습니다" in adaptive["sample"]:
        print("※ adaptive 요약이 '최근 내용 없음'으로 LLM을 타지 않았습니다. 최근 30분 내 자막이 있는 강의로 다시 재세요.")

    path = save_json("api", {"env": env_info(env), "lecture_id": lecture_id, "results": results})
    print(f"저장: {path}")


# ───────────────────────── 5. memory ─────────────────────────

def find_server_pids(port: int) -> list[int]:
    out = subprocess.run(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"],
                         capture_output=True, text=True).stdout
    return sorted({int(x) for x in out.split()})


def linear_slope(xs: list[float], ys: list[float]) -> float:
    if len(xs) < 2:
        return 0.0
    mx, my = statistics.fmean(xs), statistics.fmean(ys)
    den = sum((x - mx) ** 2 for x in xs)
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den if den else 0.0


async def cmd_memory(args):
    try:
        import psutil
    except ImportError:
        sys.exit("pip install psutil==7.0.0 이 필요합니다.")
    env = load_env()
    await preflight(args.server)

    pids = [args.pid] if args.pid else find_server_pids(args.port)
    if not pids:
        sys.exit(f"포트 {args.port}에서 대기 중인 프로세스를 찾지 못했습니다. --pid 로 직접 지정하세요.")
    roots = [psutil.Process(p) for p in pids]
    if any("reload" in " ".join(p.cmdline()) for p in roots):
        print("⚠ uvicorn --reload 로 실행 중입니다. 자식 프로세스까지 합산하지만, 가능하면 --reload 없이 재실행하세요.")

    def server_procs():
        procs = {}
        for r in roots:
            try:
                procs[r.pid] = r
                for ch in r.children(recursive=True):
                    procs[ch.pid] = ch
            except psutil.NoSuchProcess:
                pass
        return list(procs.values())

    def ollama_rss():
        total = 0
        for p in ollama_procs():
            try:
                total += p.memory_info().rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return total / 1024**2

    def ollama_procs():
        out = []
        for p in psutil.process_iter(["name", "cmdline"]):
            try:
                if "ollama" in (p.info["name"] or "").lower() or "llama-server" in " ".join(p.info["cmdline"] or []):
                    out.append(p)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return out

    has_footprint = platform.system() == "Darwin" and shutil.which("footprint") is not None

    def phys_footprint_mb(procs) -> float | None:
        """
        macOS phys_footprint (활동 모니터 '메모리' 값). RSS는 메모리 압축/스왑 때문에 크게 출렁여서
        누수 추세 판단에는 footprint가 더 적합하다.
        """
        if not has_footprint or not procs:
            return None
        total = 0
        for p in procs:
            out = subprocess.run(["footprint", "-p", str(p.pid), "-f", "bytes"],
                                 capture_output=True, text=True).stdout
            m = re.search(r"phys_footprint:\s*(\d+)\s*B", out)
            if m:
                total += int(m.group(1))
        return total / 1024**2 if total else None

    if args.audio:
        src = Path(args.audio)
        pcm = read_wav_pcm(src) if src.suffix.lower() == ".wav" else to_pcm16k(src)
    else:
        pcm, _ = load_test_audio()
    total_sec = args.minutes * 60
    loops = math.ceil(total_sec / (len(pcm) / 2 / SR))
    lecture_id = make_lecture_id("bench-mem")
    poller = CaptionPoller(env, lecture_id)

    RESULTS.mkdir(exist_ok=True)
    csv_path = RESULTS / "memory.csv"
    samples = []
    stop = asyncio.Event()
    ws_error = None

    async def count_rows(client) -> int | None:
        try:
            r = await client.get(f"{poller.base}/lecture_contents",
                                 params={"select": "id", "lecture_id": f"eq.{lecture_id}"},
                                 headers={**poller.headers, "Prefer": "count=exact", "Range": "0-0"})
            return int(r.headers.get("content-range", "*/0").split("/")[-1])
        except Exception:
            return None

    async def sampler(t0):
        f = open(csv_path, "w", newline="")
        w = csv.writer(f)
        w.writerow(["sec", "server_rss_mb", "server_footprint_mb", "ollama_rss_mb", "ollama_footprint_mb",
                    "server_cpu_pct", "threads", "caption_rows"])
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                while not stop.is_set():
                    procs = server_procs()
                    rss = sum(p.memory_info().rss for p in procs) / 1024**2
                    cpu = sum(p.cpu_percent(None) for p in procs)
                    threads = sum(p.num_threads() for p in procs)
                    # footprint 호출은 블로킹이라 스레드로 넘겨 오디오 전송 타이밍을 방해하지 않게 한다
                    fp = await asyncio.to_thread(phys_footprint_mb, procs)
                    ofp = await asyncio.to_thread(phys_footprint_mb, ollama_procs())
                    rows = await count_rows(client)
                    sec = time.perf_counter() - t0
                    s = {"sec": round(sec, 1), "rss": rss, "fp": fp, "ollama": ollama_rss(), "ollama_fp": ofp,
                         "cpu": cpu, "threads": threads, "rows": rows}
                    # 누수 판정에 쓰는 대표 지표: footprint(가능하면) → 없으면 RSS
                    s["mem"] = fp if fp is not None else rss
                    s["ollama_mem"] = ofp if ofp is not None else s["ollama"]
                    samples.append(s)
                    w.writerow([s["sec"], f"{rss:.1f}", f"{fp:.1f}" if fp is not None else "",
                                f"{s['ollama']:.1f}", f"{ofp:.1f}" if ofp is not None else "",
                                f"{cpu:.1f}", threads, rows])
                    f.flush()
                    fp_txt = f"{fp:8.1f}" if fp is not None else "       -"
                    print(f"  [{sec/60:6.1f}분] server footprint {fp_txt} MB (RSS {rss:7.1f}) | "
                          f"ollama {s['ollama_mem']:7.1f} MB | CPU {cpu:5.1f}% | threads {threads} | 자막 {rows}")
                    try:
                        await asyncio.wait_for(stop.wait(), timeout=args.interval)
                    except asyncio.TimeoutError:
                        pass
        finally:
            f.close()

    url = ws_url(args.server, lecture_id, args.lang)
    print(f"{args.minutes}분 연속 스트리밍 시작 (오디오 {len(pcm)/2/SR:.0f}초 x {loops}회 반복), 기록: {csv_path}")
    t0 = time.perf_counter()
    sample_task = asyncio.create_task(sampler(t0))
    try:
        async with websockets.connect(url, max_size=None, ping_interval=20, ping_timeout=60) as ws:
            t_stream = time.perf_counter()
            sent = 0.0
            for _ in range(loops):
                remain = total_sec - sent
                part = pcm if remain * SR * 2 >= len(pcm) else pcm[: int(remain * SR) * 2]
                await stream_realtime(ws, part, 1.0, t_stream + sent)
                sent += len(part) / 2 / SR
                if sent >= total_sec:
                    break
            await asyncio.sleep(args.interval * 2)  # 마지막 처리분 반영
    except Exception as e:
        ws_error = f"{type(e).__name__}: {e}"
        print(f"⚠ 스트리밍 중단: {ws_error}")
    stop.set()
    await sample_task

    warm = [s for s in samples if s["sec"] >= args.warmup_min * 60]
    metric = "phys_footprint" if samples and samples[0]["fp"] is not None else "rss"
    xs = [s["sec"] / 60 for s in warm]
    slope = linear_slope(xs, [s["mem"] for s in warm]) if len(warm) >= 2 else None
    rss_slope = linear_slope(xs, [s["rss"] for s in warm]) if len(warm) >= 2 else None
    o_slope = linear_slope(xs, [s["ollama_mem"] for s in warm]) if len(warm) >= 2 else None
    res = {
        "env": env_info(env), "lecture_id": lecture_id, "minutes": args.minutes, "interval": args.interval,
        "label": f"{args.minutes:g}분 간이 측정" if args.minutes < 60 else f"{args.minutes:g}분 연속 측정",
        "streamed_minutes": round((time.perf_counter() - t0) / 60, 1), "ws_error": ws_error,
        "warmup_min": args.warmup_min,
        "metric": metric,
        "samples": len(samples),
        "mem_start_mb": samples[0]["mem"] if samples else None,
        "mem_after_warmup_mb": warm[0]["mem"] if warm else None,
        "mem_end_mb": samples[-1]["mem"] if samples else None,
        "mem_max_mb": max(s["mem"] for s in samples) if samples else None,
        "rss_min_mb": min(s["rss"] for s in samples) if samples else None,
        "rss_max_mb": max(s["rss"] for s in samples) if samples else None,
        "slope_mb_per_min_after_warmup": slope,
        "rss_slope_mb_per_min_after_warmup": rss_slope,
        "ollama_slope_mb_per_min_after_warmup": o_slope,
        "leak_threshold_mb_per_min": args.leak_threshold,
        "leak_suspected": (slope is not None and slope > args.leak_threshold),
        "caption_rows_total": samples[-1]["rows"] if samples else None,
        "csv": str(csv_path),
    }

    print("\n=== 메모리 안정성 ===")
    if slope is None:
        print("워밍업 이후 샘플이 부족합니다. --minutes 를 늘리거나 --warmup-min 을 줄이세요.")
    else:
        print(f"[{res['label']}] 지표: {metric}")
        print(f"시작 {res['mem_start_mb']:.0f} MB → 워밍업 후 {res['mem_after_warmup_mb']:.0f} MB → "
              f"종료 {res['mem_end_mb']:.0f} MB (최대 {res['mem_max_mb']:.0f} MB) | "
              f"RSS 범위 {res['rss_min_mb']:.0f}~{res['rss_max_mb']:.0f} MB")
        print(f"워밍업({args.warmup_min}분) 이후 기울기: {slope:+.2f} MB/분 (RSS 기준 {rss_slope:+.2f} MB/분)")
        print(f"판정 기준 {args.leak_threshold} MB/분 → "
              f"{'누수 의심' if res['leak_suspected'] else '누수 징후 없음'}")
    print(f"총 자막 행: {res['caption_rows_total']} / 스트리밍 오류: {ws_error or '없음'}")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(figsize=(9, 4))
        t = [s["sec"] / 60 for s in samples]
        ax.plot(t, [s["mem"] for s in samples], label=f"FastAPI (uvicorn) {metric}", lw=2)
        ax.plot(t, [s["rss"] for s in samples], label="FastAPI (uvicorn) RSS", alpha=0.4)
        ax.plot(t, [s["ollama_mem"] for s in samples], label=f"Ollama {metric}", alpha=0.6)
        ax.axvline(args.warmup_min, color="gray", ls="--", lw=1, label="warm-up end")
        ax.set_xlabel("elapsed (min)")
        ax.set_ylabel("memory (MB)")
        ax.set_title(f"Memory - {args.minutes:g}-min short test (sampling {args.interval:g}s)")
        ax.legend()
        ax.grid(alpha=0.3)
        fig.tight_layout()
        png = RESULTS / "memory.png"
        fig.savefig(png, dpi=150)
        res["png"] = str(png)
        print(f"그래프: {png}")
    except ImportError:
        print("(matplotlib 미설치: 그래프 생략)")

    print(f"저장: {save_json('memory', res)}")


# ───────────────────────── 6. report ─────────────────────────

def cmd_report(args):
    lat, wer, api, mem = load_json("latency"), load_json("wer"), load_json("api"), load_json("memory")
    env = next((d["env"] for d in (lat, wer, api, mem) if d), None)
    lines = ["# 성능 측정 결과", ""]
    if env:
        lines += [f"- 측정 환경: {env['chip']}, RAM {env['ram_gb']}GB, {env['platform']}",
                  f"- STT: faster-whisper {env['whisper_model']} ({env['whisper_compute_type']}, "
                  f"device={env['whisper_device']}) / LLM: {env['llm_model']}",
                  f"- 측정 일시: {env['measured_at']}", ""]
    lines += ["| 지표 | 목표 | 실측 | 측정 조건 |", "|---|---|---|---|"]

    if lat:
        st = lat["stats_text_matched"] if lat["stats_text_matched"].get("n") else lat["stats_all"]
        val = (f"평균 {st['mean']:.2f}s / p50 {st['p50']:.2f}s / p95 {st['p95']:.2f}s"
               if st.get("n") else "측정 실패")
        lines.append(f"| E2E 자막 지연 | ≤ 5초 | {val} | {st.get('n', 0)}문장, 100ms 청크 실시간 전송, "
                     f"DB 폴링 {lat['poll_interval']}s, 누락 {lat['missing_sentences']}문장 |")
    else:
        lines.append("| E2E 자막 지연 | ≤ 5초 | (미측정) | |")

    if wer:
        src = {"tts_synthetic": "TTS 합성음", "user_audio": "실제 강의 오디오",
               "existing_lecture": "기존 강의 데이터"}[wer["source"]]
        lines.append(f"| STT 정확도 | WER < 10% | WER {wer['wer']*100:.1f}% / CER {wer['cer']*100:.1f}% | "
                     f"{src}, 정답 {wer['ref_words']}어절 / {wer['ref_chars']}자 |")
    else:
        lines.append("| STT 정확도 | WER < 10% | (미측정) | |")

    if api:
        for group, label in (("db", "API 응답(DB)"), ("llm", "API 응답(LLM)")):
            for name, r in api["results"].get(group, {}).items():
                st = r["latency_ms"]
                val = (f"평균 {st['mean']:.0f}ms / p50 {st['p50']:.0f}ms / p95 {st['p95']:.0f}ms"
                       if st.get("n") else f"성공 응답 없음 {r['status']}")
                if r.get("sample") and r["sample"].lstrip().startswith('{"error"'):
                    val = f"측정 제외 (200이지만 에러 본문 반환: {r['sample'][:50]})"
                lines.append(f"| {label} `{name}` | - | {val} | {r['n']}회, 동시 {r['concurrency']} |")
    else:
        lines.append("| API 응답 | - | (미측정) | |")

    if mem and mem.get("slope_mb_per_min_after_warmup") is not None:
        s = mem["slope_mb_per_min_after_warmup"]
        verdict = "누수 의심" if mem["leak_suspected"] else "누수 징후 없음"
        label = mem.get("label") or f"{mem['minutes']:g}분 측정"
        lines.append(f"| 연속 스트리밍 메모리 ({label}) | 누수 없음 | {verdict} (워밍업 후 {s:+.2f} MB/분, "
                     f"최대 {mem['mem_max_mb']:.0f}MB, 지표 {mem['metric']}) | **{label}** "
                     f"(스트리밍 {mem['minutes']:g}분, {mem['interval']:g}초 간격 샘플링 {mem['samples']}회, "
                     f"워밍업 {mem['warmup_min']:g}분 제외, 기준 {mem['leak_threshold_mb_per_min']} MB/분) |")
    else:
        lines.append("| 연속 스트리밍 메모리 | 누수 없음 | (미측정) | |")

    text = "\n".join(lines) + "\n"
    out = RESULTS / "report.md"
    RESULTS.mkdir(exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(text)
    print(f"저장: {out}")


# ───────────────────────── CLI ─────────────────────────

def main():
    ap = argparse.ArgumentParser(description="LiveLectureAI 성능 측정")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_stream_opts(p):
        p.add_argument("--server", default="http://localhost:8000")
        p.add_argument("--lang", default="Korean", help="target_lang (번역 언어)")
        p.add_argument("--speed", type=float, default=1.0, help="전송 속도 배율 (1.0 = 실시간)")
        p.add_argument("--poll-interval", type=float, default=0.2, help="DB 폴링 간격(초)")
        p.add_argument("--tail-silence", type=float, default=6.0, help="끝에 덧붙일 무음(초), 버퍼 flush용")
        p.add_argument("--idle", type=float, default=15.0, help="새 자막이 이 시간 동안 없으면 종료")
        p.add_argument("--max-wait", type=float, default=120.0, help="전송 후 최대 대기(초)")

    p = sub.add_parser("make-audio", help="macOS TTS로 테스트 오디오 생성")
    p.add_argument("--voice", default="Yuna")
    p.add_argument("--gap", type=float, default=1.5, help="문장 사이 무음(초)")

    p = sub.add_parser("latency", help="E2E 자막 지연 측정")
    add_stream_opts(p)
    p.add_argument("--lecture-id", default=None)

    p = sub.add_parser("wer", help="WER/CER 측정")
    add_stream_opts(p)
    p.add_argument("--audio", help="측정할 오디오/영상 파일 (mp3, wav, mp4 등)")
    p.add_argument("--reference", help="정답 스크립트 txt")
    p.add_argument("--lecture-id", help="이미 DB에 있는 강의로 계산 (스트리밍 생략)")

    p = sub.add_parser("api", help="REST API 응답시간 측정")
    p.add_argument("--server", default="http://localhost:8000")
    p.add_argument("--lecture-id", default=None)
    p.add_argument("--n-db", type=int, default=200)
    p.add_argument("--c-db", type=int, default=5)
    p.add_argument("--n-llm", type=int, default=20)
    p.add_argument("--c-llm", type=int, default=1)
    p.add_argument("--question", default="활성화 함수가 뭐야?")
    p.add_argument("--skip-llm", action="store_true")

    p = sub.add_parser("memory", help="연속 스트리밍 메모리 안정성")
    p.add_argument("--server", default="http://localhost:8000")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--pid", type=int, default=None, help="uvicorn PID (기본: 포트로 자동 탐지)")
    p.add_argument("--lang", default="Korean")
    p.add_argument("--audio", help="반복 재생할 오디오 (기본: test_sentences.wav)")
    p.add_argument("--minutes", type=float, default=60)
    p.add_argument("--interval", type=float, default=30, help="샘플링 간격(초)")
    p.add_argument("--warmup-min", type=float, default=10)
    p.add_argument("--leak-threshold", type=float, default=1.0, help="누수 판정 기울기 기준(MB/분)")

    sub.add_parser("report", help="결과를 보고서용 표로 정리")

    args = ap.parse_args()
    if args.cmd == "make-audio":
        cmd_make_audio(args)
    elif args.cmd == "latency":
        asyncio.run(cmd_latency(args))
    elif args.cmd == "wer":
        asyncio.run(cmd_wer(args))
    elif args.cmd == "api":
        asyncio.run(cmd_api(args))
    elif args.cmd == "memory":
        asyncio.run(cmd_memory(args))
    elif args.cmd == "report":
        cmd_report(args)


if __name__ == "__main__":
    main()
