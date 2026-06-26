<p align="center">
  <img src="./assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>

<p align="center">
  <a href="#-快速开始">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
  </a>
  <a href="#-使用示例">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
  </a>
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/状态-开发中-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>基于 Flutter 的实时字幕与问答交互讲义小部件</b>
</p>

<p align="center">
  <a href="README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  <a href="README.en.md">🇺🇸 English</a> &nbsp;·&nbsp;
  <a href="README.jp.md">🇯🇵 日本語</a> &nbsp;·&nbsp;
  🇨🇳 简体中文
</p>

> [!NOTE]
> 东亚大学 AI 学科 SW 核心大学项目 现场镜像联合项目
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **团队：作业猎人**

---

### 📺 这是什么项目？

看过电视字幕吧？

**这是一个能在讲义画面上实时显示字幕的 AI 程序。**

教授一开口，文字就立刻出现在屏幕上。
外语讲义还能**自动翻译成中文**，
遇到不懂的地方可以随时**搜索**，
如果错过了部分内容，还能**总结目前讲了什么**。

> 💡 **提示**
> 不好意思举手提问时尤其好用 —— 可以悄悄问 AI，没人会知道！ 🙈

---

### 📚 目录

* [适用场景](#-适用场景)
* [主要功能](#-主要功能)
* [使用示例](#-使用示例)
* [工作原理](#-工作原理)
* [快速开始](#-快速开始)
* [当前开发状态](#-当前开发状态)
* [使用方法](#-使用方法)
* [技术栈](#-技术栈)
* [项目结构](#-项目结构)
* [参考资料](#参考资料)

---

### 🙋 适用场景

| 遇到这种情况时…                          | 这样来帮你                              |
| ------------------------------------ | --------------------------------------------- |
| "这节课是英语，完全听不懂……"            | 实时翻译字幕帮助你理解内容。                   |
| "教授讲得太快了，跟不上……"              | 可以通过字幕回顾错过的内容。                   |
| "迟到了10分钟，现在讲到哪了？"           | 通过 AI 问答快速跟上讲义进度。                 |
| "想提问但不好意思举手……"               | 可以悄悄向 AI 提问，没人会发现。               |
| "出现了难懂的术语，想再查一下……"         | 在词汇表中搜索已保存的讲义术语。               |

---

### 🖼 主要功能

<table align="center">
  <tr>
    <th align="center">🎙 实时字幕与翻译</th>
    <th align="center">💬 讲义 AI 问答</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/real-time captions.png" width="360"/>
      <br/>
      <sub>同时显示字幕原文与中文翻译。</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/question_input.png" width="360"/><br/>
      <sub>可根据讲义内容向 AI 提问。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📚 词汇表查询</th>
    <th align="center">📝 要点总结</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>搜索并查看已保存的讲义术语。</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/key_summary_features.png" width="360"/><br/>
      <sub>对讲义内容进行简洁摘要。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">⚙️ 设置</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/caption_settings.png" width="360"/><br/>
      <sub>可调整字幕大小、位置、透明度和主题。</sub>
    </td>
  </tr>
</table>

<br/>

---

### 💡 使用示例

**场景：全英文授课**

```text
教授:
"Now let's discuss the vanishing gradient problem."

屏幕字幕:
原文: Now let's discuss the vanishing gradient problem.
翻译: 现在我们来讨论梯度消失问题。

学生提问:
"梯度消失是什么？"

AI 回答:
梯度消失问题是指随着神经网络层数加深，
训练信号难以有效传递到前面的层，
从而导致模型学习越来越困难的现象。
```

<br>

## 🔄 工作原理

> **麦克风采集教授声音 → AI 转换为文字 → 显示在你的屏幕上**

详细步骤如下：

```
1️⃣  教授开口说话
        ↓
2️⃣  AI 监听并将语音转换为文字
   （外语授课时自动翻译）
        ↓
3️⃣  实时以字幕形式显示在屏幕上
        ↓
4️⃣  有不懂的地方？ → 向 AI 提问！
    跟不上讲义进度？ → 点击总结按钮！
```

<br/>

## 🚀 快速开始

> 请先打开 3 个终端窗口再开始！

---

### STEP 0. 预先安装 _(仅需一次)_

| 程序 | 下载地址 |
|---------|---------|
| Python 3.12 | https://www.python.org/downloads/ |
| Flutter 3.x | https://docs.flutter.dev/get-started/install |
| Ollama | https://ollama.com/ |
| Google Chrome | https://www.google.com/chrome/ |
| Supabase 账号 | https://supabase.com/ |

---

### STEP 1. 克隆仓库

```bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter
```

---

### STEP 2. 配置后端 _(仅需一次)_

```bash
python3 -m venv pikmin
source pikmin/bin/activate        # Windows: pikmin\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # 打开 .env 文件并填写以下值
```

```env
SUPABASE_URL=在此输入
SUPABASE_ANON_KEY=在此输入
LLM_MODEL=gemma2:2b
VLM_MODEL=llama3.2-vision:11b
WHISPER_MODEL_SIZE=medium
WHISPER_DEVICE=auto
VAD_THRESHOLD=0.3
```

> 💡 URL 和 KEY 可在 Supabase 控制台 → Project Settings → API 中找到

---

### STEP 3. 配置前端 _(仅需一次)_

```bash
cd Frontend && flutter pub get && cd ..
```

---

### STEP 4. 启动应用

**终端 1** — AI 服务器
```bash
ollama serve
```

**终端 2** — 后端
```bash
source pikmin/bin/activate
cd App && uvicorn main:app --reload
```

**终端 3** — 前端
```bash
cd Frontend
flutter run -d chrome \
  --web-port=9998 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=在此输入 \
  --dart-define=SUPABASE_ANON_KEY=在此输入 \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Chinese
```

---

### STEP 5. 安装 Chrome 扩展程序

1. 在 Chrome 地址栏输入 `chrome://extensions`
2. 开启右上角的**开发者模式**
3. 点击**加载已解压的扩展程序** → 选择 `Extension/` 文件夹
4. 点击 🧩 图标 → 固定 Lecture Hunter
5. 在讲义标签页点击图标 → 启动小部件

---

### ✅ 确认运行状态

| 确认项目 | 地址 |
|---------|------|
| 后端 | http://127.0.0.1:8000 |
| 前端 | http://127.0.0.1:9998 |
| 扩展程序 | 确认讲义标签页上是否出现小部件 |

<br>

---

## 📊 当前开发状态

| 功能 | 状态 |
|------|------|
| 问答 API 集成 | ✅ 完成 |
| 提问历史重置 | ✅ 完成 |
| 词汇表 API 集成 | ✅ 完成 |
| 实时字幕接收 | ✅ 完成 |
| 手动字幕显示测试 | ✅ 完成 |
| 音频 WebSocket 连接 | ✅ 完成 |
| 麦克风语音实时转文字 | ✅ 完成 |
| 要点总结功能 | ✅ 完成 |
| 幻灯片图像分析 | ✅ 完成 |
| 多用户并发测试 | ⏳ 计划中 |

---

## 🧭 使用方法

Flutter 界面启动后，讲义画面上方会出现学习助手小部件。
点击各个按钮即可立即上手！

| 功能 | 使用方式 |
|------|-----------------|
| 查看字幕 | 原文和翻译会自动显示在屏幕底部，直接看就好！ |
| 提问 | 打开提问面板，输入疑问，AI 会给出解答 |
| 开始新提问 | 想清除上一次对话、重新开始时点击此按钮 |
| 搜索术语 | 在词汇表标签页中搜索不认识的词语 |
| 字幕历史 | 查看之前错过的字幕 |
| 实时服务器模式 | 连接真实讲义时切换到此模式 |

<br/>

---

## 🛠 技术栈

| 领域 | 技术 | 采用原因 |
|------|-----------|---------------|
| 界面 | Flutter | 用于构建字幕、问答和词汇表界面 |
| 服务器 | FastAPI | 用于创建 AI 与界面之间的通信通道 |
| AI 模型运行 | Ollama | 用于在本地无网络环境下运行 AI 模型 |
| 语音识别 | Faster-Whisper | 用于将教授的声音转换为文字 |
| 语音活动检测 | Silero VAD | 用于检测并提取发言片段 |
| 数据存储 | Supabase | 用于存储讲义内容和字幕数据 |
| 实时推送 | Supabase Realtime | 用于将字幕实时推送到屏幕 |
| 音频传输 | WebSocket | 用于将麦克风音频发送到服务器 |

<br/>

---

## 📁 项目结构

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

### 参考资料

- Flutter 官方文档: https://docs.flutter.dev/
- FastAPI 官方文档: https://fastapi.tiangolo.com/
- Supabase 官方文档: https://supabase.com/docs
- Ollama 官方文档: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 直到听课变得轻松一点点的那一天</sub>
</p>