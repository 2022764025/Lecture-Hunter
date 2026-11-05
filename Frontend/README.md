<p align="center">
  <img width="100%" src="https://capsule-render.vercel.app/api?type=speech&height=180&color=gradient&text=Frontend&fontAlignY=40&fontAlign=50&animation=twinkling&desc=과제헌터_LiveLectureAI&descAlignY=60&descAlign=55" />
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-상태관리-0099E5?style=flat-square" />
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-Realtime-3FCF8E?style=flat-square&logo=supabase&logoColor=white" />
  <img alt="WebSocket" src="https://img.shields.io/badge/WebSocket-오디오전송-7B61FF?style=flat-square" />
</p>

<p align="center">
  <b>과제헌터 (Lecture Hunter) | Frontend</b><br/>
  <b>강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯 개발</b>
</p>

> [!IMPORTANT]
> 이 문서는 과제헌터의 **학생용 Flutter 프론트엔드**를 소개합니다.  
> 음성 인식, AI 처리, 데이터베이스 등 백엔드 구성은 프로젝트 루트의 문서와 `App` 폴더를 참고해 주세요.

---

### 📺 프론트엔드가 하는 일

우리는 **강의 상호작용을 위한 Flutter 기반 실시간 자막·질문 위젯**을 개발했어요.

**Flutter는 하나의 코드로 여러 환경에서 사용할 수 있는 프로그램**을 만드는 도구예요. 우리는 이를 활용해 강의 화면 위에서 자막을 확인하고 궁금한 내용을 질문할 수 있는 프로그램을 만들었어요.

**프론트엔드는 사용자가 직접 보고 조작하는 화면을 만드는 부분**이에요. 강의 중 다른 화면으로 이동하지 않고 자막, 질문, 공지, 요약 기능을 이용할 수 있도록 구성했어요.

---

### ✨ 주요 기능
| 화면 | 기능 |
|------|------|
| 🎙 실시간 자막 | 강의 원문과 번역 자막을 표시하고 영어, 한국어, 중국어 중 언어를 선택할 수 있어요. |
| 💬 질문 | 궁금한 내용을 익명으로 질문하고, 화면 캡처 이미지를 첨부할 수 있어요. |
| 📚 용어집 조회 | 질문 탭에서 용어를 검색하고 설명을 확인할 수 있어요. |
| 📢 공지 | 강의 공지, 강의 자료, 과제 설명과 제출 방법을 확인할 수 있어요. |
| 📝 요약 | 최근 5분, 최근 10분 또는 직접 지정한 시간 구간의 강의 내용을 요약해 확인할 수 있어요. |
| ⚙️ 설정 | 위젯의 위치와 크기를 변경하고 너비, 높이, 글자 크기, 투명도를 조절할 수 있어요. |

---

### 🖼 화면 미리보기

<table align="center">
  <tr>
    <th align="center">🎙 실시간 자막 및 번역</th>
    <th align="center">💬 익명 질문</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/Captions.png" width="360" />
      <br />
      <sub>원문과 선택한 언어의 번역 자막을 확인해요.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/Questions.png" width="360" />
      <br />
      <sub>익명으로 질문하고 화면 이미지를 첨부할 수 있어요.</sub>
    </td>
  </tr>
  <tr>
    <th align="center">📚 용어집 조회 (질문 탭 내부)</th>
    <th align="center">📢 공지</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/Glossary.png" width="360" />
      <br />
      <sub>질문 탭에서 강의 용어를 검색해요.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/Notice.png" width="360" />
      <br />
      <sub>공지, 강의 자료, 과제 안내를 확인해요.</sub>
    </td>
  </tr>
  <tr>
    <th align="center">📝 구간 요약</th>
    <th align="center">⚙️ 설정</th>
  </tr>
  <tr>
    <td align="center">
      <img src="./assets/screens/Summary.png" width="360" />
      <br />
      <sub>원하는 강의 구간의 핵심 내용을 확인해요.</sub>
    </td>
    <td align="center">
      <img src="./assets/screens/Settings.png" width="360" />
      <br />
      <sub>위젯 크기, 글자 크기, 투명도를 조절해요.</sub>
    </td>
  </tr>
</table>

> 화면 이미지는 기존 README의 경로를 유지했어요. 실제 최종 UI와 다르다면 해당 이미지 파일을 최신 캡처로 교체해야 해요.

---

### 🛠 사용 기술

| 기술 | 프론트엔드에서 하는 일 |
|------|--------------------------|
| Flutter / Dart | 위젯 화면과 사용자 조작 기능 구현 |
| Riverpod | 탭 선택, 자막 표시, 위젯 설정 등 화면 상태 관리 |
| Supabase Realtime | 실시간 자막 데이터 수신 |
| WebSocket | 백엔드와 오디오 관련 실시간 통신 |
| REST API | 질문, 용어집 조회, 요약 등 백엔드 기능 연동 |
| Chrome | Flutter 웹 위젯 실행 |

---

### 🚀 시작하는 방법

**사전 준비**

| 필요한 것 | 설치 안내 |
|----------|-----------|
| Flutter 3.x | https://docs.flutter.dev/get-started/install |
| Chrome 브라우저 | https://www.google.com/chrome/ |
| 백엔드 서버 및 Supabase 설정 | 프로젝트 루트 README 참고 |

**설치 및 실행**

```bash
# 1. 프로젝트 받기
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter/Frontend

# 2. 패키지 설치
flutter pub get

# 3. Flutter 웹 실행
flutter run -d chrome \
  --web-hostname=127.0.0.1 \
  --web-port=9998 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=여기에_입력 \
  --dart-define=SUPABASE_ANON_KEY=여기에_입력 \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

`SUPABASE_URL`과 `SUPABASE_ANON_KEY`에는 본인 프로젝트의 설정값을 입력해 주세요. 실제 비밀키는 README에 적거나 GitHub에 올리지 마세요.

> [!IMPORTANT]
> `service_role` 키는 브라우저에서 실행되는 프론트엔드에 사용하면 안 돼요. 프론트엔드에는 공개용 anon 키만 사용하고, Supabase 접근 권한 정책도 별도로 설정해야 해요.

---

### 🔧 환경 변수

설정 코드: `lib/core/config/app_config.dart`

| 변수명 | 설명 | 예시 |
|--------|------|------|
| `API_BASE_URL` | 백엔드 API 주소 | `http://127.0.0.1:8000` |
| `WS_BASE_URL` | 백엔드 WebSocket 주소 | `ws://127.0.0.1:8000` |
| `SUPABASE_URL` | Supabase 프로젝트 URL | `여기에_입력` |
| `SUPABASE_ANON_KEY` | Supabase 공개용 anon 키 | `여기에_입력` |
| `LECTURE_ID` | 강의 식별값 | `demo-lecture` |
| `TARGET_LANG` | 기본 번역 언어 | `Korean` |

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

```bash
# 패키지 설치
flutter pub get

# 코드 정리
dart format .

# 정적 분석
flutter analyze

# 웹 실행
flutter run -d chrome

# 웹 빌드
flutter build web
```

</details>

---

<details>
<summary>🧩 프론트엔드 연동 참고</summary>

아래는 기존 프론트엔드 README에 기재된 연동 정보예요. 서버 버전에 따라 달라질 수 있으므로 실제 백엔드 API와 함께 확인해 주세요.

| 기능 | 엔드포인트 |
|------|-----------|
| 질문 | `GET /lecture/ask?lecture_id=&question=&target_lang=` |
| 질문 히스토리 초기화 | `POST /lecture/ask/reset?lecture_id=` |
| 용어집 | `GET /lecture/glossary/{lecture_id}?keyword=` |
| 오디오 WebSocket | `ws://127.0.0.1:8000/ws/audio/{lecture_id}?target_lang=Korean` |

**Realtime 자막 수신 예시**

```text
channel : lecture_demo-lecture
event   : new_caption
```

</details>

---

<p align="center">
  <sub>🎓 강의가 조금 더 쉬워지는 그날까지</sub>
</p>
