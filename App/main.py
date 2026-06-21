import base64
from pydantic import BaseModel
import asyncio
from datetime import datetime, timedelta
from typing import Optional
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from core.database import get_supabase

# [서비스 레이어 임포트]
from services.rag_service import get_answer_with_memory, reset_lecture_history
from services.analytics_service import (
    get_interaction_intensity,
    get_student_inactivity_timeline,
    get_content_qc_analysis,
    get_instructor_report
)
from services.vlm_service import vlm_engine
from services.summary_service import generate_lecture_summary, generate_adaptive_summary
from api.v1 import websocket 

# (0.1) 전역 상태 관리
class GlobalLectureState:
    def __init__(self):
        self.active_lecture_ids: set = set()

state = GlobalLectureState()

# (0.2) lifespan: 서버 시작/종료 시 리소스 관리
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[Startup] 서버 시작 중...")

    try:
        await get_supabase()
        print("[Startup] Supabase 연결 완료")
    except Exception as e:
        print(f"[Startup] Supabase 연결 실패: {e}")

    try:
        from services.stt_service import stt_model, vad_model
        print("[Startup] STT 모델 로딩 완료")
    except Exception as e:
        print(f"[Startup] STT 모델 로딩 실패: {e}")

    print("[Startup] 서버 준비 완료")
    yield

    print("[Shutdown] 서버 종료 중...")
    from services.stt_service import executor
    executor.shutdown(wait=False)
    print("[Shutdown] 스레드 풀 종료 완료")

# (0.3) FastAPI 앱 초기화
app = FastAPI(
    title="EduSync AI - Optimized Backend",
    description="실시간 자막 및 RAG 기반 학습 보조 플랫폼 (리소스 최적화 버전)",
    version="1.2.0",
    lifespan=lifespan  
)

# (0.4) CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(websocket.router)

# ─── [2번 기능 동기화] 플러터 웹 JSON 수신용 Pydantic 모델 선언 ───
class VlmRequest(BaseModel):
    image: Optional[str] = None   # [이중 방어막] 옛날 단수형 요청 포트 유지
    images: Optional[list[str]] = None # [이중 방어막] 신규 다중 이미지 리스트 포트 수용
    lecture_id: str
    question: Optional[str] = None

@app.get("/", tags=["System"])
async def root():
    return {"status": "running", "engine": "STT & RAG Focused Engine"}

@app.get("/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "active_lectures": len(state.active_lecture_ids),  
        "latency_target": "3-5s"
    }

# --- [기능 1] 실시간 오디오 처리 (WebSocket) ---

# --- [기능 2] AI 조교 Q&A (RAG) ---
@app.get("/lecture/ask", tags=["AI Assistant"])
async def ask_ai_assistant(lecture_id: str, question: str, target_lang: str = "Korean"):
    try:
        answer = await get_answer_with_memory(question, lecture_id, target_lang)
        return {"question": question, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lecture/ask/reset", tags=["AI Assistant"])
async def reset_chat_history(lecture_id: str):
    try:
        reset_lecture_history(lecture_id)
        return {
            "status": "success",
            "lecture_id": lecture_id,
            "message": "질문 히스토리가 초기화되었습니다."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 3] 강의 분석 및 리포트 (QC/Instructor 전용) ---
@app.get("/lecture/analytics/qc/{lecture_id}", tags=["Analytics"])
async def fetch_qc_report(lecture_id: str):
    try:
        supabase = await get_supabase()
        return await get_content_qc_analysis(supabase, lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lecture/analytics/instructor/{lecture_id}", tags=["Analytics"])
async def fetch_instructor_report(lecture_id: str):
    try:
        supabase = await get_supabase()
        return await get_instructor_report(supabase, lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lecture/analytics/interaction/{lecture_id}", tags=["Analytics"])
async def fetch_interaction_intensity(lecture_id: str):
    try:
        supabase = await get_supabase()
        return await get_interaction_intensity(supabase, lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lecture/analytics/inactivity/{lecture_id}", tags=["Analytics"])
async def fetch_inactivity_timeline(lecture_id: str, student_id: str):
    try:
        supabase = await get_supabase()
        return await get_student_inactivity_timeline(supabase, lecture_id, student_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 4] 강의 시작 및 종료, 자동 요약 ---
@app.post("/lecture/start/{lecture_id}", tags=["Lecture"])
async def start_lecture(lecture_id: str):
    try:
        state.active_lecture_ids.add(lecture_id)
        print(f"[Lecture] {lecture_id} 강의 시작 | 현재 활성 강의: {len(state.active_lecture_ids)}개")
        return {
            "status": "started",
            "lecture_id": lecture_id,
            "active_lectures": len(state.active_lecture_ids)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lecture/end/{lecture_id}", tags=["Lecture"])
async def end_lecture(lecture_id: str):
    try:
        state.active_lecture_ids.discard(lecture_id)
        print(f"[Lecture] {lecture_id} 강의 종료 | 현재 활성 강의: {len(state.active_lecture_ids)}개")
        summary_result = await generate_lecture_summary(lecture_id)
        return {
            "status": "success",
            "lecture_id": lecture_id,
            "active_lectures": len(state.active_lecture_ids),
            "summary": summary_result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 5] 슬라이드 분석 및 정밀 앵커링 (VLM) 최종본 ---
@app.post("/api/vlm/analyze", tags=["Multimodal"])
async def analyze_slide(request: VlmRequest):
    try:
        lecture_id = request.lecture_id
        user_prompt = request.question if request.question else "현재 화면 슬라이드의 시각 자료를 분석해줘."
        target_lang = "Korean"

        # [500 에러 원천 차단] 단수형/복수형 어떤 규격으로 들어오든 첫 번째 이미지를 안전하게 가로채는 믹스 체인
        base64_data = None
        if request.images and len(request.images) > 0:
            base64_data = request.images[0]
        elif request.image:
            base64_data = request.image

        if not base64_data:
            raise HTTPException(status_code=400, detail="전송된 이미지 데이터가 없습니다.")
        
        if "," in base64_data:
            base64_data = base64_data.split(",")[1]
        
        try:
            image_bytes = base64.b64decode(base64_data)
        except Exception:
            raise HTTPException(status_code=400, detail="유효하지 않은 이미지 Base64 데이터 규격입니다.")

        # VLM 분석 엔진 구동 (Llama3.2-Vision)
        analysis = await vlm_engine.analyze_lecture_screen(
            image_bytes,
            target_lang=target_lang,
            prompt=user_prompt
        )

        # 유저 커스텀 질문 처리 분기 우회
        if request.question:
            if isinstance(analysis, dict):
                visual_context = analysis.get("summary", analysis.get("analysis", str(analysis)))
            else:
                visual_context = str(analysis)
            has_visual = True
        else:
            has_visual = analysis.get("has_visual", False) if isinstance(analysis, dict) else False
            visual_context = analysis.get("summary", "") if isinstance(analysis, dict) else str(analysis)

        if not has_visual:
            return {
                "status": "success",
                "has_visual": False,
                "analysis": "시각 자료가 감지되지 않았습니다."
            }

        supabase = await get_supabase()
        
        latest = await supabase.table('lecture_contents') \
            .select('id') \
            .eq('lecture_id', lecture_id) \
            .order('created_at', desc=True) \
            .limit(1) \
            .execute()

        match_id = latest.data[0]['id'] if latest.data else None

        if match_id:
            await supabase.table('lecture_contents') \
                .update({
                    'has_visual': True,
                    'visual_summary': visual_context
                }) \
                .eq('id', match_id) \
                .execute()

            return {
                "status": "success",
                "has_visual": True,
                "anchored_content_id": match_id,
                "analysis": visual_context,  
                "target_lang": target_lang
            }

        return {
            "status": "success",
            "has_visual": True,
            "analysis": visual_context
        }

    except Exception as e:
        print(f"[Anchor Error] {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 6] 실시간 전문 용어 사전 조회 ---
@app.get("/lecture/glossary/{lecture_id}", tags=["Glossary"])
async def get_glossary(lecture_id: str, keyword: str = None):
    try:
        supabase = await get_supabase()

        query = supabase.table("lecture_glossary") \
            .select("term, definition, created_at") \
            .eq("lecture_id", lecture_id) \
            .order("created_at", desc=True)

        if keyword:
            query = query.ilike("term", f"%{keyword}%")

        result = await query.execute()

        return {
            "lecture_id": lecture_id,
            "keyword": keyword,
            "count": len(result.data),
            "glossary": result.data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 7] 실시간 구간별 요약 브리핑 (Adaptive Briefing) ---
@app.get("/lecture/summary/adaptive/{lecture_id}", tags=["Summary"])
async def get_adaptive_summary(lecture_id: str, minutes: int = 5):
    try:
        minutes = min(minutes, 30)
        summary = await generate_adaptive_summary(lecture_id, minutes=minutes)
        return {
            "lecture_id": lecture_id,
            "minutes": minutes,
            "summary": summary
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)