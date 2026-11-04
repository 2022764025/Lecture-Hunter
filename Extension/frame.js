/*
 * frame.html: 페이지(content.js)와 위젯(http://127.0.0.1:9998) 사이에서 메시지를 전달한다.
 *
 * 위젯을 확장 페이지 안에 한 번 더 넣는 이유:
 *   크롬 142+의 Local Network Access 때문에 공개 사이트(youtube.com)가 127.0.0.1을 바로 iframe으로 열면 막힌다.
 *   확장 페이지는 host_permissions(127.0.0.1)가 있어 이 제한을 받지 않는다.
 *
 * 위젯 → 페이지: llai-ready, llai-layout(크기·드래그 손잡이), llai-capture-request(화면 캡처 요청)
 * 페이지 → 위젯: llai-audio(오디오 전송 상태), llai-capture-result
 * 위젯에는 처음 준비됐을 때 llai-host 를 보내 확장 안에서 실행 중임을 알린다.
 */
(() => {
  const CFG = self.LLAI_CONFIG;
  const params = new URLSearchParams(location.search);
  const lectureId = params.get('lecture_id') || '';
  const widgetOrigin = new URL(CFG.WIDGET_URL).origin;
  const parentOrigin = (location.ancestorOrigins && location.ancestorOrigins[0]) || '*';
  const READY_TIMEOUT_MS = 12000;

  const widget = document.getElementById('widget');
  let ready = false;
  let readyTimer = null;

  document.getElementById('widget-url').textContent = CFG.WIDGET_URL;
  document.getElementById('retry').addEventListener('click', load);

  function toParent(message) {
    window.parent.postMessage(message, parentOrigin);
  }

  function load() {
    ready = false;
    document.body.classList.remove('failed');
    const url = new URL(CFG.WIDGET_URL);
    url.searchParams.set('lecture_id', lectureId);
    widget.src = url.toString();
    clearTimeout(readyTimer);
    readyTimer = setTimeout(() => {
      if (ready) return;
      document.body.classList.add('failed');
      // 안내 카드가 보이도록 페이지 쪽 틀 크기를 맞춘다 (카드 전체를 드래그 손잡이로)
      toParent({
        type: 'llai-layout', width: 420, height: 230, minimized: false,
        dragHandle: { x: 0, y: 0, width: 420, height: 60 },
      });
    }, READY_TIMEOUT_MS);
  }

  const FROM_WIDGET = new Set(['llai-ready', 'llai-layout', 'llai-capture-request']);
  const FROM_PARENT = new Set(['llai-audio', 'llai-capture-result']);

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.type !== 'string') return;

    if (event.source === widget.contentWindow && event.origin === widgetOrigin) {
      if (!FROM_WIDGET.has(data.type)) return;
      if (data.type === 'llai-ready') {
        ready = true;
        clearTimeout(readyTimer);
        document.body.classList.remove('failed');
        widget.contentWindow.postMessage({ type: 'llai-host', host: 'chrome-extension', features: ['tab-capture', 'audio-status'] }, widgetOrigin);
      }
      toParent(data);
      return;
    }

    if (event.source === window.parent && FROM_PARENT.has(data.type) && widget.contentWindow) {
      widget.contentWindow.postMessage(data, widgetOrigin);
    }
  });

  load();
})();
