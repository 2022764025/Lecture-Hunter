from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from api.v1 import websocket
from services.rag_service import get_answer_with_memory
from services.summary_service import generate_lecture_summary

app = FastAPI(title="EduSync AI", version="0.1.0")

# 1. CORS 설정: 프론트엔드(Flutter/Chrome)와의 원활한 통신을 위해 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. 실시간 음성 인식을 위한 웹소켓 라우터 연결
app.include_router(websocket.router)

@app.get("/")
async def root():
    return {"message": "EduSync AI Backend is running"}

# 3. 실시간 질문 답변 (RAG): 이전 대화 맥락을 기억함
@app.get("/ask")
async def ask_question(question: str, lecture_id: str):
    try:
        answer = await get_answer_with_memory(question, lecture_id)
        return {"question": question, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"RAG Error: {str(e)}")

# 4. [통합] 강의 종료 및 자동 요약 실행
# 이 엔드포인트는 강의 종료 버튼과 매칭
@app.post("/lecture/end/{lecture_id}")
async def end_lecture(lecture_id: str):
    """
    강의를 종료하고 그동안 쌓인 자막 데이터를 기반으로 
    Gemma-2:2b 모델을 통해 요약 및 키워드 추출을 수행합니다.
    """
    try:
        # DB(Supabase)에 저장된 내용을 바탕으로 요약 생성 및 저장
        summary_result = await generate_lecture_summary(lecture_id)
        
        return {
            "status": "success", 
            "message": f"Lecture '{lecture_id}' has been finalized.",
            "summary": summary_result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Summary Generation Failed: {str(e)}")

# 5. 수동 요약 생성 (기존 로직 유지)
@app.post("/summarize/{lecture_id}")
async def summarize_lecture(lecture_id: str):
    result = await generate_lecture_summary(lecture_id)
    return {"status": "success", "summary": result}