# 🎙️ LiveLectureAI
**실증적AI 개발프로젝트Ⅰ** > **과제헌터** | 강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발

---

## 📄 Project Overview

### "A Flutter-based Real-time Captioning and Inquiry Widget for Enhanced Lecture Interaction"

This project aims to develop an AI-driven educational platform that utilizes multimodal analysis of instructors' lectures (audio/visuals) and students' reactions (emotions/gaze) to minimize the physical gap and optimize learning outcomes in real time.

본 프로젝트는 강의자의 멀티모달 데이터(음성/시각)와 학생의 실시간 반응(감정/시선)을 분석하여, 비대면/대면 강의의 물리적 간극을 줄이고 학습 성과를 최적화하는 AI 기반 교육 플랫폼입니다.

---

## 🚀 Key Features (4 Pillars) ##

### 📊 [실시간] 익명 집계 대시보드 ###

- **익명성 보장**: 개별 학생의 데이터를 삭제하고 학급 전체의 평균 집중도만 추출.

- **교수자 피드백**: "현재 70%가 어려워함" 메시지를 통해 수업 속도 즉각 조절.

### 🗺️ [수업 후] 강의 자료 시선 히트맵 ###

- **Gaze Tracking** : 학생들의 시선이 슬라이드 좌표($x, y$) 중 어디에 머물렀는지 시각화.

- **콘텐츠 최적화** : 학습자가 방황한 지점을 파악하여 강의 자료 보완 근거 제공.

### ⏱️ [복습용] 스마트 복습 타임라인 ###

- **EAR & 시선 이탈** : 졸았거나 고개를 돌린 시간대를 영상 타임라인에 자동 마킹.

- **핀포인트 복습** : 3시간 강의를 다 볼 필요 없이 놓친 구간만 효율적 복습 가능.

### 📈 [비즈니스] 콘텐츠 이탈 분석 (QC) ###

- **종합 집중도 지표** : 강사의 어느 시점에서 학생들의 시선이 대거 이탈하는지 분석.

- **품질 관리** : 스타 강사 선별 및 콘텐츠 재촬영 구간 결정을 위한 고부가가치 데이터 제공.

---

## 🛠 Tech Stack & Environment ##

### 💻 Development Environment

- OS: macOS (Apple Silicon M1/M2/M3)

- Language: Python '3.12+'

- Framework: FastAPI (Asynchronous Backend)

- Virtual Env: venv ('pikmin')

### 🧠 AI & Machine Learning (Core)

- 🎙 STT (Speech-to-Text): **faster-whisper** `(1.2.1)`
  
- 👁 Computer Vision: 

    - **mediapipe** `(0.10.13)`
    
    - **hsemotion-onnx** `(0.3.1)`

- 🏗 Deep Learning Framework:

    - **tensorflow-macos** `(2.16.1)` / **keras** `(3.13.2)`
    
    - **torch** `(2.10.0)` / **torchvision** `(0.25.0)`

    - **jax** `(0.4.26)`

- 🤖 LLM / RAG:

    - **ollama** `(0.6.1)`
    
    - **ctranslate2** `(4.7.1)`

- 🧮 Mathematical Tools:

    - **numpy** `(1.26.4)`
    
    - **scipy** `(1.17.1)`
    
    - **sympy** `(1.14.0)`
      
### 🌐 Backend & Communication

- ⚡ API Server:

    - **fastapi** `(0.135.1)` (비동기 API 서버)
    
    - **uvicorn** `(0.41.0)` (ASGI 서버)

- ☁️ Database / Auth: **supabase** `(2.28.0)` (Postgrest, Auth, Functions 연동)

- 🔌 Real-time Communication: 

    - **websockets** `(15.0.1)` (실시간 자막/질문 위젯 데이터 전송)

    - **sse-starlette**

- 🛰 Asynchronous Client:

    - **httpx** `(0.28.1)`
    
    - **anyio** `(4.12.1)`

### 🎙 Audio & Utilities

- 🎧 Audio Processing:

    - **sounddevice** `(0.5.5)`
    
    - **av** `(16.1.0)`

- 🛡 Data Validation: **pydantic v2** `(2.12.5)`

- 📝 Environment Config: **python-dotenv** `(1.2.2)`

---

## ✅ Checklist (Current Progress) ##

- [x] 비전 분석 엔진 고도화: `HSEmotion` + `DIP(Sobel, DoG)` 하이브리드 로직 구축

- [x] 시선 추적 안정화: EMA 필터 및 비선형 가속을 통한 Gaze Tracking 정확도 개선

- [x] 백엔드 아키텍처 설계: FastAPI 기반 SSE 스트리밍 및 RAG 서비스 구조화

- [ ] SSE 실시간 통신 연동: 분석 데이터를 Flutter 클라이언트로 실시간 전송 테스트

- [ ] 익명 데이터 집계: 서버 사이드 평균 집중도 계산 로직 완성

- [ ] 프론트엔드 UI 개발: Flutter 기반 실시간 자막 및 집중도 대시보드 위젯 구현

---

## ⚙️ Getting Started ##

**Installation**
```Bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd LiveLectureAI
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt
```

**Usage**
```Bash
# FastAPI servet start
uvicorn App.main:app --reload

# Vision Engine test(Local)
python3 services/test_vision.py
```

---

## 📄 License ##

**MIT License**