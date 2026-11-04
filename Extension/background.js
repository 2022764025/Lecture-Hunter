/*
 * Lecture-Hunter 확장 서비스 워커
 *
 * 툴바 아이콘을 누르면
 *   1) 그 탭의 오디오를 캡처할 권한(streamId)을 받고
 *   2) offscreen 문서가 탭 오디오를 16kHz PCM으로 바꿔 백엔드 WebSocket(/ws/audio/{lecture_id})으로 보내고
 *   3) 탭 위에 위젯(content.js → frame.html → http://127.0.0.1:9998)을 띄운다.
 * 같은 탭에서 다시 누르면 강의를 끝낸다 (전체 요약 저장: POST /lecture/end).
 *
 * 한 번에 한 탭만 강의로 잡는다 (로컬 Whisper가 두 강의를 동시에 처리하지 못한다).
 * 서비스 워커는 수시로 꺼졌다 켜지므로 진행 중인 강의 정보는 chrome.storage.session에 둔다.
 */
importScripts('config.js');

const CFG = self.LLAI_CONFIG;
const OFFSCREEN_URL = 'offscreen.html';

// ─── 강의 세션 저장 ─────────────────────────────────────────────

async function getSession() {
  return (await chrome.storage.session.get('session')).session || null;
}

async function setSession(session) {
  if (session) await chrome.storage.session.set({ session });
  else await chrome.storage.session.remove('session');
}

/** 위젯(페이지 쪽)에 넘기는 정보. 탭 ID 같은 내부 값은 빼고 보낸다. */
function publicSession(s) {
  return { lectureId: s.lectureId, title: s.title, videoId: s.videoId, audio: s.audio };
}

// ─── 툴바 아이콘 ───────────────────────────────────────────────

chrome.action.onClicked.addListener((tab) => {
  toggle(tab).catch((err) => {
    console.warn('[Lecture-Hunter]', err);
    notify(tab.id, err.message || String(err));
  });
});

async function toggle(tab) {
  const current = await getSession();
  if (current && current.tabId === tab.id) {
    // 새로고침 등으로 위젯만 사라졌으면 다시 띄우고, 떠 있으면 강의를 끝낸다
    if (await isMounted(tab.id)) await stopSession('user');
    else await mountWidget(tab.id, current);
    return;
  }
  if (current) await stopSession('switch');
  await startSession(tab);
}

class UserError extends Error {}

function youtubeVideoId(url) {
  try {
    const u = new URL(url);
    if (!/(^|\.)youtube\.com$/.test(u.hostname) && u.hostname !== 'youtu.be') return null;
    const id = u.hostname === 'youtu.be'
      ? u.pathname.slice(1)
      : u.searchParams.get('v') || (u.pathname.match(/^\/(?:live|shorts|embed)\/([^/?]+)/) || [])[1];
    return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : null;
  } catch (_) {
    return null;
  }
}

function stamp(date = new Date()) {
  const two = (v) => String(v).padStart(2, '0');
  return `${date.getFullYear()}${two(date.getMonth() + 1)}${two(date.getDate())}-` +
    `${two(date.getHours())}${two(date.getMinutes())}${two(date.getSeconds())}`;
}

/** "(3) 딥러닝 기초 - YouTube" → "딥러닝 기초" */
function cleanTitle(title) {
  return (title || '')
    .replace(/^\(\d+\)\s*/, '')
    .replace(/\s*-\s*YouTube$/, '')
    .trim()
    .slice(0, 200);
}

async function startSession(tab) {
  const url = tab.url || '';
  if (!/^https?:\/\//.test(url) || /^https:\/\/(chromewebstore\.google\.com|chrome\.google\.com\/webstore)/.test(url)) {
    throw new UserError('이 페이지에서는 위젯을 띄울 수 없어요. 유튜브 같은 일반 웹페이지에서 눌러 주세요.');
  }

  // 아이콘을 누른 직후에만 받을 수 있다 (activeTab). 다른 일보다 먼저 받아 둔다.
  let streamId;
  try {
    streamId = await chrome.tabCapture.getMediaStreamId({ targetTabId: tab.id });
  } catch (err) {
    throw new UserError(`탭 오디오를 가져올 권한을 받지 못했어요: ${err.message}`);
  }

  const videoId = youtubeVideoId(url);
  const session = {
    tabId: tab.id,
    windowId: tab.windowId,
    lectureId: `${videoId ? `yt-${videoId}` : 'tab'}-${stamp()}`,
    title: cleanTitle(tab.title) || (videoId ? `유튜브 강의 ${videoId}` : '실시간 강의'),
    videoId,
    startedAt: Date.now(),
    audio: { state: 'connecting', message: '' },
  };
  await setSession(session);
  await setBadge(tab.id, 'connecting');

  const query = new URLSearchParams({ title: session.title });
  const wsUrl = `${CFG.BACKEND_WS}/ws/audio/${encodeURIComponent(session.lectureId)}?${query}`;
  try {
    await ensureOffscreen();
    const res = await sendToOffscreen({ type: 'start', streamId, wsUrl, lectureId: session.lectureId });
    if (!res || !res.ok) throw new Error(res && res.error ? res.error : 'offscreen 응답 없음');
  } catch (err) {
    await stopSession('error');
    throw new UserError(`탭 오디오 캡처를 시작하지 못했어요: ${err.message}`);
  }

  await mountWidget(tab.id, session);
  console.log('[Lecture-Hunter] 강의 시작', session.lectureId, session.title);
}

async function stopSession(reason) {
  const s = await getSession();
  if (!s) return;
  await setSession(null);
  try {
    await sendToOffscreen({ type: 'stop' }, 1);
  } catch (_) { /* 이미 닫힘 */ }
  await closeOffscreen();
  chrome.tabs.sendMessage(s.tabId, { type: 'llai-unmount' }).catch(() => {});
  await setBadge(s.tabId, null);
  console.log('[Lecture-Hunter] 강의 종료', s.lectureId, reason);

  // 전체 요약을 만들어 저장한다 (몇십 초 걸릴 수 있어 기다리지 않는다)
  if (reason !== 'error') {
    fetch(`${CFG.BACKEND_HTTP}/lecture/end?lecture_id=${encodeURIComponent(s.lectureId)}`, { method: 'POST' })
      .then((r) => console.log('[Lecture-Hunter] 전체 요약 저장', r.status))
      .catch((e) => console.warn('[Lecture-Hunter] 전체 요약 저장 실패', e.message));
  }
}

// ─── 위젯 (content script) ─────────────────────────────────────

async function mountWidget(tabId, session) {
  // 유튜브는 manifest의 content_scripts로 이미 들어가 있고, 다른 사이트는 여기서 넣는다 (중복 실행은 content.js가 막는다)
  await chrome.scripting.executeScript({ target: { tabId }, files: ['content.js'] });
  await chrome.tabs.sendMessage(tabId, { type: 'llai-mount', session: publicSession(session) });
}

async function isMounted(tabId) {
  try {
    const res = await chrome.tabs.sendMessage(tabId, { type: 'llai-ping' });
    return Boolean(res && res.mounted);
  } catch (_) {
    return false;
  }
}

/** 위젯을 띄우지 못할 때 페이지에 짧은 안내를 띄운다. 페이지에 못 넣으면 아이콘 배지·툴팁으로 알린다. */
async function notify(tabId, message) {
  await setBadge(tabId, 'error', message);
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      args: [message],
      func: (text) => {
        const id = 'llai-lecture-hunter-toast';
        document.getElementById(id)?.remove();
        const el = document.createElement('div');
        el.id = id;
        el.textContent = `Lecture-Hunter · ${text}`;
        el.style.cssText = 'position:fixed;top:20px;right:20px;z-index:2147483647;max-width:360px;padding:12px 16px;' +
          'border-radius:12px;background:#2f3a33;color:#fff;font:14px/1.5 system-ui,sans-serif;box-shadow:0 8px 24px rgba(0,0,0,.3)';
        document.documentElement.appendChild(el);
        setTimeout(() => el.remove(), 6000);
      },
    });
  } catch (_) { /* chrome:// 같은 페이지 */ }
}

// ─── 배지 ─────────────────────────────────────────────────────

const BADGE = {
  connecting: { text: '…', color: '#C8963E', title: '오디오 연결 중' },
  connected: { text: 'ON', color: '#5E7F69', title: '탭 오디오 전송 중 · 아이콘을 다시 누르면 강의를 끝냅니다' },
  reconnecting: { text: '…', color: '#C8963E', title: '백엔드에 다시 연결하는 중' },
  error: { text: '!', color: '#C0564B', title: '' },
};

async function setBadge(tabId, state, message = '') {
  try {
    const b = BADGE[state];
    await chrome.action.setBadgeText({ tabId, text: b ? b.text : '' });
    if (b) await chrome.action.setBadgeBackgroundColor({ tabId, color: b.color });
    await chrome.action.setTitle({
      tabId,
      title: b ? `Lecture-Hunter · ${message || b.title}` : 'Lecture-Hunter 켜기 / 끄기',
    });
  } catch (_) { /* 탭이 닫힘 */ }
}

// ─── offscreen 문서 (탭 오디오 → WebSocket) ───────────────────────

let creatingOffscreen = null;

async function hasOffscreen() {
  const contexts = await chrome.runtime.getContexts({ contextTypes: ['OFFSCREEN_DOCUMENT'] });
  return contexts.length > 0;
}

async function ensureOffscreen() {
  if (await hasOffscreen()) return;
  if (!creatingOffscreen) {
    creatingOffscreen = chrome.offscreen.createDocument({
      url: OFFSCREEN_URL,
      reasons: ['USER_MEDIA'],
      justification: '강의 탭의 오디오를 받아 로컬 음성 인식 서버로 보냅니다.',
    }).finally(() => { creatingOffscreen = null; });
  }
  await creatingOffscreen;
}

async function closeOffscreen() {
  try {
    if (await hasOffscreen()) await chrome.offscreen.closeDocument();
  } catch (_) { /* 이미 닫힘 */ }
}

/** offscreen 문서가 막 만들어졌으면 메시지 수신 준비가 늦을 수 있어 몇 번 다시 보낸다 */
async function sendToOffscreen(message, attempts = 5) {
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      return await chrome.runtime.sendMessage({ target: 'offscreen', ...message });
    } catch (err) {
      lastError = err;
      await new Promise((r) => setTimeout(r, 150));
    }
  }
  throw lastError;
}

// ─── 메시지 (content script · offscreen → 여기) ───────────────────

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.target !== 'background' || sender.id !== chrome.runtime.id) return undefined;

  switch (msg.type) {
    case 'llai-hello':
      // content script가 페이지에 들어왔을 때: 이 탭이 강의 중이면 위젯을 띄우게 한다 (유튜브 새로고침 등)
      getSession().then((s) => {
        const mine = s && sender.tab && s.tabId === sender.tab.id;
        sendResponse({ session: mine ? publicSession(s) : null });
      });
      return true;

    case 'llai-capture':
      captureTab(sender.tab).then(sendResponse);
      return true;

    case 'llai-audio-status':
      onAudioStatus(msg);
      return undefined;

    default:
      return undefined;
  }
});

async function captureTab(tab) {
  const s = await getSession();
  if (!tab || !s || s.tabId !== tab.id) return { error: '강의 중인 탭이 아닙니다.' };
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, { format: 'jpeg', quality: 85 });
    return { dataUrl };
  } catch (err) {
    return { error: err.message || String(err) };
  }
}

async function onAudioStatus({ lectureId, state, message }) {
  const s = await getSession();
  if (!s || s.lectureId !== lectureId) return;

  if (state === 'stopped') {
    // 탭 오디오 캡처가 스스로 끝났다 (탭이 닫히거나 캡처가 끊김)
    await stopSession('capture-ended');
    return;
  }
  s.audio = { state, message: message || '' };
  await setSession(s);
  await setBadge(s.tabId, state === 'error' ? 'error' : state, message);
  chrome.tabs.sendMessage(s.tabId, { type: 'llai-audio', state, message: message || '' }).catch(() => {});
}

// ─── 탭 이벤트 ─────────────────────────────────────────────────

chrome.tabs.onRemoved.addListener(async (tabId) => {
  const s = await getSession();
  if (s && s.tabId === tabId) await stopSession('tab-closed');
});

chrome.tabs.onUpdated.addListener(async (tabId, info) => {
  if (info.status !== 'complete') return;
  const s = await getSession();
  if (!s || s.tabId !== tabId) return;
  // 페이지를 새로 불러왔으면 위젯을 다시 띄운다. 권한이 없는 사이트면 아이콘을 다시 누르라고 알린다.
  try {
    await mountWidget(tabId, s);
  } catch (_) {
    await setBadge(tabId, 'error', '페이지가 바뀌어 위젯이 사라졌어요. 아이콘을 누르면 다시 띄웁니다.');
  }
});

// 브라우저를 다시 켰거나 확장을 다시 불러오면 offscreen 문서가 없으므로 남은 세션 정보를 지운다
(async () => {
  const s = await getSession();
  if (s && !(await hasOffscreen())) await setSession(null);
})();
