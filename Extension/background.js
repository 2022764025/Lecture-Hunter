// background.js - [민재 VLM 권한 파이프라인] + [여자친구 드래그/리사이즈] 대통합 버전

const BACKEND_WS = "ws://127.0.0.1:8000/ws/audio";
const WIDGET_URL = "http://127.0.0.1:9998"; // flutter run -d chrome 주소

// 크기 조절 시 위젯이 터지는 걸 방지하는 최소/최대 규격 제한 한계선 세팅
const MIN_WIDTH = 280;
const MAX_WIDTH = 600;

let activeTabId = null;

chrome.action.onClicked.addListener(async (tab) => {
  if (activeTabId === tab.id) {
    await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: removeWidget });
    await chrome.runtime.sendMessage({ type: "stop-capture" });
    activeTabId = null;
    return;
  }

  activeTabId = tab.id;
  const lectureId = "lecture-" + tab.id;

  // [중요] 스크립트 인젝션 시 반응형 최소/최대 크기 상수를 args 배열 인자로 안전하게 패스
  await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: injectWidget,
    args: [WIDGET_URL, lectureId, MIN_WIDTH, MAX_WIDTH]
  });

  if (!(await chrome.offscreen.hasDocument())) {
    await chrome.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["USER_MEDIA"],
      justification: "탭 오디오 캡처 후 STT 서버로 전송"
    });
  }

  const streamId = await chrome.tabCapture.getMediaStreamId({ targetTabId: tab.id });
  chrome.runtime.sendMessage({ type: "start-capture", streamId, lectureId, wsBase: BACKEND_WS });
});

function injectWidget(url, lectureId, minWidth, maxWidth) {
  if (document.getElementById("llai-widget")) return;

  const iframe = document.createElement("iframe");
  iframe.id = "llai-widget";
  
  // main.dart 라우터가 주소를 동적으로 파싱할 수 있게 파라미터는 무조건 'room' 유지
  iframe.src = url + "/?room=" + lectureId;
  
  // 외부 LMS 사이트 내부에서도 화면 캡처 및 음성 권한을 프리패스 시키는 핵심 마스터 키 유지
  iframe.setAttribute("allow", "display-capture; microphone; camera;");
  
  Object.assign(iframe.style, {
    position: "fixed", 
    top: "20px", 
    right: "20px",
    left: "auto", // 여자친구의 자유 드래그 좌표축 초기화 세팅
    width: "380px", 
    height: "560px", 
    border: "none",
    zIndex: "2147483647", 
    opacity: "0.95", // 민재님 고유 UI 불투명도 스타일 보존
    background: "transparent", 
    boxShadow: "0 4px 20px rgba(0,0,0,0.3)", 
    borderRadius: "12px"
  });

  document.body.appendChild(iframe);

  // 플러터 위젯 설정 탭에서 크기나 드래그 전송 시 브라우저가 반응하는 리스너 엔진 이식
  window.addEventListener("message", (event) => {
    if (event.source !== iframe.contentWindow) return;
    const data = event.data || {};

    // 1. 설정 창 슬라이더 조절 시 실시간 너비 리사이징 파트
    if (data.type === "llai-resize" && typeof data.width === "number") {
      const clamped = Math.min(maxWidth, Math.max(minWidth, data.width));
      iframe.style.width = clamped + "px";
    }

    // 2. 마우스 휠이나 타이틀바 홀드하여 이리저리 이동시키는 자유 드래그 파트
    if (data.type === "llai-drag" && typeof data.dx === "number" && typeof data.dy === "number") {
      const rect = iframe.getBoundingClientRect();
      iframe.style.left = (rect.left + data.dx) + "px";
      iframe.style.top = (rect.top + data.dy) + "px";
      iframe.style.right = "auto";
    }
  });
}

function removeWidget() {
  document.getElementById("llai-widget")?.remove();
}