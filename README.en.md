<p align="center">
  <img src="./assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>

<p align="center">
  <a href="#-getting-started">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
  </a>
  <a href="#-demo">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
  </a>
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/status-in%20development-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>Real-Time Lecture Captioning and AI Interaction Widget Built with Flutter</b>
</p>

> [!NOTE]
> Dong-A University AI Department SW-Centered University Industry-Linked Project
>
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **과제헌터**

---

### 📺 What is this project?

Have you ever seen subtitles on TV?

**Lecture Hunter displays real-time captions directly on top of lecture screens.**

As soon as a professor speaks, the speech is converted into text and displayed instantly.
Foreign-language lectures can be automatically translated into Korean.
Students can ask questions about the lecture content, search lecture-related terms, and even request summaries of what has been covered so far.

> 💡 **TIP**
>
> Especially useful when you're too shy to raise your hand. You can quietly ask the AI instead. 🙈

---

### 📚 Table of Contents

* [Use Cases](#-use-cases)
* [Features Preview](#-features-preview)
* [Demo](#-demo)
* [How It Works](#-how-it-works)
* [Getting Started](#-getting-started)
* [Development Status](#-development-status)
* [How to Use](#-how-to-use)
* [Tech Stack](#-tech-stack)
* [Project Structure](#-project-structure)
* [References](#references)

---

### 🙋 Use Cases

| Situation                                                | How Lecture Hunter Helps                           |
| -------------------------------------------------------- | -------------------------------------------------- |
| "The lecture is in English and I can't follow it."       | Provides translated Korean subtitles in real time. |
| "The professor speaks too fast."                         | Lets you review missed content through captions.   |
| "I joined 10 minutes late. What are they talking about?" | AI can explain the lecture context and flow.       |
| "I'm too shy to ask questions in class."                 | Ask the AI privately instead.                      |
| "I want to check a technical term again."                | Search the built-in lecture glossary.              |
| "I want to review previous captions."                    | Access caption history anytime.                    |

---

### 🖼 Features Preview

| Feature                             | Description                                                      |
| ----------------------------------- | ---------------------------------------------------------------- |
| 🎙 Real-Time Captions & Translation | Displays original speech and translated captions simultaneously. |
| ⚙️ Caption Settings                 | Customize size, position, transparency, and theme.               |
| 💬 AI Lecture Assistant             | Ask questions based on lecture content.                          |
| 📚 Glossary Search                  | Search and review lecture-related terms.                         |
| 📜 Caption History                  | Revisit previous captions.                                       |
| 📝 Lecture Summary                  | Generate concise summaries of lecture content. *(In Progress)*   |

---

### 💡 Demo

**Scenario: An English Lecture**

```text
Professor:
"Now let's discuss the vanishing gradient problem."

Caption:
Original: Now let's discuss the vanishing gradient problem.
Translation: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.

Student Question:
"What is the vanishing gradient problem?"

AI Response:
The vanishing gradient problem occurs when gradients become
progressively smaller as they propagate through deep neural networks,
making learning difficult in earlier layers.
```

---

### 🔄 How It Works

> **The microphone captures the professor's voice → AI converts speech into text → Captions appear on your screen**

```text
1️⃣ Professor speaks
        ↓
2️⃣ AI converts speech into text
   (and translates it when needed)
        ↓
3️⃣ Captions are displayed on screen
        ↓
4️⃣ Need help?
    → Ask the AI a question
    → Generate a lecture summary
```

---

### 🚀 Getting Started

| Component        | Version  |
| ---------------- | -------- |
| Python           | 3.12     |
| Flutter          | 3.x      |
| Ollama           | Latest   |
| Supabase Account | Required |

#### Installation

```bash
# Clone repository
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# Backend setup
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt

# Environment configuration
cp .env.example .env
```

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
LLM_MODEL=gemma2:2b
VLM_MODEL=llama3.2-vision:11b
WHISPER_MODEL_SIZE=medium
WHISPER_DEVICE=auto
VAD_THRESHOLD=0.3
```

```bash
# Frontend setup
cd Frontend
flutter pub get
cd ..
```

#### Run the Project

Open three terminal windows.

```bash
# Terminal 1: Start Ollama
ollama serve
```

```bash
# Terminal 2: Start Backend
source pikmin/bin/activate
cd App
uvicorn main:app --reload
```

```bash
# Terminal 3: Run Flutter
cd Frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

#### Verify Installation

* Open `http://127.0.0.1:8000` → Backend responds ✅
* Flutter UI appears in Chrome ✅
* Caption, Question, and Glossary buttons are visible ✅

---

### 📊 Development Status

| Feature                            | Status         |
| ---------------------------------- | -------------- |
| Question API Integration           | ✅ Completed    |
| Question History Reset             | ✅ Completed    |
| Glossary API Integration           | ✅ Completed    |
| Real-Time Caption Reception        | ✅ Completed    |
| Manual Caption Rendering Test      | ✅ Completed    |
| Audio WebSocket Connection         | ✅ Completed    |
| Live Microphone Speech Recognition | ⏳ Planned      |
| Lecture Summary Feature            | 🔄 In Progress |
| Slide Image Analysis               | 🔄 In Progress |
| Multi-User Testing                 | ⏳ Planned      |

---

### 🧪 Remaining Tasks

| Task                              | Status  |
| --------------------------------- | ------- |
| Live Microphone Input             | Planned |
| Audio Streaming to Backend        | Planned |
| Speech-to-Text Processing         | Planned |
| Real-Time Caption Display         | Planned |
| End-to-End Voice Workflow Testing | Planned |

---

### 🧭 How to Use

Once the Flutter application is running, a lecture assistant widget appears on top of the lecture screen.

| Feature          | Usage                                                       |
| ---------------- | ----------------------------------------------------------- |
| Captions         | View original and translated captions in real time.         |
| Ask Questions    | Open the question panel and ask anything about the lecture. |
| New Session      | Clear previous conversations and start fresh.               |
| Glossary Search  | Search lecture-related terms.                               |
| Caption History  | Review previously displayed captions.                       |
| Live Server Mode | Connect to a real lecture environment.                      |

---

### 🛠 Tech Stack

| Area                     | Technology        | Purpose                                     |
| ------------------------ | ----------------- | ------------------------------------------- |
| Frontend                 | Flutter           | Interactive caption and AI assistant UI     |
| Backend                  | FastAPI           | Communication layer between AI and frontend |
| AI Runtime               | Ollama            | Local AI model execution                    |
| Speech Recognition       | Faster-Whisper    | Speech-to-text conversion                   |
| Voice Activity Detection | Silero VAD        | Detects speaking segments                   |
| Database                 | Supabase          | Stores lecture and caption data             |
| Realtime Sync            | Supabase Realtime | Real-time caption delivery                  |
| Audio Streaming          | WebSocket         | Transfers microphone audio to backend       |

---

### 📁 Project Structure

```text
Lecture-Hunter
│
├── App/
│   ├── main.py
│   ├── api/
│   ├── core/
│   ├── services/
│   └── ...
│
├── Frontend/
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   │   ├── assistant/
│   │   │   ├── caption/
│   │   │   └── overlay/
│   │   ├── services/
│   │   └── main.dart
│   └── pubspec.yaml
│
├── assets/
│   ├── LectureHunter_Logo3.jpeg
│   └── screens/
│
├── README.md
├── requirements.txt
└── Dockerfile
```

---

### References

* Flutter: https://docs.flutter.dev/
* FastAPI: https://fastapi.tiangolo.com/
* Supabase: https://supabase.com/docs
* Ollama: https://ollama.com/
* Faster-Whisper: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 Making lectures easier to understand, one caption at a time.</sub>
</p>
