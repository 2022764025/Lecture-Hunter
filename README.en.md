<p align="center">
  <img src="./assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>

<p align="center">
  <a href="#-getting-started">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
  </a>
  <a href="#-usage-examples">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
  </a>
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/status-In%20Development-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>Development of Flutter-based real-time caption and question widget for lecture interaction</b>
</p>

<p align="center">
  <a href="../README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  <a href="README.jp.md">🇯🇵 日本語</a> &nbsp;·&nbsp;
  <a href="README.zh.md">🇨🇳 简体中文</a>
</p>

> [!NOTE]
> Dong-A University AI Department SW-Centered University Industry-Linked Mirror Project
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **과제헌터**

---

### 📺 What is this project?

Have you ever seen subtitles on TV?

**It's an AI program that displays real-time captions on top of your lecture screen.**

The moment your professor speaks, it instantly appears as text on the screen.
Foreign language lectures are also shown with **Korean translations**,
and if there's something you don't understand, you can also **search** for it.
If you missed the lecture, it also **summarizes "what has been covered so far"**.

> 💡 **TIP**
> It's especially useful when you're afraid to raise your hand and ask questions. You can ask the AI secretly without anyone knowing! 🙈

---

### 📚 Table of Contents

* [Useful Situations](#-useful-situations)
* [Feature Preview](#-feature-preview)
* [Usage Examples](#-usage-examples)
* [How Does It Work?](#-how-does-it-work)
* [Getting Started](#-getting-started)
* [Current Development Status](#-current-development-status)
* [How to Use](#-how-to-use)
* [Tech Stack](#-tech-stack)
* [Project Structure](#-project-structure)
* [References](#references)

---

### 🙋 Useful Situations

| If you're in this situation...                                          | Here's how it helps                                              |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------- |
| "I can't understand a word of this English lecture..."                  | Korean translated captions help you understand.                  |
| "The professor speaks way too fast..."                                  | You can review missed content through the captions.              |
| "I came in 10 minutes late, what are we even talking about..."          | You can check the lecture flow by asking the AI.                 |
| "I want to ask a question but I'm too embarrassed to raise my hand..."  | You can quietly ask the AI.                                      |
| "A difficult word came up and I want to check it again..."              | You can search saved lecture terms to verify.                    |
| "I want to see the previous captions again..."                          | You can check past captions in the caption history.              |

---

### 🖼 Feature Preview

<table align="center">
  <tr>
    <th align="center">🎙 Real-time Captions & Translation</th>
    <th align="center">⚙️ Settings</th>
  </tr>
  <tr>
    <td align="center">
      Coming Soon
      <br/>
      <sub>View both the original text and Korean translation of received captions.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/caption_settings.png" width="360"/><br/>
      <sub>Adjust caption size, position, opacity, and theme.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">💬 Lecture AI Q&A</th>
    <th align="center">📚 Glossary Lookup</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/question_input.png" width="360"/><br/>
      <sub>Ask the AI questions based on the lecture content.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>Search and verify saved lecture terminology.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📜 Caption History</th>
    <th align="center">📝 Key Summary</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/caption_history.png" width="360"/><br/>
      <sub>Review past captions again.</sub>
    </td>
    <td align="center">
      Coming Soon<br/>
      <sub>Provides a brief summary of the lecture content.</sub>
    </td>
  </tr>
</table>

<br/>

---

### 💡 Usage Examples

**Situation: A class conducted in English**

```text
Professor:
"Now let's discuss the vanishing gradient problem."

On-screen Caption:
Original: Now let's discuss the vanishing gradient problem.
Translation: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.

Student Question:
"What is the vanishing gradient?"

AI Answer:
The vanishing gradient is a phenomenon where, as a neural network becomes deeper,
the learning signal becomes difficult to propagate to earlier layers,
making training challenging.
```

<br>

## 🔄 How Does It Work?

> **Microphone listens to the professor's voice → AI converts it to text → Displayed on your screen**

In a bit more detail:

```
1️⃣  The professor speaks
        ↓
2️⃣  AI listens and converts speech to text
   (Automatically translated to Korean if in English)
        ↓
3️⃣  Displayed as captions on your screen
        ↓
4️⃣  Something you don't understand?  → Ask the AI!
    Missed the lecture flow?          → Click the Summary button!
```

<br/>

## 🚀 Getting Started

| Item             | Version      |
|------------------|--------------|
| Python           | 3.12         |
| Flutter          | 3.x          |
| Ollama           | Latest       |
| Supabase Account | -            |

**Installation**

```bash
# 1. Clone the project
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# 2. Set up the backend
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt

# 3. Configure environment (create .env file and enter the following)
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
# 4. Set up the frontend
cd Frontend
flutter pub get
cd ..
```

**Running → Please open 3 terminal windows**

```bash
# Terminal 1: Start the AI model server
ollama serve

# Terminal 2: Start the backend server
cd ~/Downloads/Lecture-Hunter
source pikmin/bin/activate
cd App
uvicorn main:app --reload

# Terminal 3: Run the frontend
cd Frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

**Verify it's running correctly**
- Open `http://127.0.0.1:8000` in your browser — if you get a response, it's **OK**
- If the caption screen appears in Chrome — **OK**
- If the caption, question, and glossary buttons are visible — **OK**

<br>

---

## 📊 Current Development Status

| Feature                            | Status         |
|------------------------------------|----------------|
| Question API integration           | ✅ Complete    |
| Question history reset             | ✅ Complete    |
| Glossary API integration           | ✅ Complete    |
| Real-time caption reception        | ✅ Complete    |
| Manual caption display test        | ✅ Complete    |
| Audio WebSocket connection         | ✅ Complete    |
| Live microphone speech-to-caption  | ⏳ Planned     |
| Key summary feature                | 🔄 In Progress |
| Slide image analysis               | 🔄 In Progress |
| Multi-user concurrent test         | ⏳ Planned     |

### 🧪 Remaining Core Tasks

| Task                                    | Status  |
|-----------------------------------------|---------|
| Live microphone input                   | Planned |
| Sending mic audio to backend            | Planned |
| Speech-to-caption conversion            | Planned |
| Real-time display of converted captions | Planned |
| Full flow test with live audio          | Planned |

---

## 🧭 How to Use

When the Flutter screen launches, a learning assistant widget appears over the lecture screen.
Just tap each button to start using it right away!

| Feature              | How to Use                                                                  |
|----------------------|-----------------------------------------------------------------------------|
| View Captions        | The original text and translation appear at the bottom of the screen. Just look! |
| Ask a Question       | Open the question panel, type your question, and the AI will answer         |
| Start New Question   | Press this when you want to clear previous questions and start fresh        |
| Search Terminology   | Search for unfamiliar words in the Glossary tab                             |
| Caption History      | Check this when you want to review past captions                            |
| Live Server Mode     | Switch to this mode when connecting to a real lecture                       |

<br/>

---

## 🛠 Tech Stack

| Area                    | Technology        | Why We Used It                                              |
|-------------------------|-------------------|-------------------------------------------------------------|
| Frontend                | Flutter           | To build the caption, question, and glossary screens        |
| Backend                 | FastAPI           | To create the communication channel between AI and frontend |
| AI Model Runtime        | Ollama            | To run AI locally without an internet connection            |
| Speech Recognition      | Faster-Whisper    | To convert the professor's voice to text                    |
| Voice Activity Detection | Silero VAD       | To detect only the speaking segments                        |
| Data Storage            | Supabase          | To store lecture content and caption data                   |
| Real-time Transmission  | Supabase Realtime | To send captions to the screen in real time                 |
| Audio Connection        | WebSocket         | To send microphone audio to the server                      |

<br/>

---

## 📁 Project Structure

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

<br/>

---

### References

- Flutter Official Docs: https://docs.flutter.dev/
- FastAPI Official Docs: https://fastapi.tiangolo.com/
- Supabase Official Docs: https://supabase.com/docs
- Ollama Official Docs: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 Until lectures become a little easier</sub>
</p>
