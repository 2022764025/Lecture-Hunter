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
  <img alt="Status" src="https://img.shields.io/badge/status-개발중-orange?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-상태관리-0099E5?style=flat-square" />
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
> 이 저장소의 `Frontend` 폴더는 **LiveLectureAI의 Flutter 프론트엔드 앱**을 다룹니다.  
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
10. [진행 상황](#-진행-상황)

<br/>

## 📌 프로젝트 소개

**LiveLectureAI Frontend**는 강의 중 발생하는 음성, 자막, 번역, 질문, 요약, 용어 정보를 학생이 한 화면에서 확인할 수 있도록 만든 Flutter 기반 클라이언트 앱입니다.

학생은 강의 흐름을 놓치지 않고 다음 기능을 사용할 수 있습니다.

- 실시간 자막과 번역 확인
- 강의 맥락 기반 AI 질문
- 최근 강의 내용 요약
- 수업 중 등장한 핵심 용어 확인
- 강의 세션별 학습 기록 확인

<br/>

## ✨ 주요 기능

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>1️⃣ 실시간 자막 오버레이</h3>
      강의 음성을 백엔드에서 변환한 뒤 앱 화면에 실시간으로 표시합니다. 외국어 강의의 경우 번역 문장도 함께 보여줄 수 있습니다.
    </td>
    <td width="50%" valign="top">
      <h3>2️⃣ 강의 질문 패널</h3>
      수업 중 이해되지 않는 내용을 바로 질문할 수 있습니다. 사용자는 현재 강의 맥락을 유지한 상태에서 AI 답변을 확인합니다.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>3️⃣ 핵심 요약 카드</h3>
      최근 강의 내용을 짧게 정리해 보여줍니다. 늦게 입장했거나 흐름을 놓쳤을 때 빠르게 따라갈 수 있도록 돕습니다.
    </td>
    <td width="50%" valign="top">
      <h3>4️⃣ 자동 용어집</h3>
      강의 중 등장한 어려운 용어를 정리하고, 사용자가 필요한 개념을 빠르게 확인할 수 있도록 제공합니다.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>5️⃣ 강의 세션 관리</h3>
      현재 참여 중인 강의 세션, 자막 로그, 질문 기록, 요약 정보를 화면 단위로 관리합니다.
    </td>
    <td width="50%" valign="top">
      <h3>6️⃣ 실시간 서버 연동</h3>
      WebSocket 또는 SSE 기반 통신을 통해 자막·요약·질문 응답 데이터를 빠르게 반영하는 구조를 준비합니다.
    </td>
  </tr>
</table>

<br/>

## 🖼 화면 구성

<p align="center">
  <table>
    <tr>
      <th align="center">자막 화면</th>
      <th align="center">질문 패널</th>
      <th align="center">용어집</th>
    </tr>
    <tr>
      <td align="center"><i>스크린샷 준비 중</i></td>
      <td align="center"><i>스크린샷 준비 중</i></td>
      <td align="center"><i>스크린샷 준비 중</i></td>
    </tr>
  </table>
</p>

<br/>

## 🛠 기술 스택

### 📱 Frontend

<img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white"/> <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white"/> <img src="https://img.shields.io/badge/Riverpod-0099E5?style=flat-square"/>

- **Flutter** — Web 기반 실시간 자막 오버레이 UI 개발
- **Dart** — 앱 로직 및 UI 구현
- **Riverpod** — 자막, 테마, 질문 패널 상태 관리
- **HTTP API** — 질문, 용어집, 요약 API 연결 준비
- **SSE / WebSocket** — 실시간 자막 수신 및 오디오 스트리밍 연결 준비

### 🔗 연동 대상

프론트엔드는 다음 백엔드 기능과 연동될 예정입니다.

- 음성 인식 결과 수신
- 번역 자막 수신
- 강의 문맥 기반 질문 응답 요청
- 요약 및 용어집 데이터 조회
- 강의 세션 데이터 저장·조회

<br/>

## 🚀 시작하기

### 1. 필요한 환경

- Flutter 3.x
- Dart SDK
- Chrome, Android Emulator, iOS Simulator, macOS Desktop 중 실행 대상 1개 이상
- LiveLectureAI 백엔드 서버

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

### 5. 앱 실행

Chrome 기준 실행:

```bash
flutter run -d chrome
```

실행 대상을 직접 지정하려면 다음처럼 사용할 수 있습니다.

```bash
flutter devices
flutter run -d chrome
flutter run -d macos
flutter run -d <device-id>
```

<br/>

## 🔐 환경 변수

현재 프론트엔드는 서비스 파일 내부에서 로컬 백엔드 주소를 사용합니다.

```dart
http://localhost:8000
```

추후 환경별 실행을 위해 아래 방식으로 분리 예정입니다.

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=WS_BASE_URL=ws://localhost:8000
```

### 예시 값

| 변수명 | 설명 | 예시 |
|---|---|---|
| `API_BASE_URL` | REST API 서버 주소 | `http://localhost:8000` |
| `WS_BASE_URL` | WebSocket 서버 주소 | `ws://localhost:8000` |
| `APP_ENV` | 실행 환경 | `local`, `dev`, `prod` |

<br/>

## 📁 프로젝트 구조

현재 프론트엔드는 feature 기반 구조로 정리되어 있습니다.

```text
Frontend/
├── main.dart
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── android/
├── ios/
├── web/
├── macos/
├── windows/
├── linux/
└── lib/
    ├── main.dart
    ├── core/
    │   ├── constants/
    │   └── theme/
    ├── shared/
    │   └── widgets/
    ├── services/
    │   ├── api_service.dart
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

현재 프론트엔드는 Mock 기반 UI 동작 확인까지 완료되었으며, 백엔드 실제 엔드포인트와의 API 경로 정합성 수정 단계입니다.

### 확인 완료 항목

- `api_service.dart` 백엔드 HTTP 호출 구조 확인
- `sse_service.dart` 실시간 자막 스트림 수신 구조 확인
- `caption_controller.dart` Provider 연결 구조 확인
- `overlay_page.dart` Mock / 실서버 전환 구조 확인
- 백엔드 실제 엔드포인트 목록 확인

### 현재 프론트 연결 구조

- `ApiService` 기반 HTTP API 호출 구조 존재
- `SseService` 기반 실시간 자막 스트림 수신 구조 존재
- `sseServiceProvider` 등록 완료
- `connectionStatusProvider` 연결 완료
- `subtitleStreamProvider` 연결 완료
- `currentSubtitleProvider` 기반 최신 자막 표시 구조 존재
- Mock 모드 / 실서버 연결 전환 구조 존재

### 확인된 경로 불일치

| 구분 | 현재 프론트 경로 | 현재 백엔드 경로 |
|---|---|---|
| 질문 API | `POST /api/v1/qa/ask` | `GET /lecture/ask` |
| 용어집 API | `GET /api/v1/glossary/search` | 백엔드 엔드포인트 미확인 |
| 실시간 자막 수신 | `GET /api/v1/subtitle/stream` | `WS /ws/audio/{lecture_id}` |

### 다음 수정 예정

- `api_service.dart` 질문 API 경로 수정
- `/lecture/ask` 요청 방식 및 파라미터 구조 확인
- 용어집 API 백엔드 엔드포인트 추가 여부 확인
- `sse_service.dart` 유지 여부 결정
- 백엔드 WebSocket 구조와 프론트 실시간 자막 수신 구조 매칭

<br/>

## 📊 진행 상황

### ✅ 완료

- [x] Flutter 앱 기본 구조 구성
- [x] feature 기반 폴더 구조 정리
- [x] 파일명과 클래스명 네이밍 통일
- [x] 실시간 자막 오버레이 UI
- [x] 질문 패널 UI
- [x] 용어집 탭 UI
- [x] Riverpod 기반 상태 관리 구조
- [x] Mock 자막 스트림 구조
- [x] Mock 질문/용어집 응답 구조
- [x] KO/EN 언어 전환 버튼
- [x] 주요 UI 버튼 동작 확인
- [x] Flutter analyze No issues found 확인
- [x] GitHub main 브랜치 최신 반영

### 🚧 작업 중

- [ ] STT/API/SSE 실제 연결 경로 정합성 수정
- [ ] 질문 API `/lecture/ask` 프론트 연결
- [ ] 용어집 API 엔드포인트 추가 또는 프론트 경로 수정
- [ ] 실시간 자막 수신 방식 결정: SSE 유지 또는 WebSocket 구조 전환
- [ ] 강의 요약 카드 UI 고도화
- [ ] 용어집 화면 고도화
- [ ] 강의 세션 히스토리 화면
- [ ] 에러·로딩 상태 UX 개선
- [ ] 반응형 레이아웃 정리

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
