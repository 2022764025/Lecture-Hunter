- version1

## 실증적AI 개발프로젝트Ⅰ

과제헌터 / 강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발

## A Flutter-based Real-time Captioning and Inquiry Widget for Enhanced Lecture Interaction ##

This project aims to develop an AI-driven educational platform that utilizes multimodal analysis of instructors' lectures (audio/visuals) and students' reactions (emotions/gaze) to minimize the physical gap and optimize learning outcomes in real time.

- version2

# 🎙️ LiveLectureAI
**실증적AI 개발프로젝트Ⅰ** > **과제헌터** | 강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발

---

## 📄 Project Overview

### "A Flutter-based Real-time Captioning and Inquiry Widget for Enhanced Lecture Interaction"

This project aims to develop an AI-driven educational platform that utilizes multimodal analysis of instructors' lectures (audio/visuals) and students' reactions (emotions/gaze) to minimize the physical gap and optimize learning outcomes in real time.

---

## 🛠 Tech Stack & Development Environment ##

### 💻  Environment

- OS: macOS (Apple Silicon M1/M2/M3)

- Language: Python 3.12+

- Framework: FastAPI (Asynchronous Backend)

- Virtual Env: venv (pikmin)

### 🧠  AI & Machine Learning (Core)

- STT (Speech-to-Text): **faster-whisper** `(1.2.1)`
  
- Computer Vision: **mediapipe** `(0.10.13)`

- Deep Learning Framework:

    - **tensorflow-macos** `(2.16.1)`
      
    - **jax** `(0.4.26)`
      
    - **keras** `(3.13.2)`

- LLM / RAG:

    - **ollama** `(0.6.1)`
    
    - **ctranslate2** `(4.7.1)`

- Mathematical Tools:

    - **numpy** `(1.26.4)`
    
    - **scipy** `(1.17.1)`
    
    - **sympy** `(1.14.0)`
      
### 🌐 Backend & Communication

- API Server:

    - **fastapi** `(0.135.1)` (비동기 API 서버)
    
    - **uvicorn** `(0.41.0)` (ASGI 서버)

- Database / Auth: **supabase** `(2.28.0)` (Postgrest, Auth, Functions 연동)

- Real-time Communication: **websockets** `(15.0.1)` (실시간 자막/질문 위젯 데이터 전송)

- Asynchronous Client:

    - **httpx** `(0.28.1)`
    
    - **anyio** `(4.12.1)`

### 🎙 Audio & Utilities

- Audio Processing:

    - **sounddevice** `(0.5.5)`
    
    - **av** `(16.1.0)`

- Data Validation: **pydantic v2** `(2.12.5)`

- Environment Config: **python-dotenv** `(1.2.2)`