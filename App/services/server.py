from fastapi import FastAPI
from pydantic import BaseModel
import datetime

app = FastAPI()

# 1. 클라이언트(test_vision.py)의 payload와 형식을 완벽히 일치시킴
class StudentData(BaseModel):
    session_id: str
    ear: float
    gaze_x: float
    gaze_y: float
    emotion: str
    engagement_score: float 

@app.post("/submit_data") # 주소를 /submit_data로 변경
async def receive_data(data: StudentData):
    timestamp = datetime.datetime.now().strftime('%H:%M:%S')
    
    # 서버 터미널에 실시간으로 데이터가 찍히는지 확인용
    print(f"[{timestamp}] 수신 성공 | EAR: {data.ear:.2f} | 감정: {data.emotion} | 점수: {data.engagement_score:.2f}")
    
    return {"status": "success", "class_average": 0.5} # 우선 임시값 반환

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)