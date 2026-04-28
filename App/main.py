import os
import asyncio
import json
import time
# import cv2
# import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, UploadFile, File, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse
from supabase import create_client, Client

# [서비스 레이어 임포트]
from services.stt_service import process_audio_and_broadcast  # 최신 WebSocket 엔진
from services.rag_service import get_answer_with_memory
from services.summary_service import generate_lecture_summary
# from services.analytics_service import get_heatmap_data, get_drowsiness_timeline
from services.analytics_service import get_content_qc_analysis, get_instructor_report
from services.vlm_service import vlm_engine

# from services.vision_service import EngagementDetector
from api.v1 import websocket 

# 0. 설정 및 리소스 초기화
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI(
    title="EduSync AI - Optimized Backend",
    description="실시간 자막 및 RAG 기반 학습 보조 플랫폼 (리소스 최적화 버전)",
    version="1.2.0"
)

# 비전 엔진 및 카메라 초기화 (비전 엔진 제거)
# detector = EngagementDetector()
# cap = cv2.VideoCapture(0) 

class GlobalLectureState:
    def __init__(self):
        self.student_scores = {}

state = GlobalLectureState()

# 1. CORS 설정
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

"""
# --- [헬퍼] 비전 로그 저장 --- 
async def save_vision_log_to_supabase(lecture_id: str, student_id: str, result: dict):
    try:
        log_data = {
            "lecture_id": lecture_id,
            "student_id": student_id,
            "engagement_score": result.get("engagement_score"),
            "emotion": result.get("emotion"),
            "gaze_x": result.get("gaze_x"),
            "gaze_y": result.get("gaze_y"),
            "status": result.get("status"),
            "ear": result.get("ear")
        }
        supabase.table("lecture_logs").insert(log_data).execute()
    except Exception as e:
        print(f"Supabase Insert Error: {e}")

# --- [기능 1] 실시간 비전 스트리밍 (SSE) ---
@app.get("/lecture/stream-engagement/{lecture_id}")
async def stream_engagement(lecture_id: str, student_id: str, request: Request):
    async def event_generator():
        while True:
            if await request.is_disconnected():
                if student_id in state.student_scores:
                    del state.student_scores[student_id]
                break
            ret, frame = cap.read()
            if not ret:
                await asyncio.sleep(0.1)
                continue
            result = detector.analyze_frame(frame)
            if result:
                state.student_scores[student_id] = result["engagement_score"]
                await save_vision_log_to_supabase(lecture_id, student_id, result)
                yield {
                    "event": "engagement_update",
                    "data": json.dumps(result)
                }
            await asyncio.sleep(0.2)
    return EventSourceResponse(event_generator())
"""
    
# --- [기능 1] 실시간 오디오 처리 (WebSocket) ---
@app.websocket("/ws/lecture/{lecture_id}/audio")
async def websocket_audio_endpoint(websocket_conn: WebSocket, lecture_id: str, lang: str = "Korean"):
    """
    [핵심] 실시간 오디오 데이터를 WebSocket으로 수신
    VAD, Overlap, Semaphore가 적용된 엔진(stt_service)으로 전달합니다.
    """
    await websocket_conn.accept()
    print(f"{lecture_id} 오디오 스트리밍 연결됨")
    
    try:
        while True:
            # 클라이언트(Flutter/Test Script)로부터 바이너리 오디오 수신
            audio_chunk = await websocket_conn.receive_bytes()
            
            # [비차단 실행] 분석 중에도 다음 데이터를 받을 수 있게 task로 생성
            asyncio.create_task(process_audio_and_broadcast(audio_chunk, lecture_id, lang))
            
    except WebSocketDisconnect:
        print(f"{lecture_id} 오디오 연결 종료")
    except Exception as e:
        print(f"오디오 스트림 에러: {e}")

# --- [기능 2] AI 조교 Q&A (RAG) ---
@app.get("/lecture/ask", tags=["AI Assistant"])
async def ask_ai_assistant(lecture_id: str, question: str, target_lang: str = "Korean"):
    try:
        answer = await get_answer_with_memory(question, lecture_id, target_lang)
        return {"question": question, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

"""
# --- [기능 4] 교수용 실시간 통계 대시보드 ---
@app.get("/lecture/dashboard/fancy/{lecture_id}")
async def get_fancy_dashboard(lecture_id: str):
    scores = list(state.student_scores.values())
    total = len(scores)
    if total == 0:
        return {"message": "No active students", "active_students": 0}
    avg_score = sum(scores) / total
    recent_logs = supabase.table("lecture_logs").select("emotion").eq("lecture_id", lecture_id).order("created_at", desc=True).limit(total).execute()
    emotions = [d['emotion'] for d in recent_logs.data]
    emotion_dist = {emo: emotions.count(emo) for emo in set(emotions)}
    return {
        "lecture_id": lecture_id,
        "status": {
            "active_students": total,
            "average_engagement": round(avg_score, 2),
            "dominant_emotion": max(emotion_dist, key=emotion_dist.get) if emotion_dist else "Neutral"
        },
        "emotion_distribution": emotion_dist,
        "timestamp": time.time()
    }
"""

# --- [기능 3] 강의 분석 및 리포트 (QC/Instructor 전용) ---
"""
@app.get("/lecture/analytics/heatmap/{lecture_id}")
async def fetch_heatmap(lecture_id: str):
    points = await get_heatmap_data(supabase, lecture_id)
    return {"lecture_id": lecture_id, "points": points}

@app.get("/lecture/analytics/timeline/{lecture_id}")
async def fetch_timeline(lecture_id: str, student_id: str):
    timeline = await get_drowsiness_timeline(supabase, lecture_id, student_id)
    return {"lecture_id": lecture_id, "student_id": student_id, "drowsy_segments": timeline}
"""

@app.get("/lecture/analytics/qc/{lecture_id}", tags=["Analytics"])
async def fetch_qc_report(lecture_id: str):
    return await get_content_qc_analysis(supabase, lecture_id)

@app.get("/lecture/analytics/instructor/{lecture_id}", tags=["Analytics"])
async def fetch_instructor_report(lecture_id: str):
    return await get_instructor_report(supabase, lecture_id)

# --- [기능 4] 강의 종료 및 자동 요약 ---
@app.post("/lecture/end/{lecture_id}", tags=["Lecture"])
async def end_lecture(lecture_id: str):
    try:
        summary_result = await generate_lecture_summary(lecture_id)
        return {"status": "success", "summary": summary_result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/health", tags=["System"])
async def health_check():
    # 현재 서버의 부하 상태나 연결된 세션 수를 반환
    return {
        "status": "healthy",
        "active_lectures": len(state.student_scores),
        "latency_target": "3-5s"
    }

# [기능 추가] 슬라이드 분석 엔드포인트
@app.post("/lecture/analyze-slide/{lecture_id}", tags=["Multimodal"])
async def analyze_slide(lecture_id: str, file: UploadFile = File(...)):
    image_bytes = await file.read()
    # 비동기로 화면 분석 실행
    analysis = await vlm_engine.analyze_lecture_screen(image_bytes)
    return {"lecture_id": lecture_id, "visual_context": analysis}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)