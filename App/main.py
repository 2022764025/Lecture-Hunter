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

@app.post("/lecture/ask/reset", tags=["AI Assistant"])
async def reset_chat_history(lecture_id: str):
    """
    Flutter '새 질문 시작' 버튼 클릭 시 호출
    해당 강의의 질문 히스토리 초기화
    """
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

# 신규 추가: 인터랙션 분포
@app.get("/lecture/analytics/interaction/{lecture_id}", tags=["Analytics"])
async def fetch_interaction_intensity(lecture_id: str):
    try:
        supabase = await get_supabase()
        return await get_interaction_intensity(supabase, lecture_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 신규 추가: 집중 공백 타임라인
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

# --- [기능 5] 슬라이드 분석 및 정밀 앵커링 (VLM) ---
@app.post("/lecture/analyze-slide/{lecture_id}", tags=["Multimodal"])
async def analyze_slide(
    lecture_id: str,
    file: UploadFile = File(...),
    target_lang: str = "Korean",                # Query Parameter 유지
    client_timestamp: Optional[str] = None      # Flutter 캡처 시점 (ISO 8601)
):
    try:
        # 1. VLM 분석
        image_bytes = await file.read()
        analysis = await vlm_engine.analyze_lecture_screen(
            image_bytes,
            target_lang=target_lang
        )

        has_visual = analysis.get("has_visual", False)
        visual_context = analysis.get("summary", "")

        # 시각 자료 없으면 DB 탐색 없이 즉시 리턴
        if not has_visual:
            return {
                "status": "success",
                "has_visual": False,
                "message": "시각 자료가 감지되지 않았습니다."
            }

        supabase = await get_supabase()
        match_id = None

        # 2. 정밀 앵커링: client_timestamp 있을 때
        if client_timestamp:
            try:
                # iso8601 라이브러리 없이 내장 모듈로 파싱
                client_dt = datetime.fromisoformat(
                    client_timestamp.replace("Z", "+00:00")
                )
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="client_timestamp 형식 오류. ISO 8601 형식으로 보내주세요. 예: 2026-05-19T14:00:05Z"
                )

            # ±5초 시간 윈도우로 후보 자막 조회
            start_window = (client_dt - timedelta(seconds=5)).isoformat()
            end_window   = (client_dt + timedelta(seconds=5)).isoformat()

            candidates = await supabase.table('lecture_contents') \
                .select('id, created_at') \
                .eq('lecture_id', lecture_id) \
                .gte('created_at', start_window) \
                .lte('created_at', end_window) \
                .execute()

            if candidates.data:
                # 시간 차이가 가장 작은 자막에 앵커링
                best = min(
                    candidates.data,
                    key=lambda x: abs((
                        datetime.fromisoformat(
                            x['created_at'].replace("Z", "+00:00")
                        ) - client_dt
                    ).total_seconds())
                )
                match_id = best['id']
                diff = abs((
                    datetime.fromisoformat(
                        best['created_at'].replace("Z", "+00:00")
                    ) - client_dt
                ).total_seconds())
                print(f"[Anchor] 정밀 매칭 성공 | 자막 ID: {match_id} | 오차: {diff}초")

            else:
                # Fallback: 윈도우 벗어난 경우 캡처 시점 직전 최신 자막
                fallback = await supabase.table('lecture_contents') \
                    .select('id') \
                    .eq('lecture_id', lecture_id) \
                    .lte('created_at', client_timestamp) \
                    .order('created_at', desc=True) \
                    .limit(1) \
                    .execute()

                if fallback.data:
                    match_id = fallback.data[0]['id']
                    print(f"[Anchor] Fallback 매칭 | 자막 ID: {match_id}")

        else:
            # client_timestamp 없을 때: 단순 최신 자막에 앵커링
            latest = await supabase.table('lecture_contents') \
                .select('id') \
                .eq('lecture_id', lecture_id) \
                .order('created_at', desc=True) \
                .limit(1) \
                .execute()

            if latest.data:
                match_id = latest.data[0]['id']
                print(f"[Anchor] 최신 자막 매칭 | 자막 ID: {match_id}")

        # 3. DB 업데이트
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
                "visual_context": visual_context,
                "target_lang": target_lang
            }

        return {
            "status": "success",
            "has_visual": True,
            "message": "시각 자료는 감지됐으나 매칭할 자막을 찾지 못했습니다."
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[Anchor Error] {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- [기능 6] 실시간 전문 용어 사전 조회 ---
@app.get("/lecture/glossary/{lecture_id}", tags=["Glossary"])
async def get_glossary(lecture_id: str, keyword: str = None):
    """
    해당 강의의 전문 용어 사전 조회
    keyword 파라미터로 특정 용어 검색 가능
    Flutter 용어 위젯에서 호출
    """
    try:
        supabase = await get_supabase()

        query = supabase.table("lecture_glossary") \
            .select("term, definition, created_at") \
            .eq("lecture_id", lecture_id) \
            .order("created_at", desc=True)

        # 키워드 검색 필터
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
    """
    최근 N분간의 강의 내용을 3줄로 요약
    학생이 '지금까지 요약' 버튼 누를 때 호출
    minutes: 요약할 구간 (기본 5분, 최대 30분)
    """
    try:
        # 최대 30분으로 제한 (너무 길면 토큰 초과)
        minutes = min(minutes, 30)
        summary = await generate_adaptive_summary(lecture_id, minutes=minutes)
        return {
            "lecture_id": lecture_id,
            "minutes": minutes,
            "summary": summary
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
# --- [임시 추가] 실시간 자막 브로드캐스트 연동 테스트용 엔드포인트 (가입 절차 추가 완료) ---
'''
@app.post("/lecture/test-broadcast/{lecture_id}", tags=["Test"])
async def test_supabase_broadcast(lecture_id: str):
    """
    백엔드에서 Supabase Realtime 채널로 가짜 자막을 송신하여
    프론트엔드(Flutter) 화면에 실시간으로 자막이 꽂히는지 선제 검증하는 API
    """
    try:
        # 1. 메인 인프라에서 초기화된 Supabase 클라이언트 획득
        supabase = await get_supabase()
        
        # 2. 수지 분의 프론트엔드(sse_service.dart)가 리스닝하는 방(채널) 생성
        channel_name = f"lecture_{lecture_id}"
        realtime_channel = supabase.channel(channel_name)
        
        # 3. 🔥 [결정적 수정] 브로드캐스트 패킷을 밀어 넣기 전에 채널에 먼저 연결(Join)합니다.
        await realtime_channel.subscribe()
        
        # 4. 프론트엔드 데이터 바인딩 규격에 맞춘 가짜 자막 데이터 구조화
        mock_payload = {
            "id": "realtime_test_uuid_999",
            "original_text": "인공지능학과 실시간 연동 테스트 중입니다. 음성 인식 자막이 정상적으로 출력됩니다.",
            "translated_text": "AI Department real-time integration test in progress. Voice recognition captions are displayed normally.",
            "language": "ko",
            "has_visual": False
        }
        
        # 5. 채널 가입이 수락된 상태에서 'new_caption' 이벤트 명세로 패킷 브로드캐스트
        response = await realtime_channel.send_broadcast(
            "new_caption",   # 1번째 인자: 이벤트명
            mock_payload     # 2번째 인자: 전송할 페이로드
        )
        
        print(f"[Supabase Broadcast] 채널 {channel_name} 가입 및 자막 송신 완료")
        
        return {
            "status": "success",
            "channel": channel_name,
            "sent_data": mock_payload,
            "supabase_status": str(response)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
'''

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)