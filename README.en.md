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
  <img alt="Status" src="https://img.shields.io/badge/status-in%20development-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>A Flutter-based real-time caption and Q&A widget for lecture interaction</b>
</p>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  🇺🇸 English &nbsp;·&nbsp;
  <a href="README.jp.md">🇯🇵 日本語</a> &nbsp;·&nbsp;
  <a href="README.zh.md">🇨🇳 简体中文</a>
</p>

> [!NOTE]
> Dong-A University AI Department — SW-oriented University Field-Mirror Linked Project
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **Team 과제헌터**

---

### 📺 What is this project?

Ever seen subtitles on TV?

**This is an AI program that displays real-time captions directly over your lecture screen.**

The moment your professor speaks, the words appear on screen instantly.
Foreign-language lectures are **translated into English** for you,
and if there's something you don't understand, you can **search** for it.
If you missed part of a lecture, it can even **summarize what's happened so far**.

> 💡 **TIP**
> Especially handy when you're too shy to raise your hand — you can quietly ask the AI without anyone knowing! 🙈

---

### 📚 Table of Contents

* [When is this useful?](#-when-is-this-useful)
* [Feature Overview](#-feature-overview)
* [Usage Examples](#-usage-examples)
* [How does it work?](#-how-does-it-work)
* [Getting Started](#-getting-started)
* [Current Development Status](#-current-development-status)
* [How to Use](#-how-to-use)
* [Tech Stack](#-tech-stack)
* [Project Structure](#-project-structure)
* [References](#references)

---

### 🙋 When is this useful?

| Situation | How it helps |
| ------------------------------------ | --------------------------------------------- |
| "This lecture is in English and I can't follow..." | Real-time translated captions help you understand. |
| "The professor is speaking too fast..." | You can review what you missed via captions. |
| "I came in 10 minutes late — what's going on?" | Use the AI Q&A to catch up on the lecture flow. |
| "I want to ask a question but I'm too shy..." | Ask the AI quietly without anyone noticing. |
| "There was a hard term I want to look up again..." | Search saved lecture terms in the glossary. |

---

### 🖼 Key Features

<table align="center">
  <tr>
    <th align="center">🎙 Real-time Captions & Translation</th>
    <th align="center">💬 AI Q&A for Lectures</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/real-time captions.png" width="360"/>
      <br/>
      <sub>View both the original text and its English translation side by side.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/question_input.png" width="360"/><br/>
      <sub>Ask the AI questions based on the lecture content.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📚 Glossary Lookup</th>
    <th align="center">📝 Key Summary</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>Search and review saved lecture terminology.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/key_summary_features.png" width="360"/><br/>
      <sub>Get a concise summary of the lecture content.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">⚙️ Settings</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/caption_settings.png" width="360"/><br/>
      <sub>Adjust caption size, position, opacity, and theme.</sub>
    </td>
  </tr>
</table>

<br/>

---

### 💡 Usage Examples

**Scenario: A lecture conducted in English**

```text
Professor:
"Now let's discuss the vanishing gradient problem."

On-screen caption:
Original: Now let's discuss the vanishing gradient problem.
Translation: Let's now talk about the vanishing gradient problem.

Student question:
"What is the vanishing gradient?"

AI answer:
The vanishing gradient problem refers to the phenomenon where, as a neural
network becomes deeper, the training signal fails to propagate well to the
earlier layers, making learning increasingly difficult.
```

<br>

## 🔄 How does it work?

> **The microphone picks up the professor's voice → AI converts it to text → It appears on your screen**

Breaking it down step by step:

```
1️⃣  The professor speaks
        ↓
2️⃣  The AI listens and converts speech to text
   (automatically translated if the lecture is in a foreign language)
        ↓
3️⃣  Captions appear on your screen in real time
        ↓
4️⃣  Something unclear? → Ask the AI!
    Lost track of the lecture? → Hit the Summary button!
```

<br/>

## 🚀 Getting Started

> Open 3 terminal windows before you begin!

---

### STEP 0. Prerequisites _(one-time setup)_

| Program | Download |
|---------|---------|
| Python 3.12 | https://www.python.org/downloads/ |
| Flutter 3.x | https://docs.flutter.dev/get-started/install |
| Ollama | https://ollama.com/ |
| Google Chrome | https://www.google.com/chrome/ |
| Supabase account | https://supabase.com/ |

---

### STEP 1. Clone the repository

```bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter
```

---

### STEP 2. Set up the backend _(one-time setup)_

```bash
python3 -m venv pikmin
source pikmin/bin/activate        # Windows: pikmin\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # Open .env and fill in the values below
```

```env
SUPABASE_URL=enter_here
SUPABASE_ANON_KEY=enter_here
LLM_MODEL=gemma2:2b
VLM_MODEL=llama3.2-vision:11b
WHISPER_MODEL_SIZE=medium
WHISPER_DEVICE=auto
VAD_THRESHOLD=0.3
```

> 💡 Find your URL and KEY in the Supabase Dashboard → Project Settings → API

---

### STEP 3. Set up the frontend _(one-time setup)_

```bash
cd Frontend && flutter pub get && cd ..
```

---

### STEP 4. Run the app

**Terminal 1** — AI server
```bash
ollama serve
```

**Terminal 2** — Backend
```bash
source pikmin/bin/activate
cd App && uvicorn main:app --reload
```

**Terminal 3** — Frontend
```bash
cd Frontend
flutter run -d chrome \
  --web-port=9998 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=enter_here \
  --dart-define=SUPABASE_ANON_KEY=enter_here \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=English
```

---

### STEP 5. Install the Chrome Extension

1. Enter `chrome://extensions` in the Chrome address bar
2. Enable **Developer mode** in the top-right corner
3. Click **Load unpacked** → select the `Extension/` folder
4. Click the 🧩 icon → pin Lecture Hunter
5. Click the icon on your lecture tab → launch the widget

---

### ✅ Verify it's running

| Check | URL |
|---------|------|
| Backend | http://127.0.0.1:8000 |
| Frontend | http://127.0.0.1:9998 |
| Extension | Confirm the widget appears over your lecture tab |

<br>

---

## 📊 Current Development Status

| Feature | Status |
|------|------|
| Q&A API integration | ✅ Done |
| Question history reset | ✅ Done |
| Glossary API integration | ✅ Done |
| Real-time caption reception | ✅ Done |
| Manual caption display test | ✅ Done |
| Audio WebSocket connection | ✅ Done |
| Live microphone speech-to-text | ✅ Done |
| Key summary feature | ✅ Done |
| Slide image analysis | ✅ Done |
| Multi-user concurrent testing | ⏳ Planned |

---

## 🧭 How to Use

Once the Flutter screen launches, a learning assistant widget appears over your lecture screen.
Just tap each button to get started!

| Feature | How to use it |
|------|-----------------|
| View captions | The original text and translation appear at the bottom of the screen automatically. |
| Ask a question | Open the question panel, type your query, and the AI will answer. |
| Start a new question | Press this when you want to clear the previous conversation and start fresh. |
| Search terms | Go to the Glossary tab and search for any unfamiliar word. |
| Caption history | Review past captions you may have missed. |
| Live server mode | Switch to this mode when connecting to a real, live lecture. |

<br/>

---

## 🛠 Tech Stack

| Area | Technology | Why we chose it |
|------|-----------|---------------|
| UI | Flutter | For building the caption, Q&A, and glossary screens |
| Server | FastAPI | To create the communication channel between the AI and the UI |
| AI model runtime | Ollama | To run AI models locally without an internet connection |
| Speech recognition | Faster-Whisper | To convert the professor's voice into text |
| Voice activity detection | Silero VAD | To detect and isolate speech segments |
| Data storage | Supabase | To store lecture content and caption data |
| Real-time delivery | Supabase Realtime | To push captions to the screen in real time |
| Audio transport | WebSocket | To stream microphone audio to the server |

<br/>

---

## 📁 Project Structure

```text
Lecture-Hunter/
├── App/
│   ├── api/
│   ├── core/
│   ├── services/
│   └── main.py
├── Extension/
│   ├── background.js
│   ├── manifest.json
│   ├── offscreen.html
│   └── offscreen.js
├── Frontend/
│   ├── lib/
│   ├── web/
│   └── pubspec.yaml
├── assets/
├── Dockerfile
├── requirements.txt
└── README.md
```

<br/>

---

### References

- Flutter official docs: https://docs.flutter.dev/
- FastAPI official docs: https://fastapi.tiangolo.com/
- Supabase official docs: https://supabase.com/docs
- Ollama official docs: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 Until lectures become just a little easier for everyone</sub>
</p>