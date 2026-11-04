"""
<설명>
실시간 강의 오디오 → 자막 파이프라인 (faster-whisper + Silero VAD)

(1) 강의별 단일 워커 (Backpressure)
    - WebSocket은 받은 PCM을 강의별 버퍼에 붙이기만 한다. 강의마다 워커 하나가 버퍼를 꺼내 처리하므로,
      Whisper가 추론하는 동안 들어온 오디오는 다음 구간에 합쳐진다.
    - 예전에는 100ms 청크마다 태스크를 만들고 락을 잡은 채 추론해서, 추론이 느리면 대기 태스크가 끝없이 쌓였다.
      (팀 측정: 자막 지연이 20초 → 389초로 계속 증가)
(2) VAD 기준 구간 자르기
    - Silero VAD를 32ms 단위로 스트리밍 실행해 말이 끝난 지점(0.4초 이상 무음)에서 구간을 자른다.
      고정 5초 + 0.5초 겹침 방식과 달리 단어가 중간에 잘리지 않고, 같은 소리를 두 번 인식하지 않는다.
    - 구간 길이는 모델 속도에 맞춘다. Whisper는 짧은 오디오도 30초 창으로 처리하기 때문에
      느린 모델은 구간을 길게 잡아야 실시간을 따라간다.
      M1 CPU 실측(beam=1, ko): small 5초 2.0s / 10초 2.5s, medium 5초 5.4s / 10초 6.9s / 15초 8.6s
      → small 3~10초, medium 8~15초 구간을 기본값으로 쓴다.
    - 그래도 처리가 밀려 버퍼가 최대 구간의 3배를 넘으면, 오래된 오디오를 버려 지연이 계속 늘지 않게 한다.
(3) 환각 필터
    - 무음·음악 구간에서 Whisper가 지어내는 대표 문장("시청해 주셔서 감사합니다" 등)은 그 문장만 버린다.
      예전처럼 '좋아요'가 들어간 자막 전체를 버리지 않는다.
    - 지시문을 initial_prompt로 넣으면 그 문구가 그대로 자막에 나와서("자막 서비스입니다."),
      직전 자막의 끝부분을 문맥으로 넣는다.
(4) 자막 먼저, 번역은 나중에
    - 인식 결과(원문)를 바로 lecture_contents에 INSERT 해서 먼저 보여주고,
      번역과 임베딩은 백그라운드에서 끝나는 대로 같은 행을 UPDATE 한다.
      강의 언어와 번역 언어가 같으면 번역을 건너뛴다.
(5) 연결 종료 시 남은 오디오 처리
    - 마지막 오디오 연결이 끊기면 버퍼에 남은 음성까지 인식한 뒤 워커를 정리한다.
"""

import asyncio
import re
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

import ctranslate2
import numpy as np
import torch
from faster_whisper import WhisperModel
from silero_vad import VADIterator, load_silero_vad

from core import llm
from core.config import settings
from core.database import get_supabase
from core.lang import lang_name, same_language
from services import glossary_service
from services.translation_service import translation_engine

SAMPLE_RATE = 16000
BYTES_PER_SAMPLE = 2
VAD_CHUNK_SAMPLES = 512                     # Silero VAD 16kHz 입력 단위 (32ms)
VAD_CHUNK_BYTES = VAD_CHUNK_SAMPLES * BYTES_PER_SAMPLE
VAD_MIN_SILENCE_MS = 400                    # 이만큼 조용하면 말이 끝난 것으로 본다
VAD_SPEECH_PAD_MS = 100
PROMPT_CONTEXT_CHARS = 60                   # 다음 구간 initial_prompt로 넣을 직전 자막 길이

# VAD는 가벼워서 1스레드면 충분하다. Whisper(CTranslate2)와 CPU를 덜 다투게 한다.
torch.set_num_threads(1)


def _resolve_device() -> str:
    if settings.WHISPER_DEVICE != "auto":
        return settings.WHISPER_DEVICE
    try:
        return "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
    except Exception:
        return "cpu"


def _window_bounds(device: str) -> tuple[float, float]:
    size = settings.WHISPER_MODEL_SIZE.lower()
    if device == "cuda" or size.startswith(("tiny", "base", "small")):
        default_min, default_max = 3.0, 10.0
    elif size.startswith("medium"):
        default_min, default_max = 8.0, 15.0
    else:  # large 계열
        default_min, default_max = 12.0, 20.0
    lo = settings.STT_MIN_WINDOW_SEC or default_min
    hi = settings.STT_MAX_WINDOW_SEC or default_max
    hi = min(max(hi, lo + 1.0), 28.0)        # Whisper 입력 한계는 30초
    return lo, hi


WHISPER_DEVICE = _resolve_device()
MIN_WINDOW_SEC, MAX_WINDOW_SEC = _window_bounds(WHISPER_DEVICE)
MAX_BACKLOG_SEC = MAX_WINDOW_SEC * 3
WHISPER_LANGUAGE = None if settings.WHISPER_LANGUAGE.lower() == "auto" else settings.WHISPER_LANGUAGE

# [1] 엔진 및 모델 초기화 (서버 시작 시 1회)
stt_model = WhisperModel(
    settings.WHISPER_MODEL_SIZE,
    device=WHISPER_DEVICE,
    compute_type=settings.WHISPER_COMPUTE_TYPE,
)

# Whisper 추론 전용 스레드 (메인 이벤트 루프 블로킹 방지). 워커 1개라 추론이 동시에 돌지 않는다.
executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="whisper")

# 무음·음악 구간에서 Whisper가 지어내는 대표 문장. 짧은 문장에서만 걸러낸다.
_HALLUCINATION_PATTERNS = [re.compile(p, re.IGNORECASE) for p in (
    r"시청\s*해\s*주셔서\s*감사",
    r"시청\s*해\s*주세요",
    r"구독\s*(과|와|하고|및|,)?\s*좋아요",
    r"좋아요\s*(와|랑|및|,)?\s*구독",
    r"구독\s*(부탁|버튼|해\s*주세요)",
    r"자막\s*(을|를)?\s*켜",
    r"자막\s*서비스",
    r"영상\s*(을|를)?\s*봐\s*주셔서",
    r"다음\s*영상에서\s*(만나요|뵙겠습니다)",
    r"(MBC|KBS|SBS|YTN)\s*뉴스",
    r"thank(s| you) for watching",
    r"please subscribe",
    r"subtitles?\s+by",
    r"ご視聴ありがとうございました",
    r"字幕",
)]

_bg_tasks: set[asyncio.Task] = set()
_streams: dict[str, "LectureStream"] = {}
_target_langs: dict[str, str] = {}


def spawn(coro) -> asyncio.Task:
    """백그라운드 태스크 실행 (참조를 잡아둬서 도중에 GC되지 않게 한다)"""
    task = asyncio.create_task(coro)
    _bg_tasks.add(task)
    task.add_done_callback(_bg_tasks.discard)
    return task


def _is_hallucination(text: str) -> bool:
    return len(text) <= 40 and any(p.search(text) for p in _HALLUCINATION_PATTERNS)


def _strip_repeated_prefix(previous: str, text: str) -> str:
    """직전 자막의 끝부분이 새 자막 앞에 그대로 반복되면 그 부분을 지운다 (initial_prompt 되풀이 방지)."""
    if not previous or not text:
        return text
    if text == previous:
        return ""
    for k in range(min(len(previous), len(text)), 3, -1):
        if previous.endswith(text[:k]):
            return text[k:].lstrip(" ,.")
    return text


def _transcribe_sync(audio: np.ndarray, prompt: Optional[str], hotwords: Optional[str]) -> tuple[str, str]:
    segments, info = stt_model.transcribe(
        audio,
        beam_size=settings.WHISPER_BEAM_SIZE,
        language=WHISPER_LANGUAGE,
        initial_prompt=prompt or None,
        hotwords=hotwords or None,
        condition_on_previous_text=False,
        vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500),
        no_speech_threshold=0.6,
        compression_ratio_threshold=2.4,
        log_prob_threshold=-1.0,
    )
    kept = []
    for seg in segments:
        text = seg.text.strip()
        if not text or seg.no_speech_prob >= 0.6 or seg.compression_ratio > 2.4:
            continue
        if _is_hallucination(text):
            print(f"[STT] 환각 문장 제거: {text}")
            continue
        kept.append(text)
    return " ".join(kept).strip(), info.language


# ─── 번역 언어 설정 (강의별) ──────────────────────────────────────────────

def get_target_lang(lecture_id: str) -> str:
    return _target_langs.get(lecture_id, lang_name(settings.DEFAULT_TARGET_LANG))


def set_target_lang(lecture_id: str, target_lang: str, *, only_if_unset: bool = False) -> str:
    if only_if_unset and lecture_id in _target_langs:
        return _target_langs[lecture_id]
    _target_langs[lecture_id] = lang_name(target_lang, default=lang_name(settings.DEFAULT_TARGET_LANG))
    return _target_langs[lecture_id]


# ─── 자막 저장 / 번역 ────────────────────────────────────────────────────

async def publish_caption(lecture_id: str, text: str, source_lang: str) -> Optional[int]:
    """원문을 먼저 저장해 화면에 띄우고, 번역·임베딩은 백그라운드에서 같은 행에 채운다."""
    target = get_target_lang(lecture_id)
    same = same_language(source_lang, target)
    row = {
        "lecture_id": lecture_id,
        "original_text": text,
        "translated_text": text if same else None,
        "source_lang": source_lang,
        "target_lang": target,
    }
    try:
        client = await get_supabase()
        res = await client.table("lecture_contents").insert(row).execute()
        content_id = res.data[0]["id"]
    except Exception as e:
        print(f"[STT] 자막 저장 실패 ({type(e).__name__}): {e}")
        return None

    glossary_service.add_caption(lecture_id, text)
    spawn(_enrich_caption(content_id, lecture_id, text, source_lang, target, same))
    return content_id


async def _enrich_caption(content_id: int, lecture_id: str, text: str,
                          source_lang: str, target: str, same: bool) -> None:
    update: dict = {}
    timing: dict = {}

    async def _embedding():
        try:
            update["content_embedding"] = await llm.embed(text)
        except Exception as e:
            print(f"[STT] 임베딩 실패 ({type(e).__name__}): {e}")

    async def _translation():
        if same:
            return
        terms = await glossary_service.get_terms(lecture_id)
        t0 = time.perf_counter()
        translated = await llm.run_bounded(translation_engine.translate(
            text, target, source_lang=source_lang, glossary_terms=terms
        ))
        timing["translate"] = time.perf_counter() - t0
        if translated:
            update["translated_text"] = translated

    await asyncio.gather(_embedding(), _translation())
    if not update:
        return
    try:
        client = await get_supabase()
        await client.table("lecture_contents").update(update).eq("id", content_id).execute()
        if "translated_text" in update:
            print(f"[STT] 번역({target}) #{content_id} {timing.get('translate', 0):.1f}s: "
                  f"{update['translated_text'][:40]}")
    except Exception as e:
        print(f"[STT] 번역/임베딩 저장 실패 #{content_id}: {e}")


async def retranslate_recent(lecture_id: str, count: int = 3) -> None:
    """번역 언어를 바꿨을 때 최근 자막 몇 개를 새 언어로 다시 번역해 화면이 바로 바뀌게 한다."""
    target = get_target_lang(lecture_id)
    try:
        client = await get_supabase()
        res = await client.table("lecture_contents").select("id, original_text, source_lang") \
            .eq("lecture_id", lecture_id).order("id", desc=True).limit(count).execute()
        terms = await glossary_service.get_terms(lecture_id)
        for row in reversed(res.data):
            original = row.get("original_text") or ""
            if not original:
                continue
            if same_language(row.get("source_lang"), target):
                translated = original
            else:
                translated = await llm.run_bounded(translation_engine.translate(
                    original, target, source_lang=row.get("source_lang"), glossary_terms=terms
                ))
            if translated and get_target_lang(lecture_id) == target:
                await client.table("lecture_contents").update(
                    {"translated_text": translated, "target_lang": target}
                ).eq("id", row["id"]).execute()
    except Exception as e:
        print(f"[STT] 재번역 실패 ({lecture_id}): {e}")


# ─── 강의별 오디오 스트림 ─────────────────────────────────────────────────

class LectureStream:
    def __init__(self, lecture_id: str):
        self.lecture_id = lecture_id
        self.pcm = bytearray()          # 아직 인식하지 않은 16kHz/16bit/mono PCM
        self.vad_bytes = 0              # pcm 중 VAD가 처리한 바이트 수
        self.pcm_start_sample = 0       # pcm[0]의 VAD 기준 샘플 번호
        self.starts: list[int] = []     # pcm 기준, 말이 시작된 샘플 위치들
        self.ends: list[int] = []       # pcm 기준, 말이 끝난 샘플 위치들 (자를 수 있는 지점)
        self.vad = VADIterator(
            load_silero_vad(),          # VAD 모델은 내부 상태가 있어 스트림마다 따로 만든다
            threshold=settings.VAD_THRESHOLD,
            sampling_rate=SAMPLE_RATE,
            min_silence_duration_ms=VAD_MIN_SILENCE_MS,
            speech_pad_ms=VAD_SPEECH_PAD_MS,
        )
        self.prev_text = ""
        self.hotwords: Optional[str] = None
        self.connections = 0
        self.active_conn = 0
        self._next_conn = 0
        self._carry = b""               # 홀수 바이트로 끊겨 들어온 나머지
        self.closing = False
        self.finished = False
        self.event = asyncio.Event()
        self.worker: Optional[asyncio.Task] = None
        self.stats = {"windows": 0, "audio_sec": 0.0, "infer_sec": 0.0, "dropped_sec": 0.0}

    # 연결 관리 ───────────────────────────
    def attach(self) -> int:
        """새 오디오 연결. 가장 최근에 붙은 연결의 오디오만 받는다 (재접속 시 이전 연결과 섞이지 않게)."""
        self._next_conn += 1
        self.active_conn = self._next_conn
        self.connections += 1
        self.closing = False
        return self.active_conn

    def detach(self, conn_id: int) -> None:
        self.connections = max(0, self.connections - 1)
        if conn_id == self.active_conn:
            self._carry = b""
        if self.connections == 0:
            self.closing = True
            self.event.set()

    def feed(self, conn_id: int, data: bytes) -> bool:
        if self.finished or conn_id != self.active_conn or not data:
            return False
        data = self._carry + data
        if len(data) % 2:
            self._carry, data = data[-1:], data[:-1]
        else:
            self._carry = b""
        self.pcm.extend(data)
        self.event.set()
        return True

    @property
    def backlog_sec(self) -> float:
        return len(self.pcm) / BYTES_PER_SAMPLE / SAMPLE_RATE

    # VAD ─────────────────────────────────
    def _run_vad(self) -> None:
        end = len(self.pcm) - (len(self.pcm) - self.vad_bytes) % VAD_CHUNK_BYTES
        pos = self.vad_bytes
        if pos >= end:
            return
        audio = np.frombuffer(bytes(self.pcm[pos:end]), dtype=np.int16).astype(np.float32) / 32768.0
        tensor = torch.from_numpy(audio)
        for i in range(0, len(audio), VAD_CHUNK_SAMPLES):
            event = self.vad(tensor[i:i + VAD_CHUNK_SAMPLES])
            if not event:
                continue
            if "start" in event:
                self.starts.append(max(0, event["start"] - self.pcm_start_sample))
            elif "end" in event:
                rel = event["end"] - self.pcm_start_sample
                if rel > 0:
                    self.ends.append(rel)
                # rel <= 0 이면 이미 잘라낸 구간에서 끝난 말이라 현재 버퍼에는 음성이 없다
        self.vad_bytes = end

    @property
    def _speech_in_buffer(self) -> bool:
        return bool(self.vad.triggered or self.starts or self.ends)

    def _drop_backlog(self) -> None:
        """처리가 실시간을 못 따라가 버퍼가 너무 커지면 오래된 오디오를 버린다."""
        limit = int(MAX_BACKLOG_SEC * SAMPLE_RATE) * BYTES_PER_SAMPLE
        if len(self.pcm) <= limit:
            return
        keep = int(MAX_WINDOW_SEC * SAMPLE_RATE) * BYTES_PER_SAMPLE
        drop = len(self.pcm) - keep
        del self.pcm[:drop]
        dropped = drop / BYTES_PER_SAMPLE / SAMPLE_RATE
        self.stats["dropped_sec"] += dropped
        print(f"[STT] {self.lecture_id}: 처리가 밀려 오디오 {dropped:.1f}초를 건너뜀 "
              f"(이 기기에서 모델이 너무 느림 → WHISPER_MODEL_SIZE=small 권장)")
        # 남긴 오디오는 VAD를 처음부터 다시 돌린다
        self.vad.reset_states()
        self.vad_bytes = 0
        self.pcm_start_sample = 0
        self.starts, self.ends = [], []

    def _pause_point(self, limit: int, floor: int) -> Optional[int]:
        """limit 이하에서 가장 늦게 말이 끝난 지점 (floor 이상만)"""
        candidates = [e for e in self.ends if floor <= e <= limit]
        return candidates[-1] if candidates else None

    def _next_cut(self) -> Optional[tuple[str, int]]:
        """('speech' | 'silence', 잘라낼 바이트 수) 또는 아직 기다릴 때 None"""
        processed = self.vad_bytes // BYTES_PER_SAMPLE
        total = len(self.pcm) // BYTES_PER_SAMPLE
        min_samples = int(MIN_WINDOW_SEC * SAMPLE_RATE)
        max_samples = int(MAX_WINDOW_SEC * SAMPLE_RATE)
        kind = "speech" if self._speech_in_buffer else "silence"

        if self.closing:
            if total == 0:
                return None
            if total <= max_samples:
                return (kind, total * BYTES_PER_SAMPLE)
            cut = self._pause_point(max_samples, min_samples // 2) or max_samples
            return (kind, cut * BYTES_PER_SAMPLE)

        if processed < min_samples:
            return None
        if kind == "silence":
            return ("silence", self.vad_bytes)          # 말이 없던 구간은 Whisper를 깨우지 않고 버린다
        if not self.vad.triggered and self.ends and processed <= max_samples:
            return ("speech", self.vad_bytes)           # 말이 끝나고 조용한 상태 → 여기까지 자른다
        pause = self._pause_point(min(processed, max_samples), min_samples)
        if pause:
            return ("speech", pause * BYTES_PER_SAMPLE)  # 다시 말하는 중이지만 최소 길이 뒤에 쉰 지점이 있으면 거기서 자른다
        if processed >= max_samples:
            # 쉬지 않고 길게 말하면 최대 길이 안의 마지막 쉰 지점, 그것도 없으면 최대 길이에서 자른다
            cut = self._pause_point(max_samples, min_samples // 2) or max_samples
            return ("speech", cut * BYTES_PER_SAMPLE)
        return None

    def _consume(self, nbytes: int) -> bytes:
        window = bytes(self.pcm[:nbytes])
        del self.pcm[:nbytes]
        samples = nbytes // BYTES_PER_SAMPLE
        self.vad_bytes = max(0, self.vad_bytes - nbytes)
        self.pcm_start_sample += samples
        self.starts = [s - samples for s in self.starts if s >= samples]
        self.ends = [e - samples for e in self.ends if e > samples]
        return window

    # 워커 ───────────────────────────────
    async def start(self) -> None:
        try:
            client = await get_supabase()
            res = await client.table("lectures").select("keywords").eq("id", self.lecture_id).limit(1).execute()
            keywords = (res.data[0].get("keywords") if res.data else None) or []
            self.hotwords = " ".join(keywords) or None
        except Exception:
            self.hotwords = None
        self.worker = asyncio.create_task(self._run(), name=f"stt-{self.lecture_id}")

    async def _run(self) -> None:
        cut_made = False
        try:
            while True:
                # 방금 구간을 잘랐으면 남은 오디오를 바로 다시 확인하고, 아니면 새 오디오를 기다린다
                if not self.closing and not cut_made:
                    try:
                        await asyncio.wait_for(self.event.wait(), timeout=0.25)
                    except asyncio.TimeoutError:
                        pass
                    self.event.clear()

                self._run_vad()
                self._drop_backlog()
                cut = self._next_cut()
                cut_made = cut is not None
                if cut is None:
                    if self.closing and not self.pcm:
                        self.finished = True
                        break
                    continue

                kind, nbytes = cut
                window = self._consume(nbytes)
                if kind == "speech":
                    await self._transcribe(window)
                if self.closing and not self.pcm:
                    self.finished = True
                    break
        except asyncio.CancelledError:
            self.finished = True
            raise
        except Exception as e:
            self.finished = True
            print(f"[STT] {self.lecture_id} 워커 오류 ({type(e).__name__}): {e}")
        finally:
            if _streams.get(self.lecture_id) is self and self.finished:
                del _streams[self.lecture_id]
                glossary_service.flush(self.lecture_id)
                s = self.stats
                if s["windows"]:
                    print(f"[STT] {self.lecture_id} 종료 | 구간 {s['windows']}개, 오디오 {s['audio_sec']:.0f}초, "
                          f"평균 RTF {s['infer_sec'] / max(s['audio_sec'], 1e-6):.2f}, "
                          f"건너뜀 {s['dropped_sec']:.0f}초")

    async def _transcribe(self, window: bytes) -> None:
        audio = np.frombuffer(window, dtype=np.int16).astype(np.float32) / 32768.0
        audio_sec = len(audio) / SAMPLE_RATE
        if audio_sec < 0.3:
            return
        prompt = self.prev_text[-PROMPT_CONTEXT_CHARS:] if self.prev_text else None
        loop = asyncio.get_running_loop()
        t_wait = time.perf_counter()
        async with llm.pipeline_lock.hold(llm.PRIORITY_STT):
            waited = time.perf_counter() - t_wait
            t0 = time.perf_counter()
            try:
                text, lang = await loop.run_in_executor(executor, _transcribe_sync, audio, prompt, self.hotwords)
            except Exception as e:
                print(f"[STT] 추론 오류 ({type(e).__name__}): {e}")
                return
            infer = time.perf_counter() - t0
        self.stats["windows"] += 1
        self.stats["audio_sec"] += audio_sec
        self.stats["infer_sec"] += infer

        text = _strip_repeated_prefix(self.prev_text, text)
        if not text:
            print(f"[STT] {self.lecture_id} {audio_sec:4.1f}s 구간 → {infer:4.1f}s (인식 결과 없음)")
            return
        self.prev_text = text
        t1 = time.perf_counter()
        await publish_caption(self.lecture_id, text, lang)
        print(f"[STT] {self.lecture_id} {audio_sec:4.1f}s 구간 → 대기 {waited:.1f}s + 인식 {infer:.1f}s "
              f"(RTF {infer / audio_sec:.2f}) + 저장 {time.perf_counter() - t1:.2f}s [{lang}] {text[:50]}")


async def open_stream(lecture_id: str) -> tuple[LectureStream, int]:
    stream = _streams.get(lecture_id)
    if stream is None or stream.finished:
        stream = LectureStream(lecture_id)
        _streams[lecture_id] = stream
        await stream.start()
    return stream, stream.attach()


async def close_stream(stream: LectureStream, conn_id: int) -> None:
    stream.detach(conn_id)


def stream_status(lecture_id: str) -> dict:
    stream = _streams.get(lecture_id)
    return {
        "streaming": bool(stream and stream.connections > 0),
        "backlog_sec": round(stream.backlog_sec, 1) if stream else 0.0,
        "target_lang": get_target_lang(lecture_id),
    }


def active_lecture_count() -> int:
    return sum(1 for s in _streams.values() if s.connections > 0)


def engine_info() -> dict:
    return {
        "model": settings.WHISPER_MODEL_SIZE,
        "device": WHISPER_DEVICE,
        "compute_type": settings.WHISPER_COMPUTE_TYPE,
        "beam_size": settings.WHISPER_BEAM_SIZE,
        "language": WHISPER_LANGUAGE or "auto",
        "window_sec": [MIN_WINDOW_SEC, MAX_WINDOW_SEC],
    }


async def shutdown(wait_sec: float = 15.0) -> None:
    """서버 종료 시 남은 오디오를 처리하고 워커를 정리한다."""
    streams = list(_streams.values())
    for stream in streams:
        stream.closing = True
        stream.event.set()
    workers = [s.worker for s in streams if s.worker]
    if workers:
        _, pending = await asyncio.wait(workers, timeout=wait_sec)
        for task in pending:
            task.cancel()
    executor.shutdown(wait=False, cancel_futures=True)
