// background.js - 완벽 연동 성공 버전으로 원상복구
const BACKEND_WS = "ws://127.0.0.1:8000/ws/audio";
const WIDGET_URL = "http://127.0.0.1:9998"; // flutter run -d chrome 주소

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
    args: [WIDGET_URL, lectureId]
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

function injectWidget(url, lectureId) {
  if (document.getElementById("llai-widget")) return;
  const iframe = document.createElement("iframe");
  iframe.id = "llai-widget";
  iframe.src = url + "/?lecture_id=" + lectureId;
  
  Object.assign(iframe.style, {
    position: "fixed", top: "20px", right: "20px",
    width: "380px", height: "560px", border: "none",
    zIndex: "2147483647", opacity: "0.95",
    boxShadow: "0 4px 20px rgba(0,0,0,0.3)", borderRadius: "12px"
  });
  document.body.appendChild(iframe);
}

function removeWidget() {
  document.getElementById("llai-widget")?.remove();
}