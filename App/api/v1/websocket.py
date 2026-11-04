"""
<설명>
실시간 오디오 WebSocket

(1) 브라우저/확장 오디오 (트랙 A)
    - ws://<host>:8000/ws/audio/{lecture_id}?target_lang=Korean&title=<강의 제목(선택)>
    - 바이너리 프레임: 16kHz / 16-bit Little-Endian / mono PCM (헤더 없음)
    - 텍스트 프레임: 연결 확인용 heartbeat
        "ping" 또는 {"type": "ping"}   →  {"type": "pong", ...}
        {"type": "config", "target_lang": "English"}  →  강의 번역 언어 변경
    - 연결 직후 서버가 {"type": "ready", ...}를 한 번 보낸다.
(2) 유튜브 강의 (트랙 B)
    - ws://<host>:8000/ws/audio/{lecture_id}?youtube=<영상 주소 또는 ID>
      (예전 방식 ws://<host>:8000/ws/audio?lecture_id=<영상ID 또는 주소>&source=youtube 도 지원)
    - 서버가 yt-dlp + ffmpeg로 영상 오디오를 실시간 속도(-re)로 읽어 같은 STT 파이프라인에 넣는다.
    - 클라이언트가 연결을 끊으면 ffmpeg도 바로 종료한다.
    - 예전에는 길이가 11글자인 ID를 전부 유튜브로 판정해서 'lecture-123' 같은 탭 ID가 오인됐다.
      이제 source=youtube 이거나 유튜브 주소일 때만 유튜브로 처리한다.
"""

import asyncio
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

from core.database import ensure_lecture
from services import stt_service
from services.audio_service import process_lecture_audio

router = APIRouter()

LECTURE_ID_RE = re.compile(r"^[\w\-.:]{1,128}$")
YOUTUBE_ID_RE = re.compile(r"(?:v=|youtu\.be/|/embed/|/shorts/|/live/)([A-Za-z0-9_-]{11})")
YOUTUBE_PLAIN_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
MAX_FRAME_BYTES = 1_000_000          # 100ms PCM은 3,200바이트. 비정상적으로 큰 프레임은 버린다
YOUTUBE_CHUNK_BYTES = 3200           # 100ms 분량


def parse_youtube_id(value: str) -> Optional[str]:
    match = YOUTUBE_ID_RE.search(value)
    if match:
        return match.group(1)
    return value if YOUTUBE_PLAIN_ID_RE.match(value) else None


def _find_tool(name: str) -> Optional[str]:
    """가상환경에 설치된 도구(yt-dlp)를 먼저 찾고, 없으면 PATH에서 찾는다."""
    local = Path(sys.executable).parent / name
    if local.exists():
        return str(local)
    return shutil.which(name)


def _is_open(websocket: WebSocket) -> bool:
    return (websocket.client_state == WebSocketState.CONNECTED
            and websocket.application_state == WebSocketState.CONNECTED)


async def _send_json(websocket: WebSocket, payload: dict) -> None:
    if _is_open(websocket):
        try:
            await websocket.send_json(payload)
        except Exception:
            pass


async def _close(websocket: WebSocket, code: int = 1000, reason: Optional[str] = None) -> None:
    """클라이언트가 먼저 끊었으면 아무것도 하지 않는다 (이미 닫힌 소켓에 close를 보내면 예외)."""
    if _is_open(websocket):
        try:
            await websocket.close(code=code, reason=reason)
        except Exception:
            pass


async def _handle_text(websocket: WebSocket, stream: "stt_service.LectureStream", text: str) -> None:
    text = text.strip()
    message: dict = {}
    if text.lower() == "ping":
        message = {"type": "ping"}
    else:
        try:
            parsed = json.loads(text)
            message = parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return

    kind = message.get("type")
    if kind == "ping":
        await _send_json(websocket, {
            "type": "pong",
            "lecture_id": stream.lecture_id,
            "backlog_sec": round(stream.backlog_sec, 1),
        })
    elif kind == "config" and message.get("target_lang"):
        lang = stt_service.set_target_lang(stream.lecture_id, str(message["target_lang"]))
        await _send_json(websocket, {"type": "config", "target_lang": lang})


@router.websocket("/ws/audio")
@router.websocket("/ws/audio/")
@router.websocket("/ws/audio/{lecture_id}")
async def audio_websocket(websocket: WebSocket, lecture_id: Optional[str] = None):
    await websocket.accept()
    params = websocket.query_params

    raw_id = (lecture_id or params.get("lecture_id") or "").strip()
    source = (params.get("source") or "").strip().lower()
    youtube_param = (params.get("youtube") or "").strip()
    youtube_url = None
    if youtube_param or source == "youtube" or "youtube.com" in raw_id or "youtu.be" in raw_id:
        # ?youtube=<주소 또는 영상ID> 를 주면 lecture_id는 따로 쓸 수 있다 (같은 영상을 다시 틀어도 새 강의로 기록).
        # 없으면 예전처럼 lecture_id 자체를 영상 주소/ID로 보고, 영상 ID를 강의 ID로 쓴다.
        video_id = parse_youtube_id(youtube_param or raw_id)
        if not video_id:
            print(f"[WebSocket] 연결 거부: 유튜브 영상 ID를 찾을 수 없음 ({(youtube_param or raw_id)[:80]})")
            await _close(websocket, 4001, "invalid youtube id")
            return
        if not youtube_param or not raw_id:
            raw_id = video_id
        youtube_url = f"https://www.youtube.com/watch?v={video_id}"

    if not LECTURE_ID_RE.match(raw_id):
        print("[WebSocket] 연결 거부: lecture_id가 없거나 형식이 잘못됨")
        await _close(websocket, 4000, "invalid lecture_id")
        return
    lid = raw_id

    # 크롬 확장은 탭 제목을 ?title= 로 보낸다 (lectures.title). 제어 문자는 지우고 200자로 자른다.
    title = re.sub(r"[\x00-\x1f\x7f]", " ", params.get("title") or "").strip()[:200]
    if not title:
        title = f"유튜브 인강 ({lid})" if youtube_url else f"실시간 강의 - {lid}"

    try:
        await ensure_lecture(lid, title)
    except Exception as e:
        print(f"[WebSocket] lectures 행 생성 실패 ({lid}): {e}")
        await _close(websocket, 1011, "database error")
        return

    if params.get("target_lang"):
        stt_service.set_target_lang(lid, params["target_lang"], only_if_unset=True)

    stream, conn_id = await stt_service.open_stream(lid)
    conn = _Connection(stream, conn_id)
    print(f"[WebSocket] {lid} 연결 (#{conn_id}, {'유튜브' if youtube_url else '클라이언트 오디오'}, "
          f"번역 언어: {stt_service.get_target_lang(lid)})")
    await _send_json(websocket, {
        "type": "ready",
        "lecture_id": lid,
        "target_lang": stt_service.get_target_lang(lid),
        "stt": stt_service.engine_info(),
    })

    try:
        if youtube_url:
            await _run_youtube(websocket, conn, youtube_url)
        else:
            await _run_client_audio(websocket, conn)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"[WebSocket] {lid} 오류 ({type(e).__name__}): {e}")
    finally:
        await stt_service.close_stream(conn.stream, conn.id)
        await _close(websocket)   # 서버가 먼저 끝낸 경우(유튜브 영상 종료 등) close 프레임을 보낸다
        print(f"[WebSocket] {lid} 연결 종료 (#{conn.id}) — 남은 오디오는 워커가 마저 처리합니다")


class _Connection:
    """현재 연결이 쓰는 스트림. 워커가 오류로 끝나 새 스트림으로 바뀔 수 있어서 묶어서 넘긴다."""

    def __init__(self, stream: "stt_service.LectureStream", conn_id: int):
        self.stream = stream
        self.id = conn_id

    async def feed(self, data: bytes) -> None:
        if process_lecture_audio(self.stream, self.id, data) or not self.stream.finished:
            return
        # 워커가 오류로 끝났으면 새 스트림을 열어 이어 받는다
        await stt_service.close_stream(self.stream, self.id)
        self.stream, self.id = await stt_service.open_stream(self.stream.lecture_id)
        process_lecture_audio(self.stream, self.id, data)


async def _run_client_audio(websocket: WebSocket, conn: _Connection) -> None:
    while True:
        message = await websocket.receive()
        if message["type"] == "websocket.disconnect":
            return

        data = message.get("bytes")
        if data:
            if len(data) <= MAX_FRAME_BYTES:
                await conn.feed(data)
            continue

        text = message.get("text")
        if text:
            await _handle_text(websocket, conn.stream, text)


async def _run_youtube(websocket: WebSocket, conn: _Connection, url: str) -> None:
    ytdlp, ffmpeg = _find_tool("yt-dlp"), _find_tool("ffmpeg")
    if not ytdlp or not ffmpeg:
        missing = ", ".join(n for n, p in (("yt-dlp", ytdlp), ("ffmpeg", ffmpeg)) if not p)
        print(f"[YouTube] 필요한 도구가 없습니다: {missing}")
        await _send_json(websocket, {"type": "error", "message": f"서버에 {missing}가 설치되어 있지 않습니다."})
        await _close(websocket, 1011)
        return

    print(f"[YouTube] 오디오 스트림 주소 추출: {url}")
    probe = await asyncio.create_subprocess_exec(
        ytdlp, "--no-update", "--no-playlist", "-g", "-f", "bestaudio/best", url,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    try:
        out, err = await asyncio.wait_for(probe.communicate(), timeout=60)
    except asyncio.TimeoutError:
        probe.kill()
        out, err = b"", b"timeout"
    lines = out.decode(errors="ignore").strip().splitlines()
    if not lines:
        message = err.decode(errors="ignore").strip().splitlines()[-1:] or ["unknown error"]
        print(f"[YouTube] 스트림 주소 획득 실패: {message[0]}")
        await _send_json(websocket, {"type": "error", "message": "유튜브 오디오를 가져오지 못했습니다."})
        await _close(websocket, 1011)
        return

    ff = await asyncio.create_subprocess_exec(
        ffmpeg, "-loglevel", "error",
        "-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "5",
        "-re", "-i", lines[0],
        "-vn", "-f", "s16le", "-ac", "1", "-ar", "16000", "pipe:1",
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
    )
    print("[YouTube] 실시간 오디오 수신 시작")

    async def pump():
        while True:
            chunk = await ff.stdout.read(YOUTUBE_CHUNK_BYTES)
            if not chunk:
                return
            await conn.feed(chunk)

    async def watch_client():
        while True:
            message = await websocket.receive()
            if message["type"] == "websocket.disconnect":
                return
            if message.get("text"):
                await _handle_text(websocket, conn.stream, message["text"])

    pump_task = asyncio.create_task(pump())
    watch_task = asyncio.create_task(watch_client())
    try:
        done, pending = await asyncio.wait({pump_task, watch_task}, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        if pump_task in done:
            print("[YouTube] 영상 오디오가 끝났습니다")
            await _send_json(websocket, {"type": "youtube_ended"})
    finally:
        if ff.returncode is None:
            ff.kill()
            await ff.wait()
        print("[YouTube] ffmpeg 종료")
