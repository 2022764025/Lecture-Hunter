# External Overlay Strategy

## 목적

LiveLectureAI 프론트엔드를 기존 강의 사이트 위에 적용하기 위한 구조 검토 문서.

현재 프론트엔드 개발 범위는 학생용 실시간 강의 보조 위젯이다.

주요 기능은 다음과 같다.

- 실시간 자막 오버레이
- 번역 자막 표시
- 질문 입력 패널
- 용어집 조회
- 자막 설정 및 히스토리
- 외부 강의 사이트 위에 띄울 수 있는 독립형 위젯 구조

---

## 검토 대상

## 1. iframe 방식

Flutter Web 앱을 iframe으로 외부 페이지에 삽입하는 방식.

### 장점

- 구현 난이도가 낮음
- 현재 Flutter Web 결과물을 그대로 활용 가능
- 자체 데모 페이지에 삽입하기 쉬움
- 학생용 위젯 시연용으로 빠르게 사용 가능

### 단점

- 외부 강의 사이트가 iframe 삽입을 허용해야 함
- YouTube, LMS, 상용 강의 플랫폼은 보안 정책으로 iframe 적용이 제한될 수 있음
- 기존 강의 화면 위에 자연스럽게 겹치는 오버레이 구현이 어려움
- 외부 사이트의 영상 영역, 버튼, 화면 상태와 직접 연동하기 어려움

### 적합한 경우

- 자체 시연 페이지
- 우리가 제어 가능한 웹페이지
- 프로젝트 데모용 화면

---

## 2. Chrome Extension 방식

Chrome Extension의 content script를 사용해 기존 강의 사이트 위에 LiveLectureAI 오버레이를 주입하는 방식.

### 장점

- 기존 강의 사이트 위에 직접 오버레이 표시 가능
- 학생이 실제로 보는 강의 화면을 유지한 채 자막 위젯 사용 가능
- 질문 패널, 용어집, 자막 설정 버튼을 floating UI로 배치 가능
- iframe 차단 정책의 영향을 덜 받음
- 외부 강의 사이트 적용 목적에 더 적합

### 단점

- Extension manifest, content script, 권한 설정 필요
- 사이트별 CSS 충돌 가능성 있음
- z-index, pointer-events, 반응형 위치 조정 필요
- Flutter Web 전체를 Extension에 넣을지, 별도 overlay UI로 분리할지 검토 필요

### 적합한 경우

- 실제 외부 강의 사이트 적용
- LMS, 온라인 강의 페이지, 웹 기반 화상 강의 페이지 위에 오버레이 표시
- 학생이 강의 화면 위에서 자막/질문/용어집을 동시에 사용하는 경우

---

## 결론

LiveLectureAI의 핵심 목표는 학생이 기존 강의 화면 위에서 실시간 자막, 번역, 질문, 용어집 기능을 사용하는 것이다.

따라서 실제 외부 사이트 적용 방식은 Chrome Extension이 더 적합하다.

iframe 방식은 자체 데모 페이지나 제한된 시연 환경에서는 사용할 수 있지만, 실제 강의 사이트 적용에는 한계가 있다.

---

## 최종 방향

- 1차 방향: Chrome Extension
- 보조 방향: iframe 데모 페이지
- Flutter Web 앱은 독립형 학생용 위젯 UI로 유지
- Extension에서는 외부 페이지 위에 overlay container를 주입하는 구조 검토
- 기존 AppConfig 기반 API / WebSocket / Supabase 설정 재사용
- 백엔드 연결은 질문 API, 오디오 WebSocket, Supabase Realtime 자막 수신 구조를 기준으로 진행

---

## 다음 검토 항목

- Chrome Extension manifest 구조 설계
- content script에서 overlay root 생성 방식 검토
- Flutter Web build 결과물을 Extension에 포함할 수 있는지 검토
- iframe 데모 페이지 필요 여부 결정
- 외부 사이트 위에서 자막 위젯 위치, 투명도, 클릭 이벤트 충돌 여부 검토
