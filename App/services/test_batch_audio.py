import asyncio
import websockets
import os
from pydub import AudioSegment

# 1. 설정 (서버에 정의된 @app.websocket 주소와 일치해야 함)
SESSION_ID = "lect01" 
WS_URL = f"ws://localhost:8000/ws/lecture/{SESSION_ID}/audio?lang=Korean"
FILE_PATH = os.path.expanduser("~/LiveLectureAI/test_samples/test_batch_es.mp3")
CHUNK_SIZE = 8000 # 0.25초

async def start_test():
    print(f"파일 로드 중: {FILE_PATH}")
    # 파일이 실제로 있는지 확인 필수!
    if not os.path.exists(FILE_PATH):
        print(f"파일이 없습니다: {FILE_PATH}")
        return

    audio = AudioSegment.from_file(FILE_PATH).set_frame_rate(16000).set_channels(1).set_sample_width(2)
    raw_data = audio.raw_data
    
    try:
        # HTTP가 아니라 ws:// 주소로 연결합니다.
        async with websockets.connect(WS_URL) as ws:
            print(f"WebSocket 연결 성공! 데이터를 전송합니다...")
            for i in range(0, len(raw_data), CHUNK_SIZE):
                await ws.send(raw_data[i:i+CHUNK_SIZE])
                await asyncio.sleep(0.25) # 실시간 속도 시뮬레이션
                if (i // CHUNK_SIZE) % 20 == 0:
                    print(f"전송률: {(i/len(raw_data))*100:.1f}%")
            print("테스트 종료")
    except Exception as e:
        print(f"에러 발생: {e}")

if __name__ == "__main__":
    asyncio.run(start_test())