![LiveLectureLogo](./assets/LiveLectureLogo2.png)
![header](https://capsule-render.vercel.app/api?type=waving&height=250&color=gradient&text=Lecture%20Hunter&descAlign=59&textBg=false&descAlignY=51&fontAlignY=35&animation=fadeIn&desc=강의를%20더%20잘%20따라가게%20도와주는%20AI%20학습%20도우미&descSize=22&fontSize=78)

<p align="center">    
  <a href="#-시작하기">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white"/>
  </a>
  <a href="#-사용-예시">
    <img src="https://img.shields.io/badge/DEMO-5C86FA?style=for-the-badge&logoColor=white"/>
  </a>
  <br/><br/>
  <img alt="Status" src="https://img.shields.io/badge/status-개발중-orange?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
</p>

<p align="center">
  <b>🇰🇷 한국어</b>
  ·
  <a href="docs/README_en.md">🇺🇸 English</a>
  ·
  <a href="docs/README_jp.md">🇯🇵 日本語</a>
</p>

<br/>

> [!TIP]
> 처음 오셨나요? **[이런 적 있으세요?](#-이런-적-있으세요)** 섹션부터 읽어보시면 빠르게 감이 잡혀요.

> [!IMPORTANT]
> 현재 개발 중인 프로젝트입니다. 기능별 진행 상황은 [진행 상황](#-진행-상황) 섹션에서 확인하실 수 있어요.

<br/>

## 🧭 Navigation

1. [이런 적 있으세요?](#-이런-적-있으세요)
2. [LiveLectureAI가 해주는 일](#-livelectureai가-해주는-일)
3. [어떻게 생겼나요?](#-어떻게-생겼나요)
4. [사용 예시](#-사용-예시)
5. [기술 스택](#-기술-스택)
6. [시작하기](#-시작하기)
7. [진행 상황](#-진행-상황)
8. [팀](#-팀)

<br/>

## 🤔 이런 적 있으세요?

> *"영어 강의인데 한 단어 놓치니까 그 뒤로 다 못 알아듣겠어…"*  
> *"수업 중에 모르는 용어가 나왔는데, 손 들고 물어보기는 좀 부담스러워…"*  
> *"10분 늦게 들어왔는데, 지금 무슨 얘기 하는지 모르겠어…"*  
> *"복습할 때 1시간짜리 강의를 다시 듣기는 너무 길어…"*

**이런 순간들을 위한 학습 도우미입니다.**

<br/>

## ✨ LiveLectureAI가 해주는 일

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>1️⃣ 실시간 자막</h3>
      교수님이 말하는 걸 AI가 받아 적어서 화면에 띄워줍니다. <b>외국어 강의는 한국어로 번역</b>해서 같이 보여줘요.
    </td>
    <td width="50%" valign="top">
      <h3>2️⃣ 슬라이드까지 이해하는 AI</h3>
      화면에 떠 있는 <b>슬라이드 속 도표·수식·그림</b>까지 AI가 함께 봐요. 그래서 강의 맥락을 통째로 이해합니다.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>3️⃣ 강의 중 바로 질문</h3>
      모르는 게 나오면 위젯에 질문하세요. 지금까지의 강의 내용을 기억해서 <b>"방금 그게 무슨 뜻이에요?"</b> 같은 질문도 가능해요.
    </td>
    <td width="50%" valign="top">
      <h3>4️⃣ 5~10분 단위 핵심 요약</h3>
      흐름을 놓쳤을 때, 최근 강의 내용을 짧게 정리해줍니다. <b>늦게 들어오거나 복습할 때</b> 특히 유용해요.
    </td>
  </tr>
  <tr>
    <td colspan="2" valign="top">
      <h3>5️⃣ 자동 용어집</h3>
      수업에 나온 어려운 용어들을 자동으로 정리해주고, 모르는 단어가 나오면 바로 검색할 수 있어요.
    </td>
  </tr>
</table>

<br/>

## 🖼 어떻게 생겼나요?

> [!NOTE]
> 📸 데모 스크린샷·GIF는 곧 추가될 예정입니다!

<p align="center">
  <table>
    <tr>
      <th align="center">자막 오버레이</th>
      <th align="center">질문 패널</th>
      <th align="center">용어집</th>
    </tr>
    <tr>
      <td align="center"><i>(이미지 준비 중)</i></td>
      <td align="center"><i>(이미지 준비 중)</i></td>
      <td align="center"><i>(이미지 준비 중)</i></td>
    </tr>
  </table>
</p>

<br/>

## 💡 사용 예시

**상황:** 영어로 진행되는 머신러닝 강의 중

```
🎤 교수님: "Now let's discuss the vanishing gradient problem..."

📺 자막 화면:
   원문: Now let's discuss the vanishing gradient problem...
   번역: 이제 기울기 소실 문제에 대해 다뤄보겠습니다.

💬 학생 질문: "기울기 소실이 왜 문제인가요?"

🤖 AI 답변: "지금 보고 계신 슬라이드 7번 그래프처럼,
            신경망이 깊어질수록 학습이 잘 안 되는 현상입니다.
            (강의 15분 시점에서 다룬 내용 참고)"
```

<br/>

## 🛠 기술 스택

> [!NOTE]
> 일반 사용자분들은 이 섹션 건너뛰셔도 좋아요!

<details>
<summary><b>📦 클릭해서 펼치기</b></summary>

<br/>

**📱 앱 (Frontend)**

<img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white"/> <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white"/> <img src="https://img.shields.io/badge/Riverpod-0099E5?style=flat-square"/>

- Flutter — 모바일·데스크탑 앱
- Riverpod — 상태 관리
- WebSocket / SSE — 실시간 통신

**⚙️ 서버 (Backend)**

<img src="https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white"/> <img src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white"/> <img src="https://img.shields.io/badge/PyTorch-EE4C2C?style=flat-square&logo=pytorch&logoColor=white"/>

- Python 3.12 + FastAPI — API 서버
- Faster-Whisper — 음성 → 텍스트 변환
- Llama 3.2 Vision — 슬라이드 이미지 분석
- Gemma 2 — 다국어 번역
- Silero VAD — 음성 구간 감지

**🗄 데이터베이스**

<img src="https://img.shields.io/badge/Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white"/> <img src="https://img.shields.io/badge/PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white"/>

- Supabase (PostgreSQL + pgvector) — 강의 데이터 저장·검색

</details>

<br/>

## 🚀 시작하기

### 필요한 환경

- macOS (Apple Silicon M1/M2/M3) 또는 NVIDIA GPU 탑재 PC
- Python 3.12
- Flutter 3.x
- 메모리 16GB 이상 권장

### 설치

```bash
# 1. 프로젝트 받기
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter

# 2. Python 환경 설정
python3 -m venv pikmin
source pikmin/bin/activate
pip install -r requirements.txt

# 3. 환경변수 설정
cp .env.example .env
# .env 파일에 Supabase 정보 입력
```

### 실행

```bash
# 로컬 AI 서버 시작
ollama serve

# 백엔드 서버 시작
uvicorn App.main:app --reload

# Flutter 앱 실행 (별도 터미널)
cd flutter_app && flutter run
```

<br/>

## 📊 진행 상황

### ✅ 완성된 것

- [x] 음성 → 자막 변환 (Whisper)
- [x] 슬라이드 이미지 분석 (Llama Vision)
- [x] 강의 내용 기반 AI 답변 (RAG)
- [x] 실시간 통신 구조 (WebSocket)
- [x] 다국어 번역 엔진 (Gemma 2)

### 🚧 작업 중

- [ ] Flutter 앱 UI 마무리
- [ ] 자동 강의 요약 기능
- [ ] 다중 사용자 동시 접속 안정성 테스트
- [ ] 학습 참여도 분석 대시보드

<br/>

## 👥 팀

<p align="center">
  <b>과제헌터</b>
</p>

<br/>

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:667EEA,100:764BA2&height=120&section=footer&text=Made%20with%20💜&fontSize=24&fontColor=ffffff&fontAlignY=70" />
</p>
