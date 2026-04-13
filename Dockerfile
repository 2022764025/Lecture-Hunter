# 1. 베이스 이미지 설정 (Python 3.12 리눅스 환경)
FROM python:3.12-slim

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 필수 도구 설치 (OpenCV 등 비전 라이브러리용)
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 4. 의존성 파일 복사 및 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. 소스 코드 복사
COPY . .

# 6. FastAPI 실행 (포트 8000)
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]