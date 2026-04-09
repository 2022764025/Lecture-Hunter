import os
import asyncio
import json
import time
import cv2
import numpy as np
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse
from supabase import create_client, Client

# [서비스 레이어 임포트] - 민재님이 고생해서 만든 파일들
from services.audio_service import process_lecture_audio # STT/번역/인덱싱 통합본
from services.rag_service import get_answer_with_memory # 히스토리 기반 RAG
from services.summary_service import generate_lecture_summary
from services.analytics_service import (
    get_heatmap_data, 
    get_drowsiness_timeline, 
    get_content_qc_analysis,
    get_instructor_report
)
from services.vision_service import EngagementDetector
from api.v1 import websocket 

# 0. 설정 및 리소스 초기화
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI(title="EduSync AI - Final", version="1.0.0")

# 비전 엔진 및 카메라 초기화
detector = EngagementDetector()
cap = cv2.VideoCapture(0) 

class GlobalLectureState:
    def __init__(self):
        # 실시간 익명 집계를 위한 저장소 {student_id: current_score}
        self.student_scores = {}

state = GlobalLectureState()

# 1. CORS 설정 (Flutter 앱 연동 필수)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(websocket.router)

@app.get("/")
async def root():
    return {"status": "running", "message": "EduSync AI Backend is fully integrated."}

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
                    "id": str(int(time.time() * 1000)),
                    "data": json.dumps(result)
                }
            await asyncio.sleep(0.2)
    return EventSourceResponse(event_generator())

# --- [기능 2] 실시간 오디오 처리 (STT / 번역 / DB 인덱싱) ---
@app.post("/lecture/audio/{lecture_id}")
async def upload_audio_chunk(
    lecture_id: str, 
    target_lang: str = "Korean", # 기본값은 한국어로 설정
    file: UploadFile = File(...)
):
    """
    [핵심] Flutter에서 보낸 오디오 데이터를 받아 
    stt_service 로직을 통해 실시간 자막 생성 및 RAG용 DB 저장을 수행합니다.
    """
    try:
        audio_data = await file.read()
        # stt_service의 환각 필터, VAD, DB 저장 로직이 여기서 한꺼번에 실행됨
        result = await process_lecture_audio(audio_data, lecture_id, target_lang)
        return {"status": "success", "transcribed": result}
    except Exception as e:
        print(f"Audio Processing Error: {e}")
        return {"status": "error", "message": str(e)}

# --- [기능 3] AI 조교 Q&A (RAG with Memory) ---
@app.get("/lecture/ask")
async def ask_ai_assistant(lecture_id: str, question: str, target_lang: str = "Korean"):
    """
    [핵심] Claude가 최적화해준 히스토리 기반 RAG 엔진을 호출합니다.
    """
    try:
        answer = await get_answer_with_memory(question, lecture_id, target_lang)
        return {"question": question, "answer": answer}
    except Exception as e:
        print(f"RAG Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 4] 교수용 실시간 통계 대시보드 ---
@app.get("/lecture/dashboard/fancy/{lecture_id}")
async def get_fancy_dashboard(lecture_id: str):
    scores = list(state.student_scores.values())
    total = len(scores)
    
    if total == 0:
        return {"message": "No active students", "active_students": 0}

    avg_score = sum(scores) / total
    
    recent_logs = supabase.table("lecture_logs") \
        .select("emotion") \
        .eq("lecture_id", lecture_id) \
        .order("created_at", desc=True) \
        .limit(total) \
        .execute()
    
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

# --- [기능 5] 강의 사후 분석 (Heatmap, Timeline, QC, Instructor) ---
@app.get("/lecture/analytics/heatmap/{lecture_id}")
async def fetch_heatmap(lecture_id: str):
    points = await get_heatmap_data(supabase, lecture_id)
    return {"lecture_id": lecture_id, "points": points}

@app.get("/lecture/analytics/timeline/{lecture_id}")
async def fetch_timeline(lecture_id: str, student_id: str):
    timeline = await get_drowsiness_timeline(supabase, lecture_id, student_id)
    return {"lecture_id": lecture_id, "student_id": student_id, "drowsy_segments": timeline}

@app.get("/lecture/analytics/qc/{lecture_id}")
async def fetch_qc_report(lecture_id: str):
    return await get_content_qc_analysis(supabase, lecture_id)

@app.get("/lecture/analytics/instructor/{lecture_id}")
async def fetch_instructor_report(lecture_id: str):
    return await get_instructor_report(supabase, lecture_id)

# --- [기능 6] 강의 종료 및 요약 생성 ---
@app.post("/lecture/end/{lecture_id}")
async def end_lecture(lecture_id: str):
    try:
        summary_result = await generate_lecture_summary(lecture_id)
        return {"status": "success", "summary": summary_result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)