<p align="center">
  <img width="100%" src="https://capsule-render.vercel.app/api?type=speech&height=180&color=gradient&text=Frontend&fontAlignY=40&fontAlign=50&animation=twinkling&desc=과제헌터_LiveLectureAI&descAlignY=60&descAlign=55" />
</p>

<p align="center">
  <a href="#-시작하기">
    <img src="https://img.shields.io/badge/QUICK%20START-4FC08D?style=for-the-badge&logoColor=white"/>
  </a>
  <a href="#-화면-구성">
    <img src="https://img.shields.io/badge/SCREENS-5C86FA?style=for-the-badge&logoColor=white"/>
  </a>
  <br/><br/>
  <img alt="Status" src="https://img.shields.io/badge/status-연동준비완료-blue?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-상태관리-0099E5?style=flat-square" />
  <img alt="WebSocket" src="https://img.shields.io/badge/WebSocket-오디오전송-7B61FF?style=flat-square" />
  <img alt="Supabase" src="https://img.shields.io/badge/Supabase-Realtime-3FCF8E?style=flat-square&logo=supabase&logoColor=white" />
  <img alt="Platform" src="https://img.shields.io/badge/platform-Web%20%7C%20Desktop%20%7C%20Mobile-lightgrey?style=flat-square" />
</p>

<p align="center">
  <b>🇰🇷 한국어</b>
  ·
  <a href="docs/README_en.md">🇺🇸 English</a>
  ·
  <a href="docs/README_jp.md">🇯🇵 日本語</a>
</p>

> [!IMPORTANT]
> 이 저장소의 `Frontend` 폴더는 **LiveLectureAI의 학생용 Flutter 프론트엔드 위젯 앱**을 다룹니다.  
> 백엔드 서버, STT/LLM 모델, 데이터베이스 구성은 `App` 폴더 또는 백엔드 문서를 참고해 주세요.

<br/>

## 🧭 Navigation

1. [프로젝트 소개](#-프로젝트-소개)
2. [주요 기능](#-주요-기능)
3. [화면 구성](#-화면-구성)
4. [기술 스택](#-기술-스택)
5. [시작하기](#-시작하기)
6. [환경 변수](#-환경-변수)
7. [프로젝트 구조](#-프로젝트-구조)
8. [개발 명령어](#-개발-명령어)
9. [백엔드 연동 상태](#-백엔드-연동-상태)
10. [외부 사이트 적용 방향](#-외부-사이트-적용-방향)
11. [진행 상황](#-진행-상황)

<br/>

## 📌 프로젝트 소개

**LiveLectureAI Frontend**는 학생이 강의 화면 위에서 실시간 자막, 번역, 질문, 용어집 기능을 사용할 수 있도록 만든 Flutter 기반 학생용 강의 보조 위젯입니다.

현재 프론트엔드는 백엔드가 준비되면 바로 연결 테스트를 진행할 수 있도록 다음 연결 구조를 정리한 상태입니다.

- 질문 API 호출 구조
- 오디오 WebSocket 전송 구조
- Supabase Realtime 자막 수신 구조
- 환경변수 기반 서버 설정 구조
- 외부 강의 사이트 적용을 위한 위젯 이식 구조

학생은 강의 흐름을 놓치지 않고 다음 기능을 사용할 수 있습니다.

- 실시간 자막과 번역 확인
- 강의 맥락 기반 질문
- 수업 중 등장한 핵심 용어 확인
- 자막 위치, 투명도, 글자 크기 설정
- 자막 히스토리 확인
- 외부 강의 사이트 위에서 위젯 형태로 사용

<br/>

## ✨ 주요 기능

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>1️⃣ 실시간 자막 오버레이</h3>
      백엔드에서 처리한 강의 자막을 학생 화면에 반투명 오버레이 형태로 표시합니다. 번역 자막도 함께 보여줄 수 있습니다.
    </td>
    <td width="50%" valign="top">
      <h3>2️⃣ 강의 질문 패널</h3>
      학생이 수업 중 이해되지 않는 내용을 바로 질문할 수 있습니다. 질문 API는 백엔드의 <code>GET /lecture/ask</code> 구조에 맞춰 연결 준비가 완료되어 있습니다.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>3️⃣ 용어집 조회</h3>
      강의 중 등장한 어려운 용어를 확인할 수 있는 UI를 제공합니다. 현재 백엔드 조회 API 대기 상태이므로 mock 데이터를 유지합니다.
    </td>
    <td width="50%" valign="top">
      <h3>4️⃣ 자막 설정</h3>
      학생이 자막 투명도, 글자 크기, 위치, 번역 표시 여부를 조정할 수 있습니다.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>5️⃣ 자막 히스토리</h3>
      실시간으로 표시된 자막 기록을 다시 확인할 수 있습니다. 학습 흐름을 놓쳤을 때 이전 내용을 빠르게 확인할 수 있습니다.
    </td>
    <td width="50%" valign="top">
      <h3>6️⃣ 백엔드 연결 준비 구조</h3>
      HTTP API, WebSocket, Supabase Realtime을 분리하여 질문 요청, 오디오 전송, 실시간 자막 수신을 처리할 수 있도록 준비했습니다.
    </td>
  </tr>
</table>

<br/>

## 🖼 화면 구성

<p align="center">
  <table>
    <tr>
      <th align="center">자막 화면</th>
      <th align="center">용어집</th>
      <th align="center">질문 패널</th>
    </tr>
    <tr>
      <td align="center">
        <img src="../assets/screens/caption_screen.png" width="300"/>
      </td>
      <td align="center">
        <img src="../assets/screens/glossary_tab.png" width="300"/>
      </td>
      <td align="center">
        <img src="../assets/screens/question_panel.png" width="300"/>
      </td>
    </tr>
    <tr>
      <th align="center">자막 설정</th>
      <th align="center">자막 히스토리</th>
      <th align="center">-</th>
    </tr>
    <tr>
      <td align="center">
        <img src="../assets/screens/caption_settings.png" width="300"/>
      </td>
      <td align="center">
        <img src="../assets/screens/caption_history.png" width="300"/>
      </td>
      <td align="center">-</td>
    </tr>
  </table>
</p>

<br/>

## 🛠 기술 스택

### 📱 Frontend

<img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white"/> <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white"/> <img src="https://img.shields.io/badge/Riverpod-0099E5?style=flat-square"/> <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white"/>

- **Flutter** — 학생용 실시간 강의 보조 위젯 UI 개발
- **Dart** — 앱 로직 및 UI 구현
- **Riverpod** — 자막, 질문 패널, 용어집, 설정 상태 관리
- **HTTP API** — 질문 API 및 백엔드 REST API 호출 구조
- **WebSocket** — 프론트에서 백엔드로 오디오 bytes 전송 구조
- **Supabase Realtime** — 백엔드 STT 결과 자막 수신 구조
- **web_socket_channel** — 오디오 WebSocket 연결 관리
- **supabase_flutter** — Supabase Realtime Broadcast 수신

### 🔗 연동 대상

프론트엔드는 다음 백엔드 기능과 연동될 수 있도록 준비되어 있습니다.

- 강의 질문 API
- 오디오 WebSocket 수신 서버
- STT 결과 자막 Broadcast
- Supabase Realtime 채널
- 용어집 조회 API
- 강의 세션 ID 및 번역 목표 언어 값

<br/>

## 🚀 시작하기

### 1. 필요한 환경

- Flutter 3.x
- Dart SDK
- Chrome, Android Emulator, iOS Simulator, macOS Desktop 중 실행 대상 1개 이상
- LiveLectureAI 백엔드 서버
- Supabase 프로젝트 정보

### 2. 프로젝트 받기

```bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter/Frontend
```

### 3. 패키지 설치

```bash
flutter pub get
```

### 4. 실행 환경 확인

```bash
flutter doctor
```

### 5. Mock 화면 실행

백엔드 없이 UI만 확인할 경우 기본 실행이 가능합니다.

```bash
flutter run -d chrome
```

Mock 모드에서는 자막 오버레이, 질문 패널, 용어집, 자막 설정, 자막 히스토리 UI를 확인할 수 있습니다.

### 6. 백엔드 연결 테스트 실행

백엔드 서버와 Supabase 값이 준비된 경우 다음과 같이 실행합니다.

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=WS_BASE_URL=ws://localhost:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

<br/>

## 🔐 환경 변수

프론트엔드는 `AppConfig`를 통해 백엔드 연결 설정값을 한 곳에서 관리합니다.

설정 파일:

```text
lib/core/config/app_config.dart
```

관리하는 값은 다음과 같습니다.

| 변수명 | 설명 | 기본값 |
|---|---|---|
| `API_BASE_URL` | 백엔드 REST API 주소 | `http://localhost:8000` |
| `WS_BASE_URL` | 백엔드 WebSocket 주소 | `ws://localhost:8000` |
| `SUPABASE_URL` | Supabase 프로젝트 URL | 빈 값 |
| `SUPABASE_ANON_KEY` | Supabase anon key | 빈 값 |
| `LECTURE_ID` | 현재 강의 ID | `demo-lecture` |
| `TARGET_LANG` | 번역 목표 언어 | `Korean` |

로컬 백엔드 연결 예시:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=WS_BASE_URL=ws://localhost:8000 \
  --dart-define=SUPABASE_URL=your_supabase_url \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=LECTURE_ID=demo-lecture \
  --dart-define=TARGET_LANG=Korean
```

<br/>

## 📁 프로젝트 구조

현재 프론트엔드는 feature 기반 구조로 정리되어 있습니다.

```text
Frontend/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── docs/
│   └── frontend/
│       └── external_overlay_strategy.md
├── android/
├── ios/
├── web/
├── macos/
├── windows/
├── linux/
└── lib/
    ├── main.dart
    ├── core/
    │   ├── config/
    │   │   └── app_config.dart
    │   ├── constants/
    │   └── theme/
    ├── shared/
    │   └── widgets/
    ├── services/
    │   ├── api_service.dart
    │   ├── audio_stream_service.dart
    │   ├── sse_service.dart
    │   └── settings_service.dart
    └── features/
        ├── overlay/
        │   └── presentation/
        │       ├── pages/
        │       │   └── overlay_page.dart
        │       ├── widgets/
        │       │   └── status_bar.dart
        │       └── controllers/
        │           └── overlay_controller.dart
        ├── caption/
        │   └── presentation/
        │       ├── widgets/
        │       │   └── caption_overlay.dart
        │       └── controllers/
        │           ├── caption_controller.dart
        │           └── subtitle_model.dart
        └── assistant/
            └── presentation/
                ├── panels/
                │   └── assistant_panel.dart
                ├── widgets/
                │   └── glossary_tab.dart
                └── controllers/
                    └── question_model.dart
```

<br/>

## 🧪 개발 명령어

### 코드 포맷팅

```bash
dart format .
```

### 정적 분석

```bash
flutter analyze
```

현재 기준:

```text
No issues found!
```

### 빌드

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web

# macOS
flutter build macos
```

<br/>

## 📡 백엔드 연동 상태

현재 프론트엔드는 학생용 실시간 강의 보조 위젯 기준으로 백엔드 연결 준비를 완료한 상태입니다.

실제 백엔드 서버, Supabase 값, 강의 ID가 준비되면 연결 테스트를 진행할 수 있습니다.

### 연결 준비 완료 항목

- 질문 API 경로 정합성 1차 수정 완료
- 질문 패널 mock 응답 제거 및 실제 API 호출 구조 전환 완료
- 오디오 WebSocket 전송 서비스 구현 완료
- Supabase Realtime 자막 수신 구조 정리 완료
- 자막 payload 정합성 수정 완료
- AppConfig 기반 환경변수 관리 구조 추가 완료
- 마이크 입력 캡처와 오디오 전송 서비스 연결 지점 정리 완료
- 용어집 API 백엔드 대기 상태 표시 완료
- 외부 사이트 적용 방식 검토 완료

### 현재 프론트 연결 구조

| 기능 | 프론트 구조 | 백엔드 연결 기준 |
|---|---|---|
| 질문 API | `ApiService.askQuestion()` | `GET /lecture/ask` |
| 오디오 전송 | `AudioStreamService` | `WS /ws/audio/{lecture_id}` |
| 자막 수신 | `SseService` 내부 Supabase Realtime 수신 | channel: `lecture_{lecture_id}`, event: `new_caption` |
| 용어집 조회 | mock 유지 | 백엔드 조회 API 대기 |
| 설정값 관리 | `AppConfig` | `--dart-define` 기반 주입 |

### 질문 API

프론트는 다음 형태로 질문 API를 호출할 수 있도록 수정되어 있습니다.

```text
GET /lecture/ask?lecture_id={lecture_id}&question={question}&target_lang={target_lang}
```

현재 기본값:

```text
lecture_id = demo-lecture
target_lang = Korean
```

### 실시간 자막 수신

백엔드가 Supabase Realtime Broadcast로 자막을 보내는 구조에 맞춰 프론트 수신 구조를 정리했습니다.

```text
channel = lecture_{lecture_id}
event = new_caption
payload = original, translated
```

프론트 자막 모델은 다음 두 형식을 모두 받을 수 있습니다.

```text
original / translated
original_text / translated_text
```

### 오디오 WebSocket 전송

프론트에서 백엔드로 오디오 bytes를 보낼 수 있는 서비스 구조를 추가했습니다.

```text
WS /ws/audio/{lecture_id}
```

마이크 캡처 기능이 붙으면 생성된 audio chunk를 아래 함수로 전달하면 됩니다.

```dart
sendAudioBytes(audioChunk)
```

### 용어집 상태

백엔드에는 `lecture_glossary` 저장 로직이 있으나, 프론트에서 호출할 조회 API는 아직 확인되지 않았습니다.

따라서 현재 용어집 UI는 유지하고, 조회 데이터는 mock 상태로 둡니다.

백엔드 조회 API가 제공되면 실제 API 호출로 교체할 예정입니다.

<br/>

## 🧩 외부 사이트 적용 방향

학생용 실시간 강의 보조 위젯을 외부 강의 사이트 위에 적용하기 위해 iframe 방식과 Chrome Extension 방식을 검토했습니다.

검토 문서:

```text
docs/frontend/external_overlay_strategy.md
```

### 결론

- **1차 방향: Chrome Extension**
- **보조 방향: iframe 데모 페이지**

Chrome Extension 방식은 학생이 실제 강의 사이트를 유지한 상태에서 자막, 질문, 용어집 위젯을 화면 위에 띄울 수 있어 프로젝트 목표에 더 적합합니다.

iframe 방식은 자체 데모 페이지나 우리가 제어 가능한 페이지에서는 사용할 수 있지만, 실제 외부 강의 사이트 적용에는 제한이 있습니다.

<br/>

## 📊 진행 상황

### ✅ 완료

- [x] Flutter 앱 기본 구조 구성
- [x] feature 기반 폴더 구조 정리
- [x] 파일명과 클래스명 네이밍 통일
- [x] 실시간 자막 오버레이 UI
- [x] 질문 패널 UI
- [x] 용어집 탭 UI
- [x] 자막 설정 및 히스토리 UI
- [x] Riverpod 기반 상태 관리 구조
- [x] Mock 자막 스트림 구조
- [x] Mock 질문/용어집 응답 구조
- [x] KO/EN 언어 전환 버튼
- [x] 주요 UI 버튼 동작 확인
- [x] Flutter analyze No issues found 확인
- [x] 질문 API `/lecture/ask` 연결 구조 정리
- [x] 오디오 WebSocket 전송 서비스 구현
- [x] Supabase Realtime 자막 수신 구조 정리
- [x] 자막 payload 정합성 수정
- [x] AppConfig 기반 환경변수 관리 구조 추가
- [x] 실제 `lecture_id` / `target_lang` 연결 지점 정리
- [x] 마이크 입력 캡처와 오디오 전송 서비스 연결 지점 정리
- [x] 용어집 API 백엔드 대기 상태 표시
- [x] 학생용 외부 사이트 적용 방식 검토
- [x] Frontend README 화면 구성 스크린샷 반영
- [x] GitHub main 브랜치 최신 반영

### 🚧 다음 작업

- [ ] 실제 백엔드 서버 실행 후 질문 API 연결 테스트
- [ ] Supabase 환경변수 실제 값 적용 후 자막 수신 테스트
- [ ] 마이크 입력 캡처 기능 구현 여부 결정
- [ ] 백엔드 용어집 조회 API 제공 시 프론트 연결
- [ ] Chrome Extension manifest 구조 설계
- [ ] Flutter Web build 결과물을 Extension에 포함할 수 있는지 검토

<br/>

## 🤝 기여 방법

1. 이슈를 생성하거나 기존 이슈를 확인합니다.
2. 작업 브랜치를 생성합니다.

```bash
git checkout -b feature/your-feature-name
```

3. 변경 사항을 커밋합니다.

```bash
git commit -m "feat: add your feature"
```

4. Pull Request를 생성합니다.