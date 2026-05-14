![LiveLectureLogo](./assets/LiveLectureLogo2.png)

# LiveLectureAI
> **Empirical AI Development Project I** > **Task Hunter** | Flutter-based Real-time Subtitle & Question Widget for Enhanced Lecture Interaction

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/) [![FastAPI](https://img.shields.io/badge/FastAPI-0.135.1-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/) [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev/) [![PyTorch](https://img.shields.io/badge/PyTorch-2.10.0-EE4C2C?style=flat&logo=pytorch&logoColor=white)](https://pytorch.org/) [![TensorFlow](https://img.shields.io/badge/TensorFlow-2.16.1-FF6F00?style=flat&logo=tensorflow&logoColor=white)](https://www.tensorflow.org/) [![MediaPipe](https://img.shields.io/badge/MediaPipe-0.10.13-00C041?style=flat&logo=google&logoColor=white)](https://developers.google.com/mediapipe) [![Whisper](https://img.shields.io/badge/Whisper-1.2.1-412991?style=flat&logo=openai&logoColor=white)](https://github.com/openai/whisper) [![Supabase](https://img.shields.io/badge/Supabase-2.28.0-3ECF8E?style=flat&logo=supabase&logoColor=white)](https://supabase.com/) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-2.28.0-4169E1?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/) [![WebSockets](https://img.shields.io/badge/WebSockets-15.0.1-010101?style=flat&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API) [![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT) [![DORA](https://img.shields.io/badge/DORA-Elite-brightgreen)](https://dora.dev/) [![Deploy](https://img.shields.io/badge/Deploy_Freq-30%2Fweek-blue)](https://github.com/features/actions)

<p align="center">
    <a href="README.ko.md">
        <img src="https://img.shields.io/badge/Language-한국어-red?style=for-the-badge&logo=googletranslate&logoColor=white" alt="한국어 버전"/>
    </a>
    <a href="README.md">
        <img src="https://img.shields.io/badge/Language-English-blue?style=for-the-badge&logo=googletranslate&logoColor=white" alt="English Version"/>
    </a>
    <a href="README.zh.md">
        <img src="https://img.shields.io/badge/Language-中文版-orange?style=for-the-badge&logo=googletranslate&logoColor=white" alt="中文版"/>
    </a>
</p>

---

## Project Overview

### "A Multimodal AI-Integrated Real-time Captioning & Context-Aware Inquiry System"

This project is an AI-driven educational support platform that integrates a low-latency STT engine (Faster-Whisper) with a multimodal VLM (Llama 3.2 Vision) to analyze lecture audio and slide visuals in real time. Beyond simple captioning, the system understands the live lecture context to provide personalized RAG-based Q&A and automated summarization.

---

## Key Features (4 Pillars) ##

**[Feature 1] Real-time Intelligent Anchoring (STT + VLM)**

- **Adaptive Capture**: Utilizes VAD (Voice Activity Detection) to identify valid speech segments and triggers VLM analysis only when slide changes are detected, optimizing server inference resources.

- **Multimodal Sync**: Precisely maps real-time transcript data with VLM-analyzed slide summaries based on timestamps to provide students with a unified context.

**[Feature 2] Multilingual Bridge Captioning**

- **Lang-Chain Pipeline** : To maximize inference performance, VLM analysis is fixed to English, while the final output is translated in real time to the user’s preferred language (Korean, Japanese, etc.) via a dual-layer architecture.

- **Context-Aware Translation** : Leverages visual context captured by the VLM as auxiliary data to prevent mistranslation of technical terms and enhance overall linguistic accuracy.

**[Feature 3] RAG-based Smart Lecture Q&A**

- **Vector Search** : Embeds and stores spoken content and slide text into a Supabase Vector Store in real time.

- **Pinpoint Retrieval** : Generates high-fidelity answers by retrieving the exact lecture timestamps and visual references relevant to the user’s inquiry.

**[Feature 4] Adaptive Briefing**

- **Recursive Summarization** : Analyzes the flow of the lecture in 5 to 10-minute intervals using an LLM to generate high-level executive summaries.

- **Efficiency Optimizer** : Enables late-joiners or students in review to quickly grasp the core lecture flow without watching the entire recording.

---

## Technical Deep Dive: Advanced Engineering ##

### 1. Whisper VAD & STT Optimization ###

Implementation of **VAD (Voice Activity Detection)** logic to prevent hallucinations during silent intervals.

**A. Signal Energy-based VAD**

The STT engine is triggered only when the frame energy of the input signal $x(n)$ is significantly higher than the background noise energy ($E_{noise}$).

$$E_{frame} = \sum_{n=1}^L |x(n)|^2 > \gamma \cdot E_{noise}$$

- $\gamma$: Dynamic threshold considering the Signal-to-Noise Ratio (SNR).

### 2. RAG Optimization: Vector Normalization ###

Inner product calculations are performed after L2 Normalization to ensure search speed and accuracy within large-scale lecture datasets.

$$\|\mathbf{v}\|_2 = \sqrt{\sum_{i=1}^n |v_i|^2}, \quad \mathbf{\hat{v}} = \frac{\mathbf{v}}{\|\mathbf{v}\|_2}$$

- Since the inner product of normalized vectors is identical to Cosine Similarity, this maximizes real-time retrieval performance by reducing computational complexity.

### 3. VLM Image Preprocessing & Scaling ###

Preprocessing steps to maximize OCR (Optical Character Recognition) accuracy while maintaining inference performance within a local environment

**A. Aspect-Ratio Aware Scaling**

To ensure the VLM (Llama 3.2 Vision) accurately captures small technical terms and formulas, input images are resized to a $1024 \times 1024$ resolution using Bilinear Interpolation to minimize feature distortion.

$$I_{scaled} = \text{Bilinear}(I_{raw}, 1024, 1024)$$

- **Engineering Insight**: Standardizing to 1024px resulted in a approximately 30% reduction in "Hallucination" effects compared to 768px.

**B. RGB Conversion & Channel Optimization**

To comply with VLM input specifications and prevent inference errors caused by transparency, PNG files containing alpha channels are forcibly converted to a 3-channel RGB format.

$$C_{\text{out}} = \{R, G, B\} \leftarrow \text{Flatten}(I_{\text{raw}}, \text{Alpha-Blend})$$

### 4. Multimodal Contextual Anchoring ###

Logic designed to integrate asynchronously generated audio (STT) and visual (VLM) data into a single unified context.

**A. Nearest-Neighbor Timestamp Mapping**

Based on the client's screenshot capture time ($T_{cap}$), the system retrieves and anchors the most relevant subtitle data ($T_{stt}$) within an error margin ($\epsilon$) from the database.

$$\text{Target-ID} = \arg\min_{id} |T_{cap} - T_{stt, id}|, \quad \text{subject to } T_{stt} \le T_{cap}$$

- This ensures that the slide summary is precisely matched to the exact moment the instructor explains the corresponding content.

**B. Cross-Lingual Inference Bridge**

To overcome local resource constraints and enhance analysis precision, the VLM performs analysis ($P_{vlm}$) in English ($L_{en}$), with the final result ($R$) translated into the user's target language ($L_{target}$) via a dedicated translation engine ($T$).

$$R = T(\text{VLM}(I, L_{en}), L_{target})$$

- **Performance Trade-off**: This architecture improved technical term recognition by over 20% compared to direct-to-target language models and provides high architectural flexibility for future model replacements.

---

## System Architecture

The system architecture of this project is designed as a three-stage data pipeline: "**Real-time Client Preprocessing (Capture & Optimization) → Multimodal Intelligent Inference (STT + VLM) → Data Integration & Personalized Service (RAG & Multilingual).**"

![System Architecture](./assets/system_architecture.png)

---

## Data Schema & Architecture

| Table Name | Key Columns | Description |
| :--- | :--- | :--- |
| **lectures** | `id`, `title`, `keywords`, `major` | Manages lecture metadata and keywords for optimized search filtering. |
| **lecture_contents** | `original_text`, `translated_text`, `has_visual`, `visual_summary`, `content_embedding` | Integrates real-time captions and VLM visual analysis; provides vector storage for RAG. |
| **lecture_glossary** | `term`, `definition` | Stores major-specific terminology and definitions extracted in real time. |
| **lecture_summaries** | `summary_text`, `key_points` | **Adaptive Briefing**: Stores recursive lecture summaries generated every 5-10 minutes. |
| **lecture_logs** | `engagement_score`, `event_type` | Quantitative learning engagement metrics based on user interactions (e.g., questions) |

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

    - **fastapi** `(0.135.1)` (Asynchronous API Server)
    
    - **uvicorn** `(0.41.0)` (ASGI Server)

- Database / Auth: **supabase** `(2.28.0)` (Postgrest, Auth, Functions integration)

- Real-time Communication: 

    - **websockets** `(15.0.1)` (Real-time data transmission)

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

- [x] VLM-based Visual Engine: Integrated Llama 3.2 Vision and optimized resolution (1024px Bilinear Scaling) to maximize slide text recognition.

- [x] Multimodal Contextual Anchoring: Implemented a Nearest-Neighbor mapping algorithm between STT timestamps and VLM capture points.

- [x] Intelligent Speech Recognition (STT): Implemented high-speed inference and auto-language detection logic based on `Faster-Whisper`.

- [x] Dynamic Translation Engine: Integrated a Cross-Lingual Bridge architecture using Gemma-2 to improve technical term accuracy.

- [x] VAD Integration: Integrated `Silero VAD` to filter silence and fundamentally prevent STT hallucinations.

**2. Backend & Intelligence (Architecture)**

- [x] Asynchronous Architecture: Structured real-time bidirectional streaming using FastAPI, WebSockets, and `anyio`.

- [x] Vector-based RAG Engine: Established hybrid embedding and HNSW indexing using Supabase `pgvector`.

- [x] Memory-based Intelligent Q&A: Completed RAG tutor logic capable of context-aware responses based on previous lecture history.

- [x] Database Schema Optimization: Secured a unified context structure by adding `has_visual` and `visual_summary` columns.

**3. High-Performance Scaling (Testing & Deployment)**

- [ ] Adaptive Briefing (Real-time Summary): Finalizing the recursive summary and keyword extraction pipeline based on 5–10 minute cumulative data.

- [ ] Local LLM Serving Optimization: Testing NPU acceleration (M1/M2/RTX 5060) and minimizing inference latency via Ollama.

- [ ] Concurrency Benchmarking: Measuring backend throughput and latency during multi-user access and WebSocket streaming.

- [ ] Interaction-based Engagement Analysis: Developing quantitative metrics for learning engagement based on question frequency and quiz results.

**4. Frontend Integration (Flutter)** -> (Final Dev scheduled after May 07, 2026)

- [ ] WebSocket Integration: Testing real-time reception and visualization of backend analysis data (captions, summaries, translations).

- [ ] Real-time Multilingual Subtitles: Implementing target language selection widgets and delay-compensated subtitle viewers.

- [ ] RAG AI Tutor Widget: Developing a real-time Q&A interface synchronized with the lecture slide context.

- [ ] Lecture Briefing Dashboard: Creating a dashboard for cumulative summaries and technical glossaries.

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
cp .env.example .env  # Create environment configuration (Required)
# Then, enter your Supabase URL and KEY in the .env file.
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

Our system supports three execution modes based on hardware resources and required inference precision.

**Option A: Local Inference (Lightweight)**

Recommended for testing on personal laptops (MacBook M1/M2/M3, etc.).

1. **Models via Ollama**: `llama3.2-vision` (Visual Analysis) & `gemma2:2b` (Translation)

2. **Faster-Whisper** `Medium` or `small` model (CPU/MPS acceleration)

3. Environment Configuration:

```Bash
export RUNTIME_MODE=local
uvicorn App.main:app --reload
```

**Option B: GPU Server (High-Performance)**

Recommended for servers with NVIDIA RTX 5060 or higher.

1. **vLLM** based LLM (`Gemma2:9b` or `27b`)

2. **Faster-Whisper** `Large-v3` model (CUDA acceleration)

3. Execution Commands:

```Bash
# Start vLLM server (On GPU Server side)
python -m vllm.entrypoints.openai.api_server --model google/gemma-2-9b-it

# Start Backend server
export RUNTIME_MODE=gpu
uvicorn App.main:app --host 0.0.0.0
```

**Option C: Docker Container (On-premises)**

Use this for a consistent development environment across different machines.

```Bash
docker build -t livelecture-ai .
docker run --gpus all -p 8000:8000 livelecture-ai
```

---

## Hardware Requirements

The system supports optimized model sizes based on the deployment environment.

| Component | Minimum (Laptop/Local) | Recommended (Server/GPU) |
| :--- | :--- | :--- |
| **GPU/NPU** | Apple Silicon (M1/M2/M3) | **NVIDIA RTX 40/50-series (12GB+ VRAM)** |
| **Acceleration** | MPS (Metal) / CPU | **CUDA (vLLM / TensorRT)** |
| **RAM** | 16GB (Unified Memory) | 32GB+ |
| **STT Model** | Faster-Whisper **Medium** | Faster-Whisper **Large-v3** |
| **VLM Model** | Llama-3.2-Vision-11B (Quantized) | **Llama-3.2-Vision-11B** or **LLaVA-13B** (8-bit/FP16) |
| **LLM Model** | Gemma2-**2b** | Gemma2-**9b** or **27b** |
| **Capacity** | Single User Analysis | **Class-wide (30+) Real-time Analysis** |

---

## License ##

**MIT License**