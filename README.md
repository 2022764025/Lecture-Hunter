![LiveLectureLogo](./assets/LiveLectureLogo2.png)


# LiveLectureAI
> **실증적AI 개발프로젝트Ⅰ** > **과제헌터** | 강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/) [![FastAPI](https://img.shields.io/badge/FastAPI-0.135.1-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/) [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/) [![PyTorch](https://img.shields.io/badge/PyTorch-2.10.0-EE4C2C?style=flat&logo=pytorch&logoColor=white)](https://pytorch.org/) [![TensorFlow](https://img.shields.io/badge/TensorFlow-2.16.1-FF6F00?style=flat&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/) [![MediaPipe](https://img.shields.io/badge/MediaPipe-0.10.13-00C041?style=flat&logo=google&logoColor=white)](https://developers.google.com/mediapipe) [![Whisper](https://img.shields.io/badge/Whisper-1.2.1-412991?style=flat&logo=openai&logoColor=white)](https://github.com/openai/whisper) [![Supabase](https://img.shields.io/badge/Supabase-2.28.0-3ECF8E?style=flat&logo=supabase&logoColor=white)](https://supabase.com/) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-2.28.0-4169E1?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/) [![WebSockets](https://img.shields.io/badge/WebSockets-15.0.1-010101?style=flat&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API) [![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT) [![DORA](https://img.shields.io/badge/DORA-Elite-brightgreen)](https://dora.dev/) [![Deploy](https://img.shields.io/badge/Deploy_Freq-30%2Fweek-blue)](https://github.com/features/actions)

<p align="center">
    <a href="README.md">
        <img src="https://img.shields.io/badge/Language-한국어-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="한국어 버전"/>
    </a>
    <a href="README.en.md">
        <img src="https://img.shields.io/badge/Language-English-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version"/>
    </a>
    <a href="README.zh.md">
        <img src="https://img.shields.io/badge/Language-中文版-orange?style=for-the-badge&logo=googletranslate&logoColor=white" alt="中文版"/>
    </a>
</p>

---

## Project Overview

### "A Multimodal AI-Integrated Real-time Captioning & Context-Aware Inquiry System"

본 프로젝트는 저지연(Low-Latency) STT 엔진(Faster-Whisper)과 멀티모달 VLM(Llama 3.2 Vision)을 결합하여, 강의 음성과 슬라이드 시각 자료를 실시간으로 통합 분석하는 교육 보조 플랫폼입니다. 단순히 자막을 보여주는 것을 넘어, 실시간 강의 문맥을 이해하고 이를 기반으로 사용자 맞춤형 질의응답(RAG) 및 자동 요약을 제공합니다.

---

## Key Features (4 Pillars) ##

**[Feature 1] 실시간 지능형 앵커링 (STT + VLM)**

- **Adaptive Capture (적응형 화면 캡처)**: VAD(Voice Activity Detection)를 통해 유효한 음성 구간을 감지하고, 슬라이드 변화 시점에 맞춰 VLM이 시각 자료(수식, 도표)를 분석.

- **Multimodal Sync (멀티모달 데이터 동기화)**: 실시간 자막 데이터와 슬라이드 요약본을 타임스탬프 기준으로 정밀하게 맵핑하여 학습자에게 통합 문맥을 제공.

**[Feature 2] 다국어 브릿지 자막 서비스**

- **Lang-Chain Pipeline (언어 체인 파이프라인)** : 추론 성능 극대화를 위해 VLM의 분석은 영어로 고정하되, 최종 결과물은 사용자 설정 언어(한국어, 일본어, 영어 등)로 실시간 번역하여 제공하는 이원화 아키텍처를 채택.

- **Context-Aware Translation (문맥 인지형 번역)** : 단순 텍스트 번역을 넘어 VLM이 파악한 시각적 정보를 보조 지표로 활용하여, 전공 용어의 오역을 방지하고 번역의 질을 높임.

**[Feature 3] RAG 기반의 스마트 강의 Q&A**

- **Vector Search (벡터 검색)** : 강의 중 언급된 내용과 슬라이드 텍스트를 Supabase Vector Store에 실시간 임베딩하여 저장.

- **Pinpoint Retrieval (정밀 정보 검색)** : 사용자가 질문하면 강의의 특정 시점(타임라인)과 시각 자료를 근거로 정확한 답변을 생성.

**[Feature 4] 구간별 자동 브리핑 (Adaptive Briefing)**

- **Recursive Summarization (재귀적 요약 고도화)** : 5~10분 단위의 강의 흐름을 LLM이 분석하여 핵심 요약을 생성.

- **Efficiency Optimizer (학습 효율 최적화)** : 늦게 접속한 학생이나 복습 중인 사용자가 전체 영상을 다 보지 않고도 수업의 맥락을 빠르게 파악할 수 있도록 도움.

---

## Technical Deep Dive: Advanced Engineering ##

### 1. Whisper VAD & STT Optimization ###

무음 구간에서의 환각 현상(Hallucination)을 방지하기 위한 **VAD (Voice Activity Detection)** 로직입니다.

**A. Signal Energy-based VAD**

입력 신호 $x(n)$의 프레임 에너지가 배경 소음 에너지($E_{noise}$)보다 충분히 클 때만 STT 엔진을 구동합니다.

$$E_{frame} = \sum_{n=1}^L |x(n)|^2 > \gamma \cdot E_{noise}$$

- $\gamma$: 신호 대 잡음비(SNR)를 고려한 동적 임계치

### 2. RAG Optimization: Vector Normalization ###

대규모 강의 데이터셋에서 검색 속도와 정확도를 보장하기 위해 L2 Normalization을 거친 내적 연산을 수행합니다.

$$\|\mathbf{v}\|_2 = \sqrt{\sum_{i=1}^n |v_i|^2}, \quad \mathbf{\hat{v}} = \frac{\mathbf{v}}{\|\mathbf{v}\|_2}$$

- 정규화된 벡터 간의 내적은 코사인 유사도와 동일하므로, 연산 복잡도를 줄이면서 실시간 검색 성능을 극대화합니다.

### 3. VLM Image Preprocessing & Scaling ###

로컬 환경에서의 추론 성능을 유지하면서 OCR(문자 인식) 정확도를 극대화하기 위한 전처리 과정입니다.

**A. Aspect-Ratio Aware Scaling**

VLM(Llama 3.2 Vision)이 작은 전공 용어와 수식을 정확히 캐치할 수 있도록 입력 영상을 $1024 \times 1024$ 해상도로 리사이징합니다. 이때 Bilinear Interpolation을 적용하여 특징점의 왜곡을 최소화합니다.

$$I_{scaled} = \text{Bilinear}(I_{raw}, 1024, 1024)$$

- **Engineering Insight**: 768px 대비 1024px에서 환각(Hallucination) 현상이 약 30% 감소함을 확인하여 해당 해상도를 표준으로 채택하였습니다.

**B. RGB Conversion & Channel Optimization**

VLM 엔진의 입력 규격을 맞추고 투명도 채널에 의한 추론 오류를 방지하기 위해 PNG 등 투명도가 포함된 이미지를 RGB 3채널로 강제 변환합니다.

$$C_{\text{out}} = \{R, G, B\} \leftarrow \text{Flatten}(I_{\text{raw}}, \text{Alpha-Blend})$$

### 4. Multimodal Contextual Anchoring ###

서로 다른 주기로 생성되는 음성 데이터(STT)와 시각 데이터(VLM)를 하나의 문맥으로 통합하기 위한 로직입니다.

**A. Nearest-Neighbor Timestamp Mapping**

클라이언트가 스크린샷을 캡처한 시점($T_{cap}$)을 기준으로, DB 내의 자막 시점($T_{stt}$) 중 오차 범위($\epsilon$) 내에 있으면서 가장 인접한 과거 데이터를 탐색하여 앵커링합니다.

$$\text{Target-ID} = \arg\min_{id} |T_{cap} - T_{stt, id}|, \quad \text{subject to } T_{stt} \le T_{cap}$$

- 이를 통해 강의자가 특정 슬라이드를 설명하는 정확한 시점에 해당 슬라이드 요약본이 매칭되도록 보장합니다.

**B. Cross-Lingual Inference Bridge**

로컬 리소스의 제약 하에서 분석 정확도를 높이기 위해 VLM 분석($P_{vlm}$)은 영어($L_{en}$)로 수행하고, 최종 결과물($R$)은 사용자 설정 언어($L_{target}$)로 번역 엔진($T$)을 통해 변환합니다.

$$R = T(\text{VLM}(I, L_{en}), L_{target})$$

- **Performance Trade-off**: 직역 모델 대비 전공 용어 인식률을 20% 이상 개선하였으며, 추론 로직과 번역 로직을 분리하여 향후 모델 교체가 용이한 유연한 구조를 확보했습니다.

---

## System Architecture

본 프로젝트의 시스템 아키텍처는 "**클라이언트 실시간 전처리(캡처 및 최적화) → 멀티모달 지능형 추론(STT + VLM) → 데이터 통합 및 맞춤형 서비스(RAG & 다국어)**"의 3단계 파이프라인으로 설계되었습니다.

![System Architecture](./assets/system_architecture.png)

---

## Data Schema & Architecture

| Table Name | Key Columns | Description |
| :--- | :--- | :--- |
| **lectures** | `id`, `title`, `keywords`, `major` | 강의 메타데이터 및 검색 필터링용 키워드 관리 |
| **lecture_contents** | `original_text`, `translated_text`, `has_visual`, `visual_summary`, `content_embedding` | 실시간 자막과 시각 분석 데이터 통합 및 RAG용 벡터 저장 |
| **lecture_glossary** | `term`, `definition` | 실시간 추출된 전공 전문 용어 및 정의 데이터 |
| **lecture_summaries** | `summary_text`, `key_points` | **Adaptive Briefing**: 5~10분 단위 재귀적 강의 요약 |
| **lecture_logs** | `engagement_score`, `event_type` | 인터랙션(질문 등) 기반 학습 참여도 정량 지표 |

---

## Tech Stack & Environment ##

### Development Environment

- OS: macOS (Apple Silicon M1/M2/M3)

- Language: Python `3.12+` (**Python 3.13+ is not supported**)

- Framework: FastAPI (Asynchronous Backend)

- Virtual Env: venv ('pikmin')

### AI & Machine Learning (Core)

- STT (Speech-to-Text): **faster-whisper** `(1.2.1)`

- VAD (Voice Activity Detection): **silero-vad** `(6.2.1)`

- Multimodal VLM & LLM:

    - **ollama** `(0.6.1)` 
    
    - **langchain-ollama** `(1.1.0)` / **langchain-core** `(1.2.28)`

- Base Framework:

    - **torch** `(2.10.0)` / **torchaudio** `(2.11.0)`

### Backend & Communication

- API Server:

    - **fastapi** `(0.135.1)` (비동기 API 서버)
    
    - **uvicorn** `(0.41.0)` (ASGI 서버)

- Database / Auth: **supabase** `(2.28.0)` (Postgrest, Auth, Functions 연동)

- Real-time Communication: 

    - **websockets** `(15.0.1)` (실시간 자막/질문 위젯 데이터 전송)

    - **sse-starlette**

- Asynchronous Client:

    - **httpx** `(0.28.1)`
    
    - **anyio** `(4.12.1)`

### Data Processing & Utilities

- Image Preprocessing

    - **pillow** `(12.1.1)`

    - **numpy** `(1.26.4)`

- Audio Processing:

    - **sounddevice** `(0.5.5)`
    
    - **av** `(16.1.0)`

- Data Validation: **pydantic v2** `(2.12.5)`

- Environment Config: **python-dotenv** `(1.2.2)`

---

## Project Milestone & Checklist (Updated 2026.05.07) ##

**1. Multi-modal AI Engine (Core)**

- [x] VLM 기반 시각 분석 엔진: Llama 3.2 Vision 적용 및 해상도 최적화(1024px Bilinear Scaling)를 통한 슬라이드 텍스트 인식률 극대화

- [x] 멀티모달 문맥 앵커링 (Anchoring): STT 자막 타임스탬프와 VLM 캡처 시점 간의 최근접 매핑(Nearest-Neighbor) 알고리즘 구현

- [x] 지능형 음성 인식(STT): `Faster-Whisper` 기반 고속 추론 및 다국어 자동 판독(Auto-Detection) 로직 구현

- [x] 동적 다국어 번역 엔진: Gemma-2 기반 이원화 추론 아키텍처(Cross-Lingual Bridge) 연동으로 전공 용어 번역 정확도 개선

- [x] VAD 음성 감지 통합: `Silero VAD` 필터 적용을 통해 무음 구간을 사전 차단하여 STT의 환각 현상(Hallucination) 원천 방지

**2. Backend & Intelligence (Architecture)**

- [x] 비동기 백엔드 아키텍처: FastAPI와 WebSockets, `anyio`를 활용한 실시간 양방향 스트리밍 구조화 완료

- [x] 벡터 기반 RAG 엔진: Supabase `pgvector`를 활용한 강의 내용(자막+시각 요약) 하이브리드 임베딩 및 HNSW 인덱싱 구축

- [x] 메모리 기반 지능형 Q&A: 검색 증강 생성(RAG)을 통해 이전 강의 문맥을 기억하고 사용자 맞춤형으로 답변하는 튜터 로직 완성

- [x] 데이터베이스 스키마 최적화: `has_visual`, `visual_summary` 컬럼 등 멀티모달 데이터를 단일 문맥으로 통합 저장하는 구조 확보

**3. High-Performance Scaling (Testing & Deployment)**

- [ ] Adaptive Briefing (실시간 요약): 5~10분 단위 누적 데이터를 기반으로 재귀적(Recursive) 강의 요약 및 핵심 키워드 추출 파이프라인 완성

- [ ] 로컬 LLM 최적화 서빙: Ollama 기반의 VLM/LLM 추론 지연시간(Latency) 최소화 및 M1/M2/RTX 5060 NPU 가속 테스트

- [ ] 동시 접속자 대응 벤치마크: 다중 사용자 접속 및 WebSocket 스트리밍 시 백엔드 처리 성능(Throughput) 측정

- [ ] 인터랙션 기반 참여도 분석: 시선 추적을 대체하여, 학생의 질문 빈도 및 퀴즈 정답률(Interaction Log) 기반 정량적 학습 참여도 지표 산출

**4. Frontend Integration (Flutter)** -> (05월 07일 이후 최종 개발 예정.)

- [ ] WebSocket 실시간 통신 연동: 백엔드 분석 데이터(자막, 요약, 번역)를 Flutter 클라이언트로 실시간 수신 및 가시화 테스트

- [ ] 실시간 다국어 자막 UI: 목표 언어 선택 위젯 및 딜레이 보정이 적용된 스트리밍 자막 뷰어 구현

- [ ] RAG AI 튜터 위젯: 강의 슬라이드 컨텍스트와 동기화되는 실시간 Q&A 채팅 인터페이스 개발

- [ ] 강의 브리핑 대시보드: 누적 생성된 강의 요약(Briefing) 및 전문 용어(Glossary)를 한눈에 볼 수 있는 학습 대시보드 개발

---

## Getting Started ##

**Installation**
```Bash
# 1. Repository Clone
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# 2. Virtual Environment Setup (Python 3.12 recommended)
python3 -m venv pikmin
source pikmin/bin/activate

# 3. Dependency Installation
pip install --upgrade pip
pip install -r requirements.txt

# 4. Environment Variables Setup
cp .env.example .env  # .env 설정 파일 생성 (필수)
# 그 후 .env 파일에 Supabase URL과 KEY를 입력하세요.
```

**Usage**
```Bash
# 1. Ollama Server Start (Local LLM/VLM 서빙)
ollama serve

# FastAPI server start
uvicorn App.main:app --reload

# Vision Engine test(Local)
python3 services/test_multimodal.py
```

---

## Deployment & Runtime Options ##

본 시스템은 하드웨어 리소스와 분석 정밀도에 따라 세 가지 구동 모드를 지원합니다.

**Option A: Local Inference (Lightweight)**

개인용 노트북(MacBook M1/M2/M3 등)에서 테스트할 때 권장합니다.

1. **Ollama 기반 모델**: `llama3.2-vision` (시각 분석) & `gemma2:2b` (번역)

2. **Faster-Whisper** `Medium` 또는 `small` 모델 (CPU/MPS 가속)

3. 환경 변수 설정:

```Bash
export RUNTIME_MODE=local
uvicorn App.main:app --reload
```

**Option B: GPU Server (High-Performance)**

RTX 5060 이상의 GPU 서버에서 권장합니다.

1. **vLLM** 기반 LLM 구동 (`Gemma2:9b` or `27b`)

2. **Faster-Whisper** `Large-v3` 모델 (CUDA 가속)

3. 실행 명령어:

```Bash
# Start vLLM server (On GPU Server side)
python -m vllm.entrypoints.openai.api_server --model google/gemma-2-9b-it

# Start Backend server
export RUNTIME_MODE=gpu
uvicorn App.main:app --host 0.0.0.0
```

**Option C: Docker Container (On-premises)**

일관된 개발 환경이 필요할 때 사용합니다.

```Bash
docker build -t livelecture-ai .
docker run --gpus all -p 8000:8000 livelecture-ai
```

---

## Hardware Requirements

본 시스템은 구동 환경에 따라 최적화된 모델 아키텍처를 지원하며, 멀티모달 추론을 위해 아래의 사양을 권장합니다.

| Component | Minimum (Laptop/Local) | Recommended (Server/GPU) |
| :--- | :--- | :--- |
| **GPU/NPU** | Apple Silicon (M1/M2/M3) | **NVIDIA RTX 40/50-series (12GB+ VRAM)** |
| **Acceleration** | MPS (Metal) / CPU | **CUDA (vLLM / TensorRT)** |
| **RAM** | 16GB (Unified Memory) | 32GB+ |
| **STT Model** | Faster-Whisper **Medium** | Faster-Whisper **Large-v3** |
| **VLM Model** | Llama-3.2-Vision-11B (Quantized) | **Llama-3.2-Vision-11B** or **LLaVA-13B** (8-bit/FP16) |
| **LLM Model** | Gemma2-**2b** | Gemma2-**9b** or **27b** |
| **Capacity** | 1인 분석 및 자막 | **강의실 전체(30인+) 실시간 분석** |

---

## License ##

**MIT License**
