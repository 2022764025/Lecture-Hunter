const BACKEND_WS = "ws://127.0.0.1:8000/ws/audio";
const WIDGET_URL = "http://127.0.0.1:9998";

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
  iframe.src = url + "/?lecture_id=" + lectureId;

  Object.assign(iframe.style, {
    position: "fixed",
    top: "20px",
    right: "20px",
    left: "auto",
    width: "380px",
    height: "560px",
    border: "none",
    zIndex: "2147483647",
    background: "transparent",
    boxShadow: "0 4px 20px rgba(0,0,0,0.3)",
    borderRadius: "12px"
  });

  document.body.appendChild(iframe);

  window.addEventListener("message", (event) => {
    if (event.source !== iframe.contentWindow) return;
    const data = event.data || {};

    if (data.type === "llai-resize" && typeof data.width === "number") {
      const clamped = Math.min(maxWidth, Math.max(minWidth, data.width));
      iframe.style.width = clamped + "px";
    }

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