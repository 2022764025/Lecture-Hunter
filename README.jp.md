<p align="center">
  <img src="./assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>
  
  <p align="center">
    <a href="#-はじめに">
      <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
    </a>
    <a href="#-使用例">
      <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
    </a>
    <br/>
    <img alt="Status" src="https://img.shields.io/badge/status-開発中-orange?style=flat-square" />
    <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
    <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
    <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
  </p>
  
  <p align="center">
    <b>講義インタラクションのためのFlutterベースリアルタイム字幕・質問ウィジェット開発</b>
  </p>
  
  <p align="center">
    <a href="../README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
    <a href="README.en.md">🇺🇸 English</a> &nbsp;·&nbsp;
    <a href="README.zh.md">🇨🇳 简体中文</a>
  </p>
  
  > [!NOTE]
  > 東亜大学AI学科SW中心大学事業 現場ミラー型連携プロジェクト
  > 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **課題ハンターチーム**
  
  ---
  
  ### 📺 このプロジェクトは何ですか？
  
  テレビで字幕を見たことがありますよね？
  
  **講義画面の上にリアルタイム字幕が表示されるAIプログラムです。**
  
  教授が話した瞬間、すぐに文字として画面に現れます。
  外国語の講義も**韓国語に翻訳**して表示し、
  わからないことがあれば**検索**もできます。
  講義を聞き逃したら**「ここまでに何をしたか」の要約**もしてくれます。
  
  > 💡 **TIP**
  > 手を挙げて質問するのが怖いときに特に便利です。誰にも気づかれずにAIだけに聞くことができます！ 🙈
  
  ---
  
  ### 📚 目次
  
  * [こんな状況に便利](#-こんな状況に便利)
  * [主な機能プレビュー](#-主な機能プレビュー)
  * [使用例](#-使用例)
  * [どのように動作しますか？](#-どのように動作しますか)
  * [はじめに](#-はじめに)
  * [現在の開発状況](#-現在の開発状況)
  * [使い方](#-使い方)
  * [使用技術](#-使用技術)
  * [プロジェクト構成](#-プロジェクト構成)
  * [参考資料](#参考資料)
  
  ---
  
  ### 🙋 こんな状況に便利
  
  | こんな状況なら...                                        | こんな風に助けてくれます                             |
  | ------------------------------------------------------- | ---------------------------------------------------- |
  | 「英語の講義で全然聞き取れない...」                       | 韓国語翻訳字幕で理解を助けます。                     |
  | 「教授の話が速すぎて...」                                 | 聞き逃した内容を字幕で再確認できます。               |
  | 「10分遅れてきたけど今何の話してるの...」                 | AIへの質問で講義の流れを確認できます。               |
  | 「質問したいけど手を挙げるのが恥ずかしい...」             | AIに静かに質問できます。                             |
  | 「難しい単語が出てきたので再確認したい...」               | 保存された講義用語を検索して確認できます。           |
  | 「過ぎた字幕をもう一度見たい...」                         | 字幕履歴から以前の字幕を確認できます。               |
  
  ---
  
  ### 🖼 主な機能プレビュー
  
  <table align="center">
    <tr>
      <th align="center">🎙 リアルタイム字幕と翻訳</th>
      <th align="center">⚙️ 設定</th>
    </tr>
    <tr>
      <td align="center">
        準備中
        <br/>
        <sub>受信した字幕の原文と韓国語翻訳を一緒に見ることができます。</sub>
      </td>
      <td align="center">
        <img src="../assets/screens/caption_settings.png" width="360"/><br/>
        <sub>字幕のサイズ、位置、透明度、テーマを調整できます。</sub>
      </td>
    </tr>
  
    <tr>
      <th align="center">💬 講義AIへの質問</th>
      <th align="center">📚 用語集検索</th>
    </tr>
    <tr>
      <td align="center">
        <img src="../assets/screens/question_input.png" width="360"/><br/>
        <sub>講義内容をもとにAIに質問できます。</sub>
      </td>
      <td align="center">
        <img src="../assets/screens/glossary_tab.png" width="360"/><br/>
        <sub>保存された講義用語を検索して確認できます。</sub>
      </td>
    </tr>
  
    <tr>
      <th align="center">📜 過去の字幕を見る</th>
      <th align="center">📝 要点まとめ</th>
    </tr>
    <tr>
      <td align="center">
        <img src="../assets/screens/caption_history.png" width="360"/><br/>
        <sub>過去の字幕も再確認できます。</sub>
      </td>
      <td align="center">
        準備中<br/>
        <sub>講義内容を短くまとめます。</sub>
      </td>
    </tr>
  </table>
  
  <br/>
  
  ---
  
  ### 💡 使用例
  
  **状況：英語で進行される授業**
  
  ```text
  教授:
  "Now let's discuss the vanishing gradient problem."
  
  画面の字幕:
  原文: Now let's discuss the vanishing gradient problem.
  翻訳: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.
  
  学生の質問:
  「勾配消失って何ですか？」
  
  AIの回答:
  勾配消失とは、ニューラルネットワークが深くなるほど学習信号が前の層に
  うまく伝わらなくなり、学習が困難になる現象です。
  ```
  
  <br>
  
  ## 🔄 どのように動作しますか？
  
  > **マイクで教授の声を聞いて → AIがテキストに変換して → 画面に表示する**
  
  もう少し詳しく説明すると：
  
  ```
  1️⃣  教授が話す
          ↓
  2️⃣  AIが声を聞いてテキストに変換する
     （英語なら韓国語にも自動翻訳）
          ↓
  3️⃣  画面に字幕として表示される
          ↓
  4️⃣  わからないことは？  → AIに質問！
      講義の流れを逃したら？ → 要約ボタンをクリック！
  ```
  
  <br/>
  
  ## 🚀 はじめに
  
  | 項目             | バージョン   |
  |------------------|-------------|
  | Python           | 3.12        |
  | Flutter          | 3.x         |
  | Ollama           | 最新バージョン |
  | Supabaseアカウント | -          |
  
  **インストール**
  
  ```bash
  # 1. プロジェクトをクローン
  git clone https://github.com/2022764025/Lecture-Hunter.git
  cd Lecture-Hunter
  
  # 2. バックエンドの準備
  python3 -m venv pikmin
  source pikmin/bin/activate
  pip install -r requirements.txt
  
  # 3. 環境設定（.envファイルを作成し、以下の内容を入力）
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
  # 4. フロントエンドの準備
  cd Frontend
  flutter pub get
  cd ..
  ```
  
  **実行 → ターミナルウィンドウを3つ開いてください**
  
  ```bash
  # ターミナル1: AIモデルサーバーを起動
  ollama serve
  
  # ターミナル2: バックエンドサーバーを起動
  cd ~/Downloads/Lecture-Hunter
  source pikmin/bin/activate
  cd App
  uvicorn main:app --reload
  
  # ターミナル3: フロントエンドを実行
  cd Frontend
  flutter run -d chrome \
    --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
    --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
    --dart-define=SUPABASE_URL=your_supabase_url \
    --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key \
    --dart-define=LECTURE_ID=demo-lecture \
    --dart-define=TARGET_LANG=Korean
  ```
  
  **正常に動作しているか確認**
  - アドレスバーに `http://127.0.0.1:8000` を開いてレスポンスがあれば **OK**
  - Chromeで字幕画面が表示されれば **OK**
  - 字幕・質問・用語集のボタンが見えれば **OK**
  
  <br>
  
  ---
  
  ## 📊 現在の開発状況
  
  | 機能                          | 状態           |
  |-------------------------------|----------------|
  | 質問API連携                   | ✅ 完了        |
  | 質問履歴のリセット             | ✅ 完了        |
  | 用語集API連携                 | ✅ 完了        |
  | リアルタイム字幕受信           | ✅ 完了        |
  | 手動字幕表示テスト             | ✅ 完了        |
  | 音声WebSocket接続             | ✅ 完了        |
  | 実際のマイク音声の字幕変換     | ⏳ 予定        |
  | 要点まとめ機能                 | 🔄 進行中      |
  | スライド画像分析               | 🔄 進行中      |
  | 複数人同時使用テスト           | ⏳ 予定        |
  
  ### 🧪 残りの主要タスク
  
  | 作業                             | 状態 |
  |----------------------------------|------|
  | 実際のマイク入力                  | 予定 |
  | マイク音声をバックエンドへ送信    | 予定 |
  | 音声字幕変換                      | 予定 |
  | 変換された字幕のリアルタイム表示  | 予定 |
  | 実際の音声ベースの全フローテスト  | 予定 |
  
  ---
  
  ## 🧭 使い方
  
  Flutterの画面が起動すると、講義画面の上に学習アシスタントウィジェットが表示されます。
  ボタンを一つずつ押すとすぐに使えます！
  
  | 機能             | 使い方                                                                        |
  |------------------|-------------------------------------------------------------------------------|
  | 字幕を見る       | 画面下部に原文と翻訳が一緒に表示されます。そのまま見るだけでOK！             |
  | 質問する         | 質問パネルを開いて気になることを入力するとAIが答えます                        |
  | 新しい質問を始める | 前の質問内容を消して新しく始めたいときに押します                            |
  | 用語検索         | 用語集タブでわからない単語を検索して確認します                                |
  | 字幕履歴         | 過ぎた字幕をもう一度見たいときに確認します                                    |
  | 実サーバー接続   | 実際の講義と接続して使うときにこのモードに切り替えます                        |
  
  <br/>
  
  ---
  
  ## 🛠 使用技術
  
  | 領域               | 使用技術           | なぜ使用したか？                                               |
  |--------------------|--------------------|----------------------------------------------------------------|
  | 画面               | Flutter            | 字幕・質問・用語集の画面を作るために使用しました               |
  | サーバー           | FastAPI            | AIと画面が互いに通信するチャネルを作るために使用しました       |
  | AIモデル実行       | Ollama             | インターネットなしでAIをローカルで動かすために使用しました     |
  | 音声認識           | Faster-Whisper     | 教授の声をテキストに変換するために使用しました                 |
  | 音声区間検出       | Silero VAD         | 話している区間だけを検出するために使用しました                 |
  | データ保存         | Supabase           | 講義内容と字幕データを保存するために使用しました               |
  | リアルタイム転送   | Supabase Realtime  | 字幕を画面にリアルタイムで送信するために使用しました           |
  | 音声接続           | WebSocket          | マイクの音をサーバーに送信するために使用しました               |
  
  <br/>
  
  ---
  
  ## 📁 プロジェクト構成
  
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
  
  ### 参考資料
  
  - Flutter公式ドキュメント: https://docs.flutter.dev/
  - FastAPI公式ドキュメント: https://fastapi.tiangolo.com/
  - Supabase公式ドキュメント: https://supabase.com/docs
  - Ollama公式ドキュメント: https://ollama.com/
  - Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper
  
  ---
  
  <p align="center">
    <sub>🎓 講義が少し楽になるその日まで</sub>
  </p>"#-getting-started">
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
<p align="center">
  <img src="../assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>

<p align="center">
  <a href="#-はじめに">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
  </a>
  <a href="#-使用例">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
  </a>
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/status-開発中-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>講義インタラクションのためのFlutterベースリアルタイム字幕・質問ウィジェット開発</b>
</p>

<p align="center">
  <a href="../README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  <a href="README.en.md">🇺🇸 English</a> &nbsp;·&nbsp;
  🇯🇵 日本語 &nbsp;·&nbsp;
  <a href="README.zh.md">🇨🇳 简体中文</a>
</p>

> [!NOTE]
> 東亜大学AI学科SW中心大学事業 現場ミラー型連携プロジェクト
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **課題ハンターチーム**

---

### 📺 このプロジェクトは何ですか？

テレビで字幕を見たことがありますよね？

**講義画面の上にリアルタイム字幕が表示されるAIプログラムです。**

教授が話した瞬間、すぐに文字として画面に現れます。
外国語の講義も**韓国語に翻訳**して表示し、
わからないことがあれば**検索**もできます。
講義を聞き逃したら**「ここまでに何をしたか」の要約**もしてくれます。

> 💡 **TIP**
> 手を挙げて質問するのが怖いときに特に便利です。誰にも気づかれずにAIだけに聞くことができます！ 🙈

---

### 📚 目次

* [こんな状況に便利](#-こんな状況に便利)
* [主な機能プレビュー](#-主な機能プレビュー)
* [使用例](#-使用例)
* [どのように動作しますか？](#-どのように動作しますか)
* [はじめに](#-はじめに)
* [現在の開発状況](#-現在の開発状況)
* [使い方](#-使い方)
* [使用技術](#-使用技術)
* [プロジェクト構成](#-プロジェクト構成)
* [参考資料](#参考資料)

---

### 🙋 こんな状況に便利

| こんな状況なら...                                        | こんな風に助けてくれます                             |
| ------------------------------------------------------- | ---------------------------------------------------- |
| 「英語の講義で全然聞き取れない...」                       | 韓国語翻訳字幕で理解を助けます。                     |
| 「教授の話が速すぎて...」                                 | 聞き逃した内容を字幕で再確認できます。               |
| 「10分遅れてきたけど今何の話してるの...」                 | AIへの質問で講義の流れを確認できます。               |
| 「質問したいけど手を挙げるのが恥ずかしい...」             | AIに静かに質問できます。                             |
| 「難しい単語が出てきたので再確認したい...」               | 保存された講義用語を検索して確認できます。           |
| 「過ぎた字幕をもう一度見たい...」                         | 字幕履歴から以前の字幕を確認できます。               |

---

### 🖼 主な機能プレビュー

<table align="center">
  <tr>
    <th align="center">🎙 リアルタイム字幕と翻訳</th>
    <th align="center">⚙️ 設定</th>
  </tr>
  <tr>
    <td align="center">
      準備中
      <br/>
      <sub>受信した字幕の原文と韓国語翻訳を一緒に見ることができます。</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/caption_settings.png" width="360"/><br/>
      <sub>字幕のサイズ、位置、透明度、テーマを調整できます。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">💬 講義AIへの質問</th>
    <th align="center">📚 用語集検索</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/question_input.png" width="360"/><br/>
      <sub>講義内容をもとにAIに質問できます。</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>保存された講義用語を検索して確認できます。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📜 過去の字幕を見る</th>
    <th align="center">📝 要点まとめ</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/caption_history.png" width="360"/><br/>
      <sub>過去の字幕も再確認できます。</sub>
    </td>
    <td align="center">
      準備中<br/>
      <sub>講義内容を短くまとめます。</sub>
    </td>
  </tr>
</table>

<br/>

---

### 💡 使用例

**状況：英語で進行される授業**

```text
教授:
"Now let's discuss the vanishing gradient problem."

画面の字幕:
原文: Now let's discuss the vanishing gradient problem.
翻訳: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.

学生の質問:
「勾配消失って何ですか？」

AIの回答:
勾配消失とは、ニューラルネットワークが深くなるほど学習信号が前の層に
うまく伝わらなくなり、学習が困難になる現象です。
```

<br>

## 🔄 どのように動作しますか？

> **マイクで教授の声を聞いて → AIがテキストに変換して → 画面に表示する**

もう少し詳しく説明すると：

```
1️⃣  教授が話す
        ↓
2️⃣  AIが声を聞いてテキストに変換する
   （英語なら韓国語にも自動翻訳）
        ↓
3️⃣  画面に字幕として表示される
        ↓
4️⃣  わからないことは？  → AIに質問！
    講義の流れを逃したら？ → 要約ボタンをクリック！
```

<br/>

## 🚀 はじめに

| 項目             | バージョン   |
|------------------|-------------|
| Python           | 3.12        |
| Flutter          | 3.x         |
| Ollama           | 最新バージョン |
| Supabaseアカウント | -          |

**インストール**

```bash
# 1. プロジェクトをクローン
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# 2. バックエンドの準備
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt

# 3. 環境設定（.envファイルを作成し、以下の内容を入力）
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
# 4. フロントエンドの準備
cd Frontend
flutter pub get
cd ..
```

**実行 → ターミナルウィンドウを3つ開いてください**

```bash
# ターミナル1: AIモデルサーバーを起動
ollama serve

# ターミナル2: バックエンドサーバーを起動
cd ~/Downloads/Lecture-Hunter
source pikmin/bin/activate
cd App
uvicorn main:app --reload

# ターミナル3: フロントエンドを実行
cd Frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

**正常に動作しているか確認**
- アドレスバーに `http://127.0.0.1:8000` を開いてレスポンスがあれば **OK**
- Chromeで字幕画面が表示されれば **OK**
- 字幕・質問・用語集のボタンが見えれば **OK**

<br>

---

## 📊 現在の開発状況

| 機能                          | 状態           |
|-------------------------------|----------------|
| 質問API連携                   | ✅ 完了        |
| 質問履歴のリセット             | ✅ 完了        |
| 用語集API連携                 | ✅ 完了        |
| リアルタイム字幕受信           | ✅ 完了        |
| 手動字幕表示テスト             | ✅ 完了        |
| 音声WebSocket接続             | ✅ 完了        |
| 実際のマイク音声の字幕変換     | ⏳ 予定        |
| 要点まとめ機能                 | 🔄 進行中      |
| スライド画像分析               | 🔄 進行中      |
| 複数人同時使用テスト           | ⏳ 予定        |

### 🧪 残りの主要タスク

| 作業                             | 状態 |
|----------------------------------|------|
| 実際のマイク入力                  | 予定 |
| マイク音声をバックエンドへ送信    | 予定 |
| 音声字幕変換                      | 予定 |
| 変換された字幕のリアルタイム表示  | 予定 |
| 実際の音声ベースの全フローテスト  | 予定 |

---

## 🧭 使い方

Flutterの画面が起動すると、講義画面の上に学習アシスタントウィジェットが表示されます。
ボタンを一つずつ押すとすぐに使えます！

| 機能             | 使い方                                                                        |
|------------------|-------------------------------------------------------------------------------|
| 字幕を見る       | 画面下部に原文と翻訳が一緒に表示されます。そのまま見るだけでOK！             |
| 質問する         | 質問パネルを開いて気になることを入力するとAIが答えます                        |
| 新しい質問を始める | 前の質問内容を消して新しく始めたいときに押します                            |
| 用語検索         | 用語集タブでわからない単語を検索して確認します                                |
| 字幕履歴         | 過ぎた字幕をもう一度見たいときに確認します                                    |
| 実サーバー接続   | 実際の講義と接続して使うときにこのモードに切り替えます                        |

<br/>

---

## 🛠 使用技術

| 領域               | 使用技術           | なぜ使用したか？                                               |
|--------------------|--------------------|----------------------------------------------------------------|
| 画面               | Flutter            | 字幕・質問・用語集の画面を作るために使用しました               |
| サーバー           | FastAPI            | AIと画面が互いに通信するチャネルを作るために使用しました       |
| AIモデル実行       | Ollama             | インターネットなしでAIをローカルで動かすために使用しました     |
| 音声認識           | Faster-Whisper     | 教授の声をテキストに変換するために使用しました                 |
| 音声区間検出       | Silero VAD         | 話している区間だけを検出するために使用しました                 |
| データ保存         | Supabase           | 講義内容と字幕データを保存するために使用しました               |
| リアルタイム転送   | Supabase Realtime  | 字幕を画面にリアルタイムで送信するために使用しました           |
| 音声接続           | WebSocket          | マイクの音をサーバーに送信するために使用しました               |

<br/>

---

## 📁 プロジェクト構成

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

### 参考資料

- Flutter公式ドキュメント: https://docs.flutter.dev/
- FastAPI公式ドキュメント: https://fastapi.tiangolo.com/
- Supabase公式ドキュメント: https://supabase.com/docs
- Ollama公式ドキュメント: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 講義が少し楽になるその日まで</sub>
</p>
