<p align="center">
  <img src="../assets/LectureHunter_Logo3.jpeg" alt="Lecture Hunter Logo" width="100%" />
</p>

<p align="center">
  <a href="#-快速开始">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white" alt="Quick Start" />
  </a>
  <a href="#-使用示例">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white" alt="Demo" />
  </a>
  <br/>
  <img alt="Status" src="https://img.shields.io/badge/status-开发中-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>基于Flutter的实时字幕·问答小组件开发（面向课堂互动）</b>
</p>

<p align="center">
  <a href="../README.md">🇰🇷 한국어</a> &nbsp;·&nbsp;
  <a href="README.en.md">🇺🇸 English</a> &nbsp;·&nbsp;
  <a href="README.jp.md">🇯🇵 日本語</a> &nbsp;·&nbsp;
</p>

> [!NOTE]
> 东亚大学AI学系SW核心大学事业现场镜像型关联项目
> 👩🏻‍🎓👨🏻‍🎓👨🏻‍🎓 **과제헌터**

---

### 📺 这个项目是什么？

看过电视字幕吗？

**这是一个在课程画面上显示实时字幕的AI程序。**

教授说话的瞬间，立即以文字形式显示在屏幕上。
外语课程也会**翻译成韩语**显示，
如果有不懂的地方还可以**搜索**。
如果错过了课程，还可以**总结"到目前为止讲了什么"**。

> 💡 **TIP**
> 当你不敢举手提问时特别有用。你可以悄悄地只向AI提问！ 🙈

---

### 📚 目录

* [适用场景](#-适用场景)
* [主要功能预览](#-主要功能预览)
* [使用示例](#-使用示例)
* [如何运行？](#-如何运行)
* [快速开始](#-快速开始)
* [当前开发状况](#-当前开发状况)
* [使用方法](#-使用方法)
* [技术栈](#-技术栈)
* [项目结构](#-项目结构)
* [参考资料](#参考资料)

---

### 🙋 适用场景

| 如果遇到这种情况...                                    | 这样帮助你                                       |
| ------------------------------------------------------ | ------------------------------------------------ |
| 「全英文授课，完全听不懂...」                           | 韩语翻译字幕帮助理解。                           |
| 「教授说话太快了...」                                   | 可以通过字幕重新确认漏听的内容。                 |
| 「晚到10分钟，现在在讲什么？...」                       | 可以通过向AI提问确认课程进度。                   |
| 「想提问但不好意思举手...」                             | 可以悄悄向AI提问。                               |
| 「出现了难懂的词，想再确认一下...」                     | 可以搜索已保存的讲座词汇进行确认。               |
| 「想再看看刚才的字幕...」                               | 可以在字幕历史中确认之前的字幕。                 |

---

### 🖼 主要功能预览

<table align="center">
  <tr>
    <th align="center">🎙 实时字幕及翻译</th>
    <th align="center">⚙️ 设置</th>
  </tr>
  <tr>
    <td align="center">
      准备中
      <br/>
      <sub>可以同时查看接收到的字幕原文和韩语翻译。</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/caption_settings.png" width="360"/><br/>
      <sub>可以调整字幕大小、位置、透明度和主题。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">💬 讲座AI问答</th>
    <th align="center">📚 词汇表查询</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/question_input.png" width="360"/><br/>
      <sub>可以根据讲座内容向AI提问。</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>可以搜索已保存的讲座词汇进行确认。</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📜 查看历史字幕</th>
    <th align="center">📝 核心摘要</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/caption_history.png" width="360"/><br/>
      <sub>可以再次确认过去的字幕。</sub>
    </td>
    <td align="center">
      准备中<br/>
      <sub>对讲座内容进行简短总结。</sub>
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
翻译: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.

学生提问:
「梯度消失是什么？」

AI回答:
梯度消失是指随着神经网络层数加深，学习信号越来越难以传递到前面的层，
从而导致训练困难的现象。
```

<br>

## 🔄 如何运行？

> **麦克风听取教授的声音 → AI转换成文字 → 显示在屏幕上**

更详细地说：

```
1️⃣  教授说话
        ↓
2️⃣  AI听取声音并转换成文字
   （英语则自动翻译成韩语）
        ↓
3️⃣  以字幕形式显示在屏幕上
        ↓
4️⃣  有不懂的地方？  → 向AI提问！
    错过课程进度了？  → 点击摘要按钮！
```

<br/>

## 🚀 快速开始

| 项目             | 版本         |
|------------------|-------------|
| Python           | 3.12        |
| Flutter          | 3.x         |
| Ollama           | 最新版本     |
| Supabase账户     | -           |

**安装**

```bash
# 1. 获取项目
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# 2. 后端准备
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt

# 3. 环境配置（创建.env文件后输入以下内容）
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
# 4. 前端准备
cd Frontend
flutter pub get
cd ..
```

**运行 → 请打开3个终端窗口**

```bash
# 终端1: 启动AI模型服务器
ollama serve

# 终端2: 启动后端服务器
cd ~/Downloads/Lecture-Hunter
source pikmin/bin/activate
cd App
uvicorn main:app --reload

# 终端3: 运行前端界面
cd Frontend
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

**确认是否正常运行**
- 在地址栏打开 `http://127.0.0.1:8000`，若收到响应则 **OK**
- Chrome中出现字幕界面则 **OK**
- 字幕、提问、词汇表按钮可见则 **OK**

<br>

---

## 📊 当前开发状况

| 功能                         | 状态         |
|------------------------------|--------------|
| 问答API集成                  | ✅ 完成      |
| 问题历史重置                 | ✅ 完成      |
| 词汇表API集成                | ✅ 完成      |
| 实时字幕接收                 | ✅ 完成      |
| 手动字幕显示测试             | ✅ 完成      |
| 音频WebSocket连接            | ✅ 完成      |
| 实际麦克风语音字幕转换       | ⏳ 计划中    |
| 核心摘要功能                 | 🔄 进行中    |
| 幻灯片图像分析               | 🔄 进行中    |
| 多人同时使用测试             | ⏳ 计划中    |

### 🧪 剩余核心任务

| 任务                           | 状态   |
|--------------------------------|--------|
| 实际麦克风输入                  | 计划中 |
| 麦克风音频传输至后端            | 计划中 |
| 语音字幕转换                    | 计划中 |
| 转换字幕实时显示                | 计划中 |
| 基于实际语音的全流程测试        | 计划中 |

---

## 🧭 使用方法

Flutter界面启动后，讲座画面上方会出现学习助手小组件。
逐一点击按钮即可立即使用！

| 功能           | 使用方法                                                                  |
|----------------|---------------------------------------------------------------------------|
| 查看字幕       | 屏幕下方同时显示原文和翻译。直接查看即可！                               |
| 提问           | 打开问题面板，输入想知道的内容，AI会回答                                 |
| 开始新提问     | 想清除之前的问题重新开始时点击                                           |
| 词汇搜索       | 在词汇表标签页搜索不认识的单词进行确认                                   |
| 字幕历史       | 想再次查看过去字幕时确认                                                 |
| 连接实际服务器 | 与实际讲座连接使用时切换到此模式                                         |

<br/>

---

## 🛠 技术栈

| 领域           | 使用技术           | 使用原因                                               |
|----------------|--------------------|--------------------------------------------------------|
| 界面           | Flutter            | 用于制作字幕、问答、词汇表界面                         |
| 服务器         | FastAPI            | 用于创建AI和界面互相通信的通道                         |
| AI模型运行     | Ollama             | 用于在本地计算机上无需互联网运行AI                     |
| 语音识别       | Faster-Whisper     | 用于将教授的声音转换为文字                             |
| 语音段检测     | Silero VAD         | 用于只检测说话的区间                                   |
| 数据存储       | Supabase           | 用于存储讲座内容和字幕数据                             |
| 实时传输       | Supabase Realtime  | 用于实时将字幕发送到界面                               |
| 音频连接       | WebSocket          | 用于将麦克风声音发送到服务器                           |

<br/>

---

## 📁 项目结构

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

### 参考资料

- Flutter官方文档: https://docs.flutter.dev/
- FastAPI官方文档: https://fastapi.tiangolo.com/
- Supabase官方文档: https://supabase.com/docs
- Ollama官方文档: https://ollama.com/
- Faster-Whisper GitHub: https://github.com/SYSTRAN/faster-whisper

---

<p align="center">
  <sub>🎓 直到课程变得更轻松的那一天</sub>
</p>
