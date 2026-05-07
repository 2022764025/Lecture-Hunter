import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from core.database import get_supabase

# [서비스 레이어 임포트]
from services.rag_service import get_answer_with_memory
from services.summary_service import generate_lecture_summary
from services.analytics_service import get_content_qc_analysis, get_instructor_report
from services.vlm_service import vlm_engine
from api.v1 import websocket 

# (0.1) 전역 상태 관리
# 비전 제거 후 student_scores → active_lecture_ids로 교체
# 나중에 질문 빈도, 퀴즈 정답률 등으로 확장 예정
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
    lifespan=lifespan  # lifespan 연결
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

@app.get("/", tags=["System"])
async def root():
    return {"status": "running", "engine": "STT & RAG Focused Engine"}

@app.get("/health", tags=["System"])
async def health_check():
    return {
        "status": "healthy",
        "active_lectures": len(state.active_lecture_ids),  # 실제 추적값
        "latency_target": "3-5s"
    }

# --- [기능 1] 실시간 오디오 처리 (WebSocket) ---
# 라우터(/ws/audio/{lecture_id})로 통일

# --- [기능 2] AI 조교 Q&A (RAG) ---
@app.get("/lecture/ask", tags=["AI Assistant"])
async def ask_ai_assistant(lecture_id: str, question: str, target_lang: str = "Korean"):
    try:
        answer = await get_answer_with_memory(question, lecture_id, target_lang)
        return {"question": question, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 3] 강의 분석 및 리포트 (QC/Instructor 전용) ---
@app.get("/lecture/analytics/qc/{lecture_id}", tags=["Analytics"])
async def fetch_qc_report(lecture_id: str):
    try:
        supabase = await get_supabase()  # 비동기 클라이언트로 교체
        return await get_content_qc_analysis(supabase, lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lecture/analytics/instructor/{lecture_id}", tags=["Analytics"])
async def fetch_instructor_report(lecture_id: str):
    try:
        supabase = await get_supabase()  # 비동기 클라이언트로 교체
        return await get_instructor_report(supabase, lecture_id)
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

# --- [기능 5] 슬라이드 분석 (VLM) ---
@app.post("/lecture/analyze-slide/{lecture_id}", tags=["Multimodal"])
async def analyze_slide(lecture_id: str, target_lang: str = "Korean", file: UploadFile = File(...)):
    try:
        # (1) VLM 분석
        image_bytes = await file.read()
        analysis = await vlm_engine.analyze_lecture_screen(image_bytes, target_lang=target_lang)

        has_visual = analysis["has_visual"]
        visual_context = analysis["summary"]

        # (2) 시각 자료 감지 시 최신 자막에 앵커링
        if has_visual:
            supabase = await get_supabase()

            # (2-1) 현재 강의의 최신 자막 ID 조회
            latest_content = await supabase.table('lecture_contents') \
                .select('id') \
                .eq('lecture_id', lecture_id) \
                .order('created_at', desc=True) \
                .limit(1) \
                .execute()

            # (2-2) 최신 자막에 시각 자료 플래그 + 요약 업데이트
            if latest_content.data:
                target_id = latest_content.data[0]['id']
                await supabase.table('lecture_contents') \
                    .update({
                        'has_visual': True,
                        'visual_summary': visual_context
                    }) \
                    .eq('id', target_id) \
                    .execute()
                print(f"[Anchor] 자막 ID({target_id})에 {target_lang}으로 슬라이드 정보 매핑 완료")

        return {
            "lecture_id": lecture_id,
            "has_visual": has_visual,
            "visual_context": visual_context,
            "target_lang": target_lang # 결과에 어떤 언어로 처리됐는지 포함
        }

    except Exception as e:
        print(f"[API 에러] 슬라이드 분석 중 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)