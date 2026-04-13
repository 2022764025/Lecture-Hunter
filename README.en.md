# 🎙️ LiveLectureAI
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

## 📄 Project Overview

### "A Flutter-based Real-time Captioning and Inquiry Widget for Enhanced Lecture Interaction"

This project aims to develop an AI-driven educational platform that utilizes multimodal analysis of instructors' lectures (audio/visuals) and students' reactions (emotions/gaze) to minimize the physical gap and optimize learning outcomes in real time.

---

## 🚀 Key Features (4 Pillars) ##

**📊 [Real-time] Anonymous Aggregation Dashboard**

- **Anonymity Guaranteed**: Deletes individual student data and extracts only the overall class average engagement.

- **Instructor Feedback**: Provides instant speed adjustment cues like "70% of students find this difficult."

**🗺️ [Post-lecture] Lecture Material Gaze Heatmap**

- **Gaze Tracking** : Visualizes where students' attention lingered on the slide coordinates ($x, y$).

- **Content Optimization** : Identifies points where learners struggled to provide a basis for improving lecture materials.

**⏱️ [For Review] Smart Review Timeline**

- **EAR & Distraction Detection** : Automatically marks segments where students were drowsy or looked away on the video timeline.

- **Pinpoint Review** : Enables efficient review of only missed segments without watching the entire 3-hour lecture.

**📈 [B2B] Instructor Performance Metrics & Quality Control (QC)**

- **Instructor Score** : Quantifies instructional power into a score using a proprietary algorithm that combines the mean and **volatility (standard deviation)** of engagement.

- **Data Consulting** : Provides objective decision-making criteria for instructor contract renewals and content re-filming by analyzing drop-off points.

- **Quality Optimization** : Derives high-value business insights to discover star instructors and standardize the quality of educational content.

---

## 🧠 Technical Deep Dive: Advanced Engineering ##

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

### 3. DIP (Digital Image Processing) Preprocessing ###

To enhance the accuracy of the vision engine, a DoG (Difference of Gaussians) filter is applied to the input image to remove noise and highlight feature points.

**A. Difference of Gaussians (DoG)**

Emphasizes edges by utilizing the difference between two Gaussian kernels with different standard deviations ($\sigma_1, \sigma_2$).

$$DoG(x, y) = \frac{1}{2\pi\sigma_1^2} e^{-\frac{x^2+y^2}{2\sigma_1^2}} - \frac{1}{2\pi\sigma_2^2} e^{-\frac{x^2+y^2}{2\sigma_2^2}}$$

-> This process enables robust landmark extraction against lighting variations.

**B. Sobel Edge Detection**

Detects the boundaries of the pupil area to increase the precision of gaze tracking.

$$G = \sqrt{G_x^2 + G_y^2}, \quad \theta = \arctan\left(\frac{G_y}{G_x}\right)$$

### 4. Multi-modal Engagement Fusion Model ###

A fused engagement index combining vision ($V$) and emotion ($A$) data is used to overcome the limitations of single-metric analysis.

**A. Composite Engagement Score ($CE$)**

$$CE = w_e \cdot EAR_{norm} + w_g \cdot Gaze_{dist} + w_{emo} \cdot \sum (Emo_i \cdot s_i)$$

- $w_e, w_g, w_{emo}$: Weights based on the importance of each metric ($\sum w = 1$).

- $s_i$: Correlation coefficients for each emotion (e.g., Neutral=1.0, Surprise=0.8, Sad=-0.5).

**B. Head Pose Variance ($HP_v$)**

Detects non-attentive intervals through head movements (Yaw, Pitch, Roll).

$$HP_v = \sqrt{\frac{1}{N}\sum_{i=1}^N (\theta_i - \bar{\theta})^2}$$

- If the standard deviation exceeds the threshold, the state is classified as 'Distracted' and reflected in the dashboard.

---

## 🏗️ System Architecture

The system operates on a 3-stage pipeline: "**Real-time Edge Analysis -> Cloud Intelligent Processing -> Multilingual Broadcast**".

```mermaid
graph TD
    subgraph "Client Side (Flutter)"
        A["Mic/Camera Stream"] --> B["DIP Processor"]
        B --> C["SSE/WebSocket Client"]
    end

    subgraph "Backend Engine (FastAPI)"
        C --> D{"Engine Selector"}
        D --> E["Vision Engine: HSEmotion + Gaze"]
        D --> F["Audio Engine: Whisper + Gemma2"]
        E --> G["Engagement Scorer"]
        F --> H["Multi-lang Translator"]
    end

    subgraph "Intelligent Data (Supabase)"
        G --> I[("(Realtime DB)")]
        H --> J[("(Vector DB: pgvector)")]
        J --> K["RAG AI Tutor"]
    end

    I --> L["Real-time Dashboard"]
    K --> L
```

---

## 📂 Data Schema & Architecture

| Table Name | Key Columns | Description |
| :--- | :--- | :--- |
| **lecture_contents** | `original`, `translated`, `target_lang`, `embedding` | Real-time transcription/translation and vector embeddings for RAG. |
| **lecture_logs** | `engagement_score`, `emotion`, `gaze_x/y`, `ear` | Source data for gaze tracking, emotion analysis, and drowsiness detection. |
| **lecture_summaries** | `summary_text`, `key_points` | AI-generated lecture summaries and key point data. |

---

## 🛠 Tech Stack & Environment ##

### 💻 Development Environment

- OS: macOS (Apple Silicon M1/M2/M3)

- Language: Python `3.12+` (**Python 3.13+ is not supported**)

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

    - **fastapi** `(0.135.1)` (Asynchronous API Server)
    
    - **uvicorn** `(0.41.0)` (ASGI Server)

- ☁️ Database / Auth: **supabase** `(2.28.0)` (Postgrest, Auth, Functions integration)

- 🔌 Real-time Communication: 

    - **websockets** `(15.0.1)` (Real-time data transmission)

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

## ✅ Project Milestone & Checklist (Updated 2026.04.09) ##

**1️⃣ Multi-modal AI Engine (Core)**

- [x] Advanced Vision Analysis: Built hybrid logic for `HSEmotion` + `DIP(Sobel, DoG)`.

- [x] Gaze Stability: Improved accuracy via EMA filters and non-linear acceleration.

- [x] Intelligent STT: Implemented multi-lang Auto-Detection based on Whisper (Medium).

- [x] Dynamic Translation: Integrated Gemma2-based user-selectable Target Language system.

- [x] VAD Integration: Applied Whisper VAD filter to prevent hallucinations and optimize silent intervals.

**2️⃣ Backend & Intelligence (Architecture)**

- [x] Backend Architecture: Structuralized FastAPI-based SSE streaming and RAG services.

- [x] Vector RAG Engine: Established lecture content embedding and similarity search using Supabase Vector.

- [x] Context-aware Q&A: Completed RAG logic for context-retention from previous lecture segments.

- [x] Schema Optimization: Secured data structure by adding `target_lang` and multi-lang support.

**3️⃣ High-Performance Scaling (Testing & Deployment)**

- [ ] High-perf Model Deployment: Testing vLLM engine for serving Gemma2-9B/27B models on GPU servers.

- [ ] Hardware Acceleration: Maximizing real-time performance via Whisper Large-v3 and CUDA acceleration.

- [ ] Throughput Benchmarking: Measuring latency and throughput for concurrent multi-user access.

- [ ] Analysis Report Generation: Completing API for automatic report generation based on engagement/stability data.

**4️⃣ Frontend Integration (Flutter)**

- [ ] SSE Real-time Integration: Testing real-time reception and visualization of analysis data on Flutter.

- [ ] Real-time Multi-lang UI: Implementing target language selection widgets and streaming caption viewers.

- [ ] Engagement Dashboard: Developing real-time engagement graphs and gaze heatmap visualization widgets.

---

## ⚙️ Getting Started ##

**Installation**
```Bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Create environment configuration (Required)
# Then, enter your Supabase URL and KEY in the .env file.
```

**Usage**
```Bash
# FastAPI server start
uvicorn App.main:app --reload

# Vision Engine test(Local)
python3 services/test_vision.py
```

---

## 🚀 Deployment & Runtime Options ##

The system supports three runtime modes depending on your hardware environment.

**Option A: Local Inference (Lightweight)**

Recommended for testing on personal laptops (MacBook M1/M2/M3, etc.).

1. **Ollama** based LLM (`Gemma2:2b`)

2. **Faster-Whisper** `Medium` model (CPU/MPS acceleration)

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

## 💻 Hardware Requirements

The system supports optimized model sizes based on the deployment environment.

| Component | Minimum (Laptop/Local) | Recommended (Server/GPU) |
| :--- | :--- | :--- |
| **GPU** | Apple Silicon (M1/M2/M3) | **NVIDIA RTX 5060 (12GB+ VRAM)** |
| **Acceleration** | MPS (Metal) / CPU | **CUDA (vLLM / TensorRT)** |
| **RAM** | 16GB | 32GB+ |
| **STT Model** | Faster-Whisper **Medium** | Faster-Whisper **Large-v3** |
| **LLM Model** | Gemma2-**2b** | Gemma2-**9b** or **27b** |
| **Capacity** | Single User Analysis | **Class-wide (30+) Real-time Analysis** |

---

## 📄 License ##

**MIT License**