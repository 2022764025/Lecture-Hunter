<p align="center">
  <img width="100%" src="https://capsule-render.vercel.app/api?type=slice&height=180&color=gradient&text=Frontend&fontAlignY=25&fontAlign=70&rotate=12&animation=twinkling&desc=과제헌터_LiveLectureAI&descAlignY=43&descAlign=58" />
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
  <img alt="Platform" src="https://img.shields.io/badge/platform-Mobile%20%7C%20Desktop-lightgrey?style=flat-square" />
</p>

<p align="center">
  <b>🇰🇷 한국어</b>
  ·
  <a href="docs/README_en.md">🇺🇸 English</a>
  ·
  <a href="docs/README_jp.md">🇯🇵 日本語</a>
</p>

<br/>

> [!IMPORTANT]
> 이 저장소는 **LiveLectureAI의 프론트엔드 앱**을 다룹니다.  
> 백엔드 서버, STT/LLM 모델, 데이터베이스 구성은 별도 서버 저장소 또는 백엔드 문서를 참고해 주세요.

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
9. [진행 상황](#-진행-상황)
10. [팀](#-팀)

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
      WebSocket 또는 SSE 기반 통신을 통해 자막·요약·질문 응답 데이터를 빠르게 반영합니다.
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

- **Flutter** — 모바일·데스크탑 크로스 플랫폼 앱 개발
- **Dart** — 앱 로직 및 UI 구현
- **Riverpod** — 전역 상태 관리
- **WebSocket / SSE** — 실시간 자막·질문 응답 수신
- **REST API** — 강의 세션, 요약, 용어집 데이터 요청

### 🔗 연동 대상

프론트엔드는 다음 백엔드 기능과 연동됩니다.

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
- Android Studio 또는 Xcode
- Chrome, Android Emulator, iOS Simulator, macOS Desktop 중 실행 대상 1개 이상
- LiveLectureAI 백엔드 서버

### 2. 프로젝트 받기

```bash
git clone https://github.com/2022764025/Lecture-Hunter.git
cd Lecture-Hunter/flutter_app
```

> 프론트엔드 전용 저장소로 분리되어 있다면 `cd flutter_app` 과정은 생략하고, 클론한 저장소 루트에서 아래 명령어를 실행하면 됩니다.

### 3. 패키지 설치

```bash
flutter pub get
```

### 4. 실행 환경 확인

```bash
flutter doctor
```

### 5. 앱 실행

```bash
flutter run
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

프론트엔드는 백엔드 API 주소와 실시간 통신 주소가 필요합니다.

### 권장 실행 방식

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

> 실제 프로젝트에서 `.env` 파일 또는 별도 config 파일을 사용한다면, 위 변수명을 프로젝트 설정 방식에 맞게 매핑해 주세요.

<br/>

## 📁 프로젝트 구조

아래 구조는 Flutter 프론트엔드 기준의 권장 구성입니다. 실제 폴더명은 프로젝트 상황에 맞게 조정될 수 있습니다.

```text
lib/
├── main.dart                 # 앱 진입점
├── app/                      # 앱 공통 설정, 라우팅, 테마
├── core/                     # 상수, 네트워크, 예외 처리, 유틸
├── features/                 # 기능 단위 화면 및 상태
│   ├── lecture/              # 강의 세션
│   ├── caption/              # 실시간 자막
│   ├── chat/                 # AI 질문
│   ├── summary/              # 강의 요약
│   └── glossary/             # 용어집
├── shared/                   # 공통 위젯, 공통 모델
└── services/                 # API, WebSocket, 로컬 저장소 연동
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

### 테스트

```bash
flutter test
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

## 📡 백엔드 연동 체크리스트

프론트엔드 실행 전 아래 항목을 확인해 주세요.

- [ ] 백엔드 서버가 실행 중인가요?
- [ ] `API_BASE_URL` 주소가 백엔드 서버 주소와 일치하나요?
- [ ] `WS_BASE_URL` 주소가 WebSocket 주소와 일치하나요?
- [ ] CORS 또는 WebSocket 연결 정책이 클라이언트 실행 주소를 허용하나요?
- [ ] 강의 세션 생성·자막 수신·질문 응답 API가 정상 동작하나요?

<br/>

## 📊 진행 상황

### ✅ 완료

- [x] Flutter 앱 기본 구조 구성
- [x] 실시간 자막 화면 UI
- [x] 질문 패널 UI
- [x] Riverpod 기반 상태 관리 구조
- [x] 백엔드 실시간 통신 연동 구조

### 🚧 작업 중

- [ ] 강의 요약 카드 UI 고도화
- [ ] 용어집 화면 고도화
- [ ] 강의 세션 히스토리 화면
- [ ] 에러·로딩 상태 UX 개선
- [ ] 반응형 레이아웃 정리
- [ ] 테스트 코드 보강

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

<br/>

## 👥 과제헌터
