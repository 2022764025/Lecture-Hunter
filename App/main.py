import asyncio
import base64
import binascii
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from api.v1 import interaction, websocket
from core import llm
from core.config import settings
from core.database import ensure_lecture, get_supabase
from core.lang import lang_code
from services import glossary_service, stt_service
from services.rag_service import cleanup_old_histories, get_answer_with_memory, reset_lecture_history
from services.summary_service import (
    generate_adaptive_summary,
    generate_lecture_summary,
    generate_range_summary,
    get_saved_full_summary,
    lecture_timeline,
)
from services.vlm_service import InvalidImageError, VLMError, recent_lecture_text, vlm_engine

LECTURE_ID_PATTERN = r"^[\w\-.:]{1,128}$"
MAX_IMAGE_BASE64_CHARS = 14_000_000      # 약 10MB 이미지


def LectureId(default=...):  # noqa: N802 - FastAPI Query 헬퍼
    return Query(default, pattern=LECTURE_ID_PATTERN, description="강의 ID")


async def _periodic_cleanup():
    while True:
        await asyncio.sleep(600)
        try:
            await cleanup_old_histories()
        except Exception as e:
            print(f"[Cleanup] 대화 기록 정리 실패: {e}")


# (0.1) lifespan: 서버 시작/종료 시 리소스 관리
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[Startup] 서버 시작 중...")
    try:
        await get_supabase()
        print("[Startup] Supabase 연결 완료")
    except Exception as e:
        print(f"[Startup] Supabase 연결 실패: {e}")

    info = stt_service.engine_info()
    print(f"[Startup] STT: faster-whisper {info['model']} ({info['device']}, {info['compute_type']}, "
          f"beam={info['beam_size']}, 언어={info['language']}, 구간 {info['window_sec'][0]:g}~{info['window_sec'][1]:g}초)")

    try:
        missing = await llm.missing_models()
        if missing:
            print(f"[Startup] ⚠ Ollama에 없는 모델: {', '.join(missing)} → ollama pull <모델명>")
        else:
            print(f"[Startup] Ollama 모델 확인 완료 (LLM {settings.LLM_MODEL}, 임베딩 {settings.EMBED_MODEL}, "
                  f"VLM {settings.VLM_MODEL})")
    except Exception as e:
        print(f"[Startup] ⚠ Ollama에 연결할 수 없습니다 ({e}). 'ollama serve'를 먼저 실행하세요.")

    cleanup_task = asyncio.create_task(_periodic_cleanup())
    print("[Startup] 서버 준비 완료")
    yield

    print("[Shutdown] 서버 종료 중... (남은 오디오 처리)")
    cleanup_task.cancel()
    await stt_service.shutdown()
    print("[Shutdown] 완료")


# (0.2) FastAPI 앱 초기화
app = FastAPI(
    title="Lecture-Hunter Backend",
    description="실시간 자막·번역, RAG 질의응답, 용어집, 요약, 화면 질문(VLM), 익명 질문·공지 API",
    version="2.0.0",
    lifespan=lifespan,
)

# (0.3) CORS: 쿠키를 쓰지 않으므로 credentials 없이 모든 출처 허용 (로컬 위젯·크롬 확장용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(websocket.router)
app.include_router(interaction.router)


# ─── 요청 모델 ──────────────────────────────────────────────────────────

class AskRequest(BaseModel):
    lecture_id: str = Field(pattern=LECTURE_ID_PATTERN)
    question: str = Field(min_length=1, max_length=1000)
    target_lang: str = "Korean"
    client_id: Optional[str] = Field(default=None, max_length=64)


class LectureSettingsUpdate(BaseModel):
    lecture_id: str = Field(pattern=LECTURE_ID_PATTERN)
    target_lang: str = Field(min_length=1, max_length=32)


class VlmRequest(BaseModel):
    lecture_id: str = Field(pattern=LECTURE_ID_PATTERN)
    image: Optional[str] = None                 # data URL 또는 base64
    images: Optional[list[str]] = None          # 예전 프론트 호환 (첫 장만 사용)
    question: Optional[str] = Field(default=None, max_length=1000)
    target_lang: str = "Korean"


# ─── 시스템 ─────────────────────────────────────────────────────────────

@app.get("/", tags=["System"])
async def root():
    return {"status": "running", "service": "Lecture-Hunter Backend"}


@app.get("/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "active_lectures": stt_service.active_lecture_count(),
        "stt": stt_service.engine_info(),
        "models": {"llm": settings.LLM_MODEL, "embedding": settings.EMBED_MODEL, "vlm": settings.VLM_MODEL},
    }


# ─── [기능 1] 실시간 오디오 처리: api/v1/websocket.py (WS /ws/audio/{lecture_id}) ───

# ─── [기능 2] AI 조교 Q&A (RAG) ─────────────────────────────────────────

async def _ask(lecture_id: str, question: str, target_lang: str, client_id: Optional[str]):
    try:
        result = await get_answer_with_memory(question, lecture_id, target_lang, client_id)
    except Exception as e:
        print(f"[Ask] 답변 생성 실패: {e}")
        raise HTTPException(status_code=503, detail=f"AI 답변 생성 실패: {e}") from e
    return {"question": question, **result}


@app.post("/lecture/ask", tags=["AI Assistant"])
async def ask_ai_assistant(body: AskRequest):
    return await _ask(body.lecture_id, body.question.strip(), body.target_lang, body.client_id)


@app.get("/lecture/ask", tags=["AI Assistant"])
async def ask_ai_assistant_get(
    lecture_id: str = LectureId(),
    question: str = Query(min_length=1, max_length=1000),
    target_lang: str = "Korean",
    client_id: Optional[str] = Query(default=None, max_length=64),
):
    """예전 프론트·성능 측정 스크립트 호환용. 새 코드는 POST를 쓴다."""
    return await _ask(lecture_id, question.strip(), target_lang, client_id)


@app.post("/lecture/ask/reset", tags=["AI Assistant"])
async def reset_chat_history(
    lecture_id: str = LectureId(),
    client_id: Optional[str] = Query(default=None, max_length=64),
):
    removed = reset_lecture_history(lecture_id, client_id)
    return {
        "status": "success",
        "lecture_id": lecture_id,
        "removed": removed,
        "message": "질문 히스토리가 초기화되었습니다.",
    }


# ─── [기능 3] 강의 상태·설정 ─────────────────────────────────────────────

@app.post("/lecture/start", tags=["Lecture"])
async def start_lecture(lecture_id: str = LectureId()):
    try:
        await ensure_lecture(lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
    return {"status": "started", "lecture_id": lecture_id, **stt_service.stream_status(lecture_id)}


@app.post("/lecture/end", tags=["Lecture"])
async def end_lecture(lecture_id: str = LectureId(), target_lang: str = "Korean"):
    """강의 종료: 전체 요약을 만들어 lecture_summaries('full')에 저장한다."""
    try:
        summary = await generate_lecture_summary(lecture_id, target_lang)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"전체 요약 생성 실패: {e}") from e
    return {"status": "success", "lecture_id": lecture_id, "summary": summary}


@app.get("/lecture/status", tags=["Lecture"])
async def lecture_status(lecture_id: str = LectureId()):
    """강의 경과 시간(첫 자막 기준), 자막 수, 오디오 수신 여부, 번역 언어"""
    try:
        timeline = await lecture_timeline(lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
    stream = stt_service.stream_status(lecture_id)
    elapsed = 0.0
    if timeline["started_at"]:
        start = datetime.fromisoformat(timeline["started_at"].replace("Z", "+00:00"))
        end = datetime.now(timezone.utc) if stream["streaming"] else \
            datetime.fromisoformat(timeline["last_caption_at"].replace("Z", "+00:00"))
        elapsed = max(0.0, (end - start).total_seconds())
    return {"lecture_id": lecture_id, **timeline, **stream, "elapsed_sec": round(elapsed, 1)}


@app.get("/lecture/settings", tags=["Lecture"])
async def get_lecture_settings(lecture_id: str = LectureId()):
    target = stt_service.get_target_lang(lecture_id)
    return {"lecture_id": lecture_id, "target_lang": target, "target_code": lang_code(target)}


@app.put("/lecture/settings", tags=["Lecture"])
async def update_lecture_settings(body: LectureSettingsUpdate):
    """자막 번역 언어 변경. 이후 자막부터 새 언어로 번역하고, 최근 자막 3개도 다시 번역한다."""
    if lang_code(body.target_lang) is None:
        raise HTTPException(status_code=400, detail="지원 언어: ko, en, zh, ja")
    target = stt_service.set_target_lang(body.lecture_id, body.target_lang)
    stt_service.spawn(stt_service.retranslate_recent(body.lecture_id))
    print(f"[Settings] {body.lecture_id} 번역 언어 → {target}")
    return {"lecture_id": body.lecture_id, "target_lang": target, "target_code": lang_code(target)}


# ─── [기능 4] 화면 캡처 질의 (VLM) ──────────────────────────────────────

def _decode_image(request: VlmRequest) -> bytes:
    data = request.image or (request.images[0] if request.images else None)
    if not data:
        raise HTTPException(status_code=400, detail="전송된 이미지 데이터가 없습니다.")
    if len(data) > MAX_IMAGE_BASE64_CHARS:
        raise HTTPException(status_code=413, detail="이미지가 너무 큽니다 (최대 약 10MB).")
    if "," in data and data.lstrip().startswith("data:"):
        data = data.split(",", 1)[1]
    try:
        return base64.b64decode(data, validate=True)
    except (binascii.Error, ValueError) as e:
        raise HTTPException(status_code=400, detail="유효하지 않은 이미지 Base64 데이터입니다.") from e


@app.post("/api/vlm/analyze", tags=["Multimodal"])
async def analyze_slide(request: VlmRequest):
    """
    question이 있으면: 캡처 화면 + 질문 → 답변 (DB에 저장하지 않음)
    question이 없으면: 슬라이드 분석 → 시각 자료가 있으면 가장 최근 자막에 visual_summary로 연결
    """
    image_bytes = _decode_image(request)
    question = (request.question or "").strip()
    terms = await glossary_service.get_terms(request.lecture_id)   # 번역 시 전공 용어 일관성 유지
    try:
        if question:
            context = await recent_lecture_text(request.lecture_id)
            result = await vlm_engine.answer_question(image_bytes, question, request.target_lang, context, terms)
        else:
            result = await vlm_engine.analyze_slide(image_bytes, request.target_lang, terms)
    except InvalidImageError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except VLMError as e:
        print(f"[VLM] {e}")
        raise HTTPException(status_code=503, detail=str(e)) from e

    response = {
        "status": "success",
        "mode": "question" if question else "slide",
        "has_visual": result["has_visual"],
        "answer": result["answer"],
        "analysis": result["answer"],          # 예전 프론트 호환 키
        "target_lang": request.target_lang,
        "anchored_content_id": None,
    }

    if not question and result["has_visual"]:
        try:
            client = await get_supabase()
            latest = await client.table("lecture_contents").select("id") \
                .eq("lecture_id", request.lecture_id).order("id", desc=True).limit(1).execute()
            if latest.data:
                match_id = latest.data[0]["id"]
                await client.table("lecture_contents").update(
                    {"has_visual": True, "visual_summary": result["answer"]}
                ).eq("id", match_id).execute()
                response["anchored_content_id"] = match_id
        except Exception as e:
            print(f"[VLM] 자막 연결 실패: {e}")
    return response


# ─── [기능 5] 실시간 전문 용어 사전 조회 ─────────────────────────────────

@app.get("/lecture/glossary", tags=["Glossary"])
async def get_glossary(lecture_id: str = LectureId(), keyword: Optional[str] = Query(default=None, max_length=50)):
    try:
        items = await glossary_service.search(lecture_id, keyword)
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"용어집 조회 실패: {e}") from e
    return {"lecture_id": lecture_id, "keyword": keyword, "count": len(items), "glossary": items}


# ─── [기능 6] 강의 요약 ─────────────────────────────────────────────────

def _summary_error(e: Exception) -> HTTPException:
    print(f"[Summary] 요약 실패: {e}")
    return HTTPException(status_code=503, detail=f"요약 생성 실패: {e}")


@app.get("/lecture/summary/adaptive", tags=["Summary"])
async def get_adaptive_summary(
    lecture_id: str = LectureId(),
    minutes: int = Query(default=5, ge=1, le=180),
    target_lang: str = "Korean",
):
    """최근 N분 요약 (최대 180분)"""
    try:
        result = await generate_adaptive_summary(lecture_id, minutes, target_lang)
    except Exception as e:
        raise _summary_error(e) from e
    return {"lecture_id": lecture_id, **result}


@app.get("/lecture/summary/range", tags=["Summary"])
async def get_range_summary(
    lecture_id: str = LectureId(),
    start_min: float = Query(ge=0),
    end_min: float = Query(gt=0),
    target_lang: str = "Korean",
):
    """강의 시작(첫 자막) 기준 start_min ~ end_min 분 구간 요약"""
    if end_min <= start_min:
        raise HTTPException(status_code=400, detail="종료 시간은 시작 시간보다 커야 합니다.")
    try:
        result = await generate_range_summary(lecture_id, start_min, end_min, target_lang)
    except Exception as e:
        raise _summary_error(e) from e
    return {"lecture_id": lecture_id, **result}


@app.get("/lecture/summary/full", tags=["Summary"])
async def get_full_summary(lecture_id: str = LectureId(), regenerate: bool = True, target_lang: str = "Korean"):
    """강의 전체 요약. regenerate=false면 저장된 요약을 돌려준다 (없으면 새로 만든다)."""
    try:
        if not regenerate:
            saved = await get_saved_full_summary(lecture_id)
            if saved:
                return {"lecture_id": lecture_id, **saved}
        result = await generate_lecture_summary(lecture_id, target_lang)
    except Exception as e:
        raise _summary_error(e) from e
    return {"lecture_id": lecture_id, **result}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
