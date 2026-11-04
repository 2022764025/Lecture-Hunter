/*
 * Lecture-Hunter content script: 강의 페이지 위에 위젯 틀을 띄운다.
 *
 * - 틀은 닫힌 shadow DOM 안의 iframe(frame.html)이라 페이지 CSS·스크립트가 건드리지 못한다.
 * - popover(top layer)로 띄워서 유튜브 전체화면에서도 영상 위에 보인다.
 * - 위젯이 보내는 llai-layout(크기·최소화·드래그 손잡이 위치)에 맞춰 틀 크기를 바꾸고,
 *   손잡이 영역(로고·제목 줄) 위에 투명한 div를 깔아 드래그는 여기서 처리한다.
 *   (iframe 안에서 드래그하면 iframe이 움직일 때 좌표가 같이 바뀌어 위젯이 떨린다)
 * - 위치는 chrome.storage.local에 저장한다. 손잡이를 더블클릭하면 처음 자리(오른쪽 위)로 돌아간다.
 * - 화면 캡처 요청이 오면 위젯을 잠깐 숨기고 보이는 화면을 찍어(서비스 워커) 위젯에 돌려준다.
 *
 * 유튜브에는 manifest로 항상 들어가고, 다른 사이트에는 아이콘을 누를 때 background.js가 넣는다.
 * 강의 중인 탭이 아니면 아무것도 하지 않는다.
 */
(() => {
  if (window.__llaiContentLoaded) return; // manifest + executeScript 중복 실행 방지
  window.__llaiContentLoaded = true;

  const HOST_ID = 'llai-lecture-hunter';
  const POSITION_KEY = 'llai_widget_position';
  const MARGIN = 8;          // 화면 가장자리와 띄울 최소 간격
  const DEFAULT_OFFSET = 20; // 처음 위치: 오른쪽 위에서 20px
  const CAPTURE_MAX_SIDE = 1600;
  const EXT_ORIGIN = new URL(chrome.runtime.getURL('')).origin;
  const DEFAULT_LAYOUT = Object.freeze({
    width: 420, height: 640, minimized: false, dragHandle: { x: 0, y: 0, width: 360, height: 57 },
  });

  let host = null;
  let frame = null;
  let handle = null;
  let session = null;
  let layout = { ...DEFAULT_LAYOUT };
  let position = null; // { x, y } 사용자가 옮긴 위치 (없으면 오른쪽 위)
  let audio = null;    // 마지막 오디오 상태 (위젯이 늦게 준비돼도 다시 보낸다)
  let drag = null;
  let capturing = false;

  const important = (el, styles) => {
    for (const [key, value] of Object.entries(styles)) el.style.setProperty(key, value, 'important');
  };
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const num = (v, min, max, fallback) => (Number.isFinite(v) ? clamp(v, min, max) : fallback);

  // ─── 틀 만들기 / 없애기 ───────────────────────────────────────

  function mount(next) {
    if (!next || !next.lectureId) return;
    if (host && session && session.lectureId === next.lectureId) return; // 이미 떠 있음
    unmount();
    document.getElementById(HOST_ID)?.remove(); // 확장을 다시 불러오기 전에 남은 틀

    session = next;
    audio = next.audio || null;
    layout = { ...DEFAULT_LAYOUT };

    host = document.createElement('div');
    host.id = HOST_ID;
    host.setAttribute('popover', 'manual');
    // popover 기본 스타일(가운데 정렬·테두리·배경)을 지우고 위치는 직접 정한다
    important(host, {
      position: 'fixed', inset: 'auto', margin: '0', padding: '0', border: '0',
      background: 'transparent', overflow: 'visible', 'border-radius': '19px',
      'box-shadow': '0 10px 30px rgba(0, 0, 0, 0.28)', 'color-scheme': 'normal',
      'z-index': '2147483647', 'max-width': 'none', 'max-height': 'none',
    });

    const root = host.attachShadow({ mode: 'closed' });

    frame = document.createElement('iframe');
    frame.title = 'Lecture-Hunter';
    frame.allow = 'display-capture';
    frame.src = `${chrome.runtime.getURL('frame.html')}?lecture_id=${encodeURIComponent(session.lectureId)}`;
    important(frame, {
      display: 'block', border: '0', width: '100%', height: '100%', 'border-radius': '19px',
      background: 'transparent', 'color-scheme': 'normal',
    });

    handle = document.createElement('div');
    handle.title = '드래그해서 옮기기 · 더블클릭하면 처음 자리로';
    important(handle, {
      position: 'absolute', cursor: 'grab', 'touch-action': 'none', 'user-select': 'none', background: 'transparent',
    });
    handle.addEventListener('pointerdown', onPointerDown);
    handle.addEventListener('pointermove', onPointerMove);
    handle.addEventListener('pointerup', onPointerUp);
    handle.addEventListener('pointercancel', onPointerUp);
    handle.addEventListener('dblclick', () => {
      position = null;
      savePosition();
      applyLayout();
    });

    root.append(frame, handle);
    document.documentElement.appendChild(host);
    showOnTop();
    applyLayout();

    chrome.storage.local.get(POSITION_KEY).then((saved) => {
      const p = saved[POSITION_KEY];
      if (host && p && Number.isFinite(p.x) && Number.isFinite(p.y)) {
        position = p;
        applyLayout();
      }
    }).catch(() => {});
  }

  function unmount() {
    host?.remove();
    host = frame = handle = null;
    session = null;
    drag = null;
  }

  /** top layer에 (다시) 올린다. 전체화면 요소가 생기면 그보다 위로 가야 해서 다시 띄운다. */
  function showOnTop() {
    if (!host) return;
    try {
      if (host.matches(':popover-open')) host.hidePopover();
      host.showPopover();
    } catch (_) {
      important(host, { display: 'block' }); // popover를 못 쓰는 브라우저
    }
  }

  // ─── 크기·위치 ───────────────────────────────────────────────

  function viewport() {
    return {
      w: document.documentElement.clientWidth || window.innerWidth,
      h: window.innerHeight,
    };
  }

  function applyLayout() {
    if (!host) return;
    const vp = viewport();
    const w = Math.max(120, Math.min(layout.width, vp.w - MARGIN * 2));
    const h = Math.max(40, Math.min(layout.height, vp.h - MARGIN * 2));
    const x = clamp(position ? position.x : vp.w - w - DEFAULT_OFFSET, MARGIN, Math.max(MARGIN, vp.w - w - MARGIN));
    const y = clamp(position ? position.y : DEFAULT_OFFSET, MARGIN, Math.max(MARGIN, vp.h - h - MARGIN));
    important(host, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px` });

    const d = layout.dragHandle;
    important(handle, {
      left: `${d.x}px`, top: `${d.y}px`,
      width: `${Math.max(0, Math.min(d.width, w - d.x))}px`,
      height: `${Math.max(0, Math.min(d.height, h - d.y))}px`,
    });
  }

  function setLayout(data) {
    const d = data.dragHandle || {};
    layout = {
      width: num(data.width, 200, 1200, DEFAULT_LAYOUT.width),
      height: num(data.height, 40, 1400, DEFAULT_LAYOUT.height),
      minimized: Boolean(data.minimized),
      dragHandle: {
        x: num(d.x, 0, 1200, 0),
        y: num(d.y, 0, 1400, 0),
        width: num(d.width, 0, 1200, 0),
        height: num(d.height, 0, 1400, 0),
      },
    };
    applyLayout();
  }

  function savePosition() {
    if (!position) {
      chrome.storage.local.remove(POSITION_KEY).catch(() => {});
      return;
    }
    const rect = host ? host.getBoundingClientRect() : null;
    if (rect) position = { x: Math.round(rect.left), y: Math.round(rect.top) };
    chrome.storage.local.set({ [POSITION_KEY]: position }).catch(() => {});
  }

  function onPointerDown(event) {
    if (event.button !== 0 || !host) return;
    event.preventDefault();
    const rect = host.getBoundingClientRect();
    drag = { id: event.pointerId, dx: event.clientX - rect.left, dy: event.clientY - rect.top };
    handle.setPointerCapture(event.pointerId);
    important(handle, { cursor: 'grabbing' });
  }

  function onPointerMove(event) {
    if (!drag || event.pointerId !== drag.id) return;
    position = { x: event.clientX - drag.dx, y: event.clientY - drag.dy };
    applyLayout();
  }

  function onPointerUp(event) {
    if (!drag || event.pointerId !== drag.id) return;
    drag = null;
    important(handle, { cursor: 'grab' });
    savePosition();
  }

  window.addEventListener('resize', applyLayout);
  document.addEventListener('fullscreenchange', () => {
    showOnTop();
    applyLayout();
  });

  // ─── 화면 캡처 ───────────────────────────────────────────────

  const nextFrame = () => new Promise((r) => requestAnimationFrame(() => r()));

  async function capture(id) {
    if (capturing) {
      postToFrame({ type: 'llai-capture-result', id, error: '이미 캡처 중입니다.' });
      return;
    }
    capturing = true;
    let result;
    try {
      important(host, { visibility: 'hidden' }); // 위젯이 슬라이드를 가리지 않게 잠깐 숨긴다
      await nextFrame();
      await nextFrame();
      await new Promise((r) => setTimeout(r, 60));
      result = await chrome.runtime.sendMessage({ target: 'background', type: 'llai-capture' });
    } catch (err) {
      result = { error: err.message || String(err) };
    } finally {
      if (host) important(host, { visibility: 'visible' });
      capturing = false;
    }
    if (result && result.dataUrl) {
      try {
        result.dataUrl = await downscale(result.dataUrl, CAPTURE_MAX_SIDE);
      } catch (_) { /* 원본 그대로 보낸다 */ }
    }
    postToFrame({ type: 'llai-capture-result', id, dataUrl: result && result.dataUrl, error: result && result.error });
  }

  /** 레티나 화면 캡처는 4K 가까이 되므로 긴 변을 maxSide로 줄인다 (VLM 입력·전송량) */
  function downscale(dataUrl, maxSide) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
        if (scale >= 1) return resolve(dataUrl);
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(img.naturalWidth * scale);
        canvas.height = Math.round(img.naturalHeight * scale);
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL('image/jpeg', 0.85));
      };
      img.onerror = () => reject(new Error('image decode failed'));
      img.src = dataUrl;
    });
  }

  // ─── 메시지 ─────────────────────────────────────────────────

  function postToFrame(message) {
    if (frame && frame.contentWindow) frame.contentWindow.postMessage(message, EXT_ORIGIN);
  }

  // frame.html → 여기 (위젯이 보낸 메시지를 frame.html이 전달)
  window.addEventListener('message', (event) => {
    if (!frame || event.source !== frame.contentWindow || event.origin !== EXT_ORIGIN) return;
    const data = event.data || {};
    switch (data.type) {
      case 'llai-ready':
        if (audio) postToFrame({ type: 'llai-audio', state: audio.state, message: audio.message || '' });
        break;
      case 'llai-layout':
        setLayout(data);
        break;
      case 'llai-capture-request':
        capture(String(data.id || ''));
        break;
      default:
        break;
    }
  });

  // 서비스 워커 → 여기
  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (!msg || sender.id !== chrome.runtime.id) return undefined;
    switch (msg.type) {
      case 'llai-mount':
        mount(msg.session);
        sendResponse({ ok: true });
        break;
      case 'llai-unmount':
        unmount();
        sendResponse({ ok: true });
        break;
      case 'llai-ping':
        sendResponse({ mounted: Boolean(host) });
        break;
      case 'llai-audio':
        audio = { state: msg.state, message: msg.message || '' };
        postToFrame({ type: 'llai-audio', state: audio.state, message: audio.message });
        break;
      default:
        break;
    }
    return undefined;
  });

  // 이 탭이 강의 중이면(유튜브 새로고침 등) 바로 위젯을 띄운다
  chrome.runtime.sendMessage({ target: 'background', type: 'llai-hello' })
    .then((res) => { if (res && res.session) mount(res.session); })
    .catch(() => {});
})();
