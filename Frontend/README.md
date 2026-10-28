<p align="center">
  <img width="100%" src="https://capsule-render.vercel.app/api?type=speech&height=180&color=gradient&text=Frontend&fontAlignY=40&fontAlign=50&animation=twinkling&desc=과제헌터_LiveLectureAI&descAlignY=60&descAlign=55" />
</p>

<p align="center">
  <img alt="Status" src="https://img.shields.io/badge/status-개발중-orange?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-상태관리-0099E5?style=flat-square" />
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-Realtime-3FCF8E?style=flat-square&logo=supabase&logoColor=white" />
  <img alt="WebSocket" src="https://img.shields.io/badge/WebSocket-오디오전송-7B61FF?style=flat-square" />
</p>

<p align="center">
  <b>Frontend</b><br/>
  <b>강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발</b>
</p>

> [!IMPORTANT]
> 이 저장소의 `Frontend` 폴더는 **LiveLectureAI의 학생용 Flutter 프론트엔드 위젯 앱**을 다룹니다.  
> 백엔드 서버, STT/LLM 모델, 데이터베이스 구성은 `App` 폴더 또는 백엔드 문서를 참고해 주세요.

---

### 📺 프론트엔드가 하는 일

강의 화면 위에 아래 기능을 띄워주는 앱이에요.

- 실시간 자막 / 번역 자막 표시
- AI 질문 및 히스토리 초기화
- 강의 용어집 검색
- 자막 히스토리 확인
- 자막 크기·위치·투명도·테마 설정

---

### ✨ 기능 현황

| 기능 | 상태 |
|------|------|
| 실시간 자막 오버레이 | ✅ 완료 |
| 번역 자막 표시 | ✅ 완료 |
| AI 질문 | ✅ 완료 |
| 질문 히스토리 초기화 | ✅ 완료 |
| 용어집 조회 | ✅ 완료 |
| 자막 설정 | ✅ 완료 |
| 자막 히스토리 | ✅ 완료 |
| Supabase Realtime 수신 | ✅ 완료 |
| 오디오 WebSocket 연결 | ✅ 완료 |

---

### 🖼 화면 미리보기

<table align="center">
  <tr>
    <th align="center">🎙 실시간 자막 및 번역</th>
    <th align="center">💬 강의 AI 질문</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/real-time captions.png" width="360"/>
      <br/>
      <sub>수신된 자막의 원문과 한국어 번역을 함께 볼 수 있어요.</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/question_input.png" width="360"/><br/>
      <sub>강의 내용을 바탕으로 AI에게 질문할 수 있어요.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">📚 용어집 조회</th>
    <th align="center">📝 핵심 요약</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/glossary_tab.png" width="360"/><br/>
      <sub>저장된 강의 용어를 검색해서 확인할 수 있어요.</sub>
    </td>
    <td align="center">
      <img src="../assets/screens/key_summary_features.png" width="360"/><br/>
      <sub>강의 내용을 짧게 요약해줘요.</sub>
    </td>
  </tr>

  <tr>
    <th align="center">⚙️ 설정</th>
  </tr>
  <tr>
    <td align="center">
      <img src="../assets/screens/caption_settings.png" width="360"/><br/>
      <sub>자막 크기, 위치, 투명도, 테마를 조절할 수 있어요.</sub>
    </td>
  </tr>
</table>


---

### 🚀 시작하는 방법

**사전 준비** _(딱 한 번만)_

| 필요한 것 | 받는 곳 |
|---------|---------|
| Flutter 3.x | https://docs.flutter.dev/get-started/install |
| Chrome 브라우저 | https://www.google.com/chrome/ |

**설치 및 실행**

```bash
# 1. 프로젝트 받기
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter/Frontend

# 2. 패키지 설치 (부품 자동으로 내려받기)
flutter pub get

# 3. 실행 — 아래에서 "여기에_입력" 부분만 본인 값으로 바꾸세요
flutter run -d chrome \
  --web-port=9998 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=여기에_입력 \
  --dart-define=SUPABASE_ANON_KEY=여기에_입력 \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

> 💡 `SUPABASE_URL`과 `SUPABASE_ANON_KEY`는
> [Supabase 사이트](https://supabase.com/dashboard) → 내 프로젝트
> → **Project Settings → API** 에서 복사해요.

Chrome이 자동으로 열리고 위젯 화면이 보이면 **성공!** 🎉

---

### 🔧 환경 변수

설정 파일: `lib/core/config/app_config.dart`

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `API_BASE_URL` | 백엔드 REST API 주소 | `http://127.0.0.1:8000` |
| `WS_BASE_URL` | 백엔드 WebSocket 주소 | `ws://127.0.0.1:8000` |
| `SUPABASE_URL` | Supabase 프로젝트 URL | `your_supabase_url` |
| `SUPABASE_ANON_KEY` | 브라우저용 Supabase key | `your_anon_key` |
| `LECTURE_ID` | 현재 강의 ID | `demo-lecture` |
| `TARGET_LANG` | 번역 목표 언어 | `Korean` |

> [!IMPORTANT]
> `service_role` 키는 프론트에 절대 사용 금지. anon public key만 사용.

---

### 📁 프로젝트 구조

```text
Frontend/
├── web/
├── assets/
├── lib/
│   ├── main.dart
│   ├── core/
│   ├── features/
│   └── services/
├── docs/
├── pubspec.yaml
└── README.md
```

---

<details>
<summary>🧪 개발 명령어</summary>

**패키지 설치**
```bash
flutter pub get
```

**코드 정리**
```bash
dart format .
```

**정적 분석**
```bash
flutter analyze
```

**Web 실행**
```bash
flutter run -d chrome
```

**Web 빌드**
```bash
flutter build web
```

</details>

---

<details>
<summary>🧩 테스트 방법</summary>

**API 엔드포인트**

| 기능 | 엔드포인트 |
|------|-----------|
| 질문 | `GET /lecture/ask?lecture_id=&question=&target_lang=` |
| 히스토리 초기화 | `POST /lecture/ask/reset?lecture_id=` |
| 용어집 | `GET /lecture/glossary/{lecture_id}?keyword=` |
| 오디오 WebSocket | `ws://127.0.0.1:8000/ws/audio/{lecture_id}?target_lang=Korean` |

**Realtime 자막 수신**

```text
channel : lecture_demo-lecture
event   : new_caption
```

</details>

---

<p align="center">
  <sub>🎓 강의가 조금 더 쉬워지는 그날까지</sub>
</p>
