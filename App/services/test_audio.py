import requests
from pydub import AudioSegment
import io
import os

# 1. 파일 경로 설정 (바탕화면에 있다면 경로를 맞춰주세요)
# 맥북 바탕화면 경로는 보통 /Users/사용자명/Desktop/test_lecture.m4a 입니다.
file_path = os.path.expanduser("/Users/iminjae/Desktop/test_lecture.m4a") 
url = "http://localhost:8000/lecture/audio/lect01"

try:
    print("오디오 변환 중 (m4a -> Raw PCM)...")
    # 2. m4a 파일을 로드하여 서버 규격(16kHz, Mono, 16bit)으로 변환
    audio = AudioSegment.from_file(file_path, format="m4a")
    audio = audio.set_frame_rate(16000).set_channels(1).set_sample_width(2)
    
    # 3. 순수 데이터(Raw Bytes) 추출
    raw_data = audio.raw_data
    
    print(f"서버로 전송 시작... (데이터 크기: {len(raw_data)} bytes)")
    
    # 4. 서버로 POST 요청 (파일 이름은 상관없음)
    files = {'file': ('test.raw', raw_data, 'application/octet-stream')}
    response = requests.post(url, files=files)
    
    # 5. 결과 출력
    print("-" * 30)
    print("서버 응답:")
    print(response.json())
    print("-" * 30)

except Exception as e:
    print(f"에러 발생: {e}")