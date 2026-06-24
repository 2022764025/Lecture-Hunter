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
  <img alt="Status" src="https://img.shields.io/badge/ステータス-開発中-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>講義インタラクションのためのFlutterベースリアルタイム字幕・質問ウィジェット</b>
</p>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  <a href="README.en.md">🇺🇸 English</a> &nbsp;·&nbsp;
  🇯🇵 日本語 &nbsp;·&nbsp;
  <a href="README.zh.md">🇨🇳 简体中文</a>
</p>

> [!NOTE]
> 東亜大学 AI学科 SW中心大学事業 現場ミラー型連携プロジェクト
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓**과제헌터**

---

### 📺 このプロジェクトとは？

テレビで字幕を見たことがありますよね？

**講義画面の上にリアルタイムで字幕を表示するAIプログラムです。**

教授が話した瞬間、すぐに文字として画面に現れます。
外国語の講義も**日本語に翻訳**して表示し、
わからないことがあれば**検索**もできます。
講義を聞き逃したなら、**「ここまでの内容の要約」**も提供します。

> 💡 **TIP**
> 手を挙げて質問するのが恥ずかしいときに特に便利です。誰にも気づかれずにAIにこっそり聞けますよ！ 🙈

---

### 📚 目次

* [こんな場面で役立ちます](#-こんな場面で役立ちます)
* [主な機能](#-主な機能)
* [使用例](#-使用例)
* [どうやって動くの？](#-どうやって動くの)
* [はじめに](#-はじめに)
* [現在の開発状況](#-現在の開発状況)
* [使い方](#-使い方)
* [技術スタック](#-技術スタック)
* [プロジェクト構成](#-プロジェクト構成)
* [参考資料](#参考資料)

---

### 🙋 こんな場面で役立ちます

| こんな状況なら...                         | こう助けてくれます                          |
| ------------------------------------ | --------------------------------------------- |
| 「英語の講義で全然聞き取れない…」         | リアルタイム翻訳字幕で理解をサポートします。       |
| 「教授の話が速すぎてついていけない…」     | 見逃した内容を字幕で確認できます。               |
| 「10分遅れて入ったけど今何の話？」        | AI質問で講義の流れをキャッチアップできます。      |
| 「質問したいけど手を挙げるのが恥ずかしい…」 | AIに静かに質問できます。                        |
| 「難しい用語が出たけどもう一度確認したい…」 | 用語集に保存された講義用語を検索して確認できます。 |
| 「見逃した字幕をもう一度見たい…」         | 字幕履歴から過去の字幕を確認できます。           |

---

### 🖼 主な機能

<table align="center">
  <tr>
    <th align="center">🎙 リアルタイム字幕・翻訳</th>
    <th align="center">💬 講義AIへの質問</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/real-time captions.png" width="360"/>
      <br/>
      <sub>受信した字幕の原文と日本語訳を並べて表示します。</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/question_input.png" width="360"/><br/>
      <sub>講義内容をもとにAIに質問できます。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📚 用語集の検索</th>
    <th align="center">📝 重要ポイントの要約</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>保存された講義用語を検索して確認できます。</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/key_summary_features.png" width="360"/><br/>
      <sub>講義内容を短くまとめて表示します。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">⚙️ 設定</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/caption_settings.png" width="360"/><br/>
      <sub>字幕のサイズ・位置・透明度・テーマを調整できます。</sub>
    </td>
  </tr>
</table>

<br/>

---

### 💡 使用例

**シナリオ：英語で行われる授業**

```text
教授:
"Now let's discuss the vanishing gradient problem."

画面上の字幕:
原文: Now let's discuss the vanishing gradient problem.
翻訳: 勾配消失問題について見ていきましょう。

学生の質問:
「勾配消失ってなんですか？」

AIの回答:
勾配消失問題とは、ニューラルネットワークが深くなるにつれて
学習信号が前の層にうまく伝わらなくなり、
学習が困難になる現象のことです。
```

<br>

## 🔄 どうやって動くの？

> **マイクが教授の声を拾う → AIがテキストに変換 → あなたの画面に表示される**

もう少し詳しく説明すると：

```
1️⃣  教授が話す
        ↓
2️⃣  AIが音声を聞いてテキストに変換する
   （外国語の場合は自動的に翻訳）
        ↓
3️⃣  リアルタイムで字幕として画面に表示される
        ↓
4️⃣  わからないことがあれば → AIに質問！
    講義の流れを見失ったら  → 要約ボタンをクリック！
```

<br/>

## 🚀 はじめに

> ターミナルウィンドウを3つ開いてから始めましょう！

---

### STEP 0. 事前インストール _(初回のみ)_

| プログラム | ダウンロード |
|---------|---------|
| Python 3.12 | https://www.python.org/downloads/ |
| Flutter 3.x | https://docs.flutter.dev/get-started/install |
| Ollama | https://ollama.com/ |
| Google Chrome | https://www.google.com/chrome/ |
| Supabaseアカウント | https://supabase.com/ |

---

### STEP 1. リポジトリのクローン

```bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter
```

---

### STEP 2. バックエンドのセットアップ _(初回のみ)_

```bash
python3 -m venv pikmin
source pikmin/bin/activate        # Windows: pikmin\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # .envファイルを開いて以下の値を入力
```

```env
SUPABASE_URL=ここに入力
SUPABASE_ANON_KEY=ここに入力
LLM_MODEL=gemma2:2b
VLM_MODEL=llama3.2-vision:11b
WHISPER_MODEL_SIZE=medium
WHISPER_DEVICE=auto
VAD_THRESHOLD=0.3
```

> 💡 URLとKEYはSupabaseダッシュボード → Project Settings → APIで確認できます

---

### STEP 3. フロントエンドのセットアップ _(初回のみ)_

```bash
cd Frontend && flutter pub get && cd ..
```

---

### STEP 4. 起動する

**ターミナル 1** — AIサーバー
```bash
ollama serve
```

**ターミナル 2** — バックエンド
```bash
source pikmin/bin/activate
cd App && uvicorn main:app --reload
```

**ターミナル 3** — フロントエンド
```bash
cd Frontend
flutter run -d chrome \
  --web-port=9998 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=ここに入力 \
  --dart-define=SUPABASE_ANON_KEY=ここに入力 \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Japanese
```

---

### STEP 5. Chrome拡張機能のインストール

1. Chromeのアドレスバーに `chrome://extensions` と入力
2. 右上の**デベロッパーモード**をオンにする
3. **パッケージ化されていない拡張機能を読み込む**をクリック → `Extension/` フォルダを選択
4. 🧩 アイコンをクリック → Lecture Hunterをピン留め
5. 講義タブでアイコンをクリック → ウィジェットを起動

---

### ✅ 動作確認

| 確認項目 | URL |
|---------|------|
| バックエンド | http://127.0.0.1:8000 |
| フロントエンド | http://127.0.0.1:9998 |
| 拡張機能 | 講義タブ上にウィジェットが表示されているか確認 |

<br>

---

## 📊 現在の開発状況

| 機能 | 状態 |
|------|------|
| 質問API連携 | ✅ 完了 |
| 質問履歴のリセット | ✅ 完了 |
| 用語集API連携 | ✅ 完了 |
| リアルタイム字幕受信 | ✅ 完了 |
| 手動字幕表示テスト | ✅ 完了 |
| 音声WebSocket接続 | ✅ 完了 |
| マイク音声のリアルタイム文字起こし | ✅ 完了 |
| 重要ポイント要約機能 | ✅ 完了 |
| スライド画像分析 | ✅ 完了 |
| 複数ユーザー同時使用テスト | ⏳ 予定 |

---

## 🧭 使い方

Flutterの画面が起動すると、講義画面の上に学習サポートウィジェットが表示されます。
各ボタンを押すだけですぐに使えます！

| 機能 | 使い方 |
|------|-----------------|
| 字幕を見る | 原文と翻訳が画面下部に自動的に表示されます。そのまま見るだけでOK！ |
| 質問する | 質問パネルを開いて気になることを入力するとAIが答えてくれます |
| 新しい質問を始める | 以前の質問内容を消して新しく始めたいときに押します |
| 用語を検索する | 用語集タブでわからない単語を検索して確認できます |
| 字幕履歴 | 見逃した過去の字幕を確認できます |
| ライブサーバーモード | 実際の講義に接続して使うときはこのモードに切り替えます |

<br/>

---

## 🛠 技術スタック

| 領域 | 使用技術 | 採用理由 |
|------|-----------|---------------|
| 画面 | Flutter | 字幕・質問・用語集の画面を構築するために使用 |
| サーバー | FastAPI | AIと画面の通信チャネルを作るために使用 |
| AIモデル実行 | Ollama | インターネットなしでローカルにAIを動かすために使用 |
| 音声認識 | Faster-Whisper | 教授の声をテキストに変換するために使用 |
| 音声区間検出 | Silero VAD | 発話区間だけを検出・抽出するために使用 |
| データ保存 | Supabase | 講義内容と字幕データを保存するために使用 |
| リアルタイム配信 | Supabase Realtime | 字幕を画面にリアルタイムで送信するために使用 |
| 音声転送 | WebSocket | マイク音声をサーバーに送信するために使用 |

<br/>

---

## 📁 プロジェクト構成

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

### 参考資料

- Flutter公式ドキュメント: https://docs.flutter.dev/
- FastAPI公式ドキュメント: https://fastapi.tiangolo.com/
- Supabase公式ドキュメント: https://supabase.com/docs
- Ollama公式ドキュメント: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 講義がもう少し楽になるその日まで</sub>
</p>