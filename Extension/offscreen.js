/*
 * offscreen 문서: 강의 탭의 오디오를 백엔드로 보낸다.
 *
 *  - 탭 오디오를 캡처하면 탭 소리가 사용자에게 안 들리므로, 원래 품질(기본 샘플레이트)로 다시 재생한다.
 *  - 별도의 16kHz AudioContext + AudioWorklet(pcm-worklet.js)이 100ms마다 16-bit PCM을 만들고 WebSocket으로 보낸다.
 *  - 15초마다 "ping"을 보내고, 45초 동안 "pong"이 없으면 연결을 끊고 다시 붙는다.
 *  - 끊기면 1·2·4·8·10초 간격으로 다시 연결하고, 그동안의 오디오는 최근 10초까지 모아 뒀다가 보낸다.
 *  - 상태(connecting / connected / reconnecting / error / stopped)는 서비스 워커로 알린다.
 */
const CFG = self.LLAI_CONFIG;
const SAMPLE_RATE = 16000;
const PING_MS = 15000;
const PONG_TIMEOUT_MS = 45000;
const MAX_PENDING_BYTES = SAMPLE_RATE * 2 * 10; // 끊긴 동안 모아 둘 오디오: 10초

let current = null; // { lectureId, wsUrl }
let stream = null;
let playCtx = null;
let procCtx = null;
let ws = null;
let active = false;
let retry = 0;
let pingTimer = null;
let retryTimer = null;
let lastPong = 0;
let pending = [];
let pendingBytes = 0;

function report(state, message = '') {
  if (!current) return;
  chrome.runtime.sendMessage({
    target: 'background',
    type: 'llai-audio-status',
    lectureId: current.lectureId,
    state,
    message,
  }).catch(() => {});
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!msg || msg.target !== 'offscreen' || sender.id !== chrome.runtime.id) return undefined;
  if (msg.type === 'start') {
    start(msg).then(
      () => sendResponse({ ok: true }),
      (err) => {
        teardown();
        sendResponse({ ok: false, error: err && err.message ? err.message : String(err) });
      },
    );
    return true;
  }
  if (msg.type === 'stop') {
    teardown();
    sendResponse({ ok: true });
  }
  return undefined;
});

async function start({ streamId, wsUrl, lectureId }) {
  teardown();
  current = { lectureId, wsUrl };
  active = true;

  stream = await navigator.mediaDevices.getUserMedia({
    audio: { mandatory: { chromeMediaSource: 'tab', chromeMediaSourceId: streamId } },
    video: false,
  });
  stream.getAudioTracks().forEach((track) => {
    track.onended = () => {
      if (!active) return;
      report('stopped', '탭 오디오 캡처가 끝났습니다.');
      teardown();
    };
  });

  // 1) 사용자가 계속 들을 수 있게 다시 재생
  playCtx = new AudioContext();
  playCtx.createMediaStreamSource(stream).connect(playCtx.destination);

  // 2) 16kHz 모노 PCM으로 바꿔 전송
  procCtx = new AudioContext({ sampleRate: SAMPLE_RATE });
  await procCtx.audioWorklet.addModule('pcm-worklet.js');
  const source = procCtx.createMediaStreamSource(stream);
  const pcm = new AudioWorkletNode(procCtx, 'llai-pcm16', {
    numberOfInputs: 1,
    numberOfOutputs: 1,
    channelCount: 1,
    channelCountMode: 'explicit',
    channelInterpretation: 'speakers',
  });
  pcm.port.onmessage = (event) => sendAudio(event.data);
  const mute = procCtx.createGain();
  mute.gain.value = 0; // 그래프가 계속 돌도록 출력에 연결만 하고 소리는 내지 않는다
  source.connect(pcm);
  pcm.connect(mute);
  mute.connect(procCtx.destination);
  await Promise.all([playCtx.resume(), procCtx.resume()]);

  report('connecting');
  connect();
}

function sendAudio(buffer) {
  if (!active) return;
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(buffer);
    return;
  }
  pending.push(buffer);
  pendingBytes += buffer.byteLength;
  while (pendingBytes > MAX_PENDING_BYTES && pending.length) {
    pendingBytes -= pending.shift().byteLength;
  }
}

function connect() {
  if (!active || !current) return;
  let socket;
  try {
    socket = new WebSocket(current.wsUrl);
  } catch (err) {
    scheduleReconnect(`연결 주소 오류: ${err.message}`);
    return;
  }
  ws = socket;
  socket.binaryType = 'arraybuffer';

  socket.onopen = () => {
    if (socket !== ws) return;
    retry = 0;
    lastPong = Date.now();
    for (const chunk of pending) socket.send(chunk);
    pending = [];
    pendingBytes = 0;
    clearInterval(pingTimer);
    pingTimer = setInterval(() => heartbeat(socket), PING_MS);
    report('connected');
  };

  socket.onmessage = (event) => {
    if (typeof event.data !== 'string') return;
    let msg = null;
    try {
      msg = JSON.parse(event.data);
    } catch (_) {
      return;
    }
    if (msg.type === 'pong' || msg.type === 'ready') lastPong = Date.now();
    if (msg.type === 'error') report('error', msg.message || '서버 오류');
  };

  socket.onclose = (event) => {
    if (socket !== ws) return;
    clearInterval(pingTimer);
    ws = null;
    if (!active) return;
    if (event.code === 4000 || event.code === 4001) {
      report('error', '서버가 연결을 거부했습니다 (강의 ID 형식 확인).');
      return;
    }
    scheduleReconnect('백엔드 서버(127.0.0.1:8000)에 다시 연결하는 중');
  };
}

function heartbeat(socket) {
  if (socket !== ws || socket.readyState !== WebSocket.OPEN) return;
  if (Date.now() - lastPong > PONG_TIMEOUT_MS) {
    socket.close(4002, 'heartbeat timeout'); // onclose에서 다시 연결
    return;
  }
  socket.send('ping');
}

function scheduleReconnect(message) {
  retry += 1;
  const delay = Math.min(10000, 1000 * 2 ** (retry - 1));
  report('reconnecting', `${message} · ${Math.round(delay / 1000)}초 후`);
  clearTimeout(retryTimer);
  retryTimer = setTimeout(connect, delay);
}

function teardown() {
  active = false;
  clearInterval(pingTimer);
  clearTimeout(retryTimer);
  if (ws) {
    const socket = ws;
    ws = null;
    try { socket.close(1000, 'stop'); } catch (_) { /* 이미 닫힘 */ }
  }
  if (stream) stream.getTracks().forEach((t) => t.stop());
  for (const ctx of [playCtx, procCtx]) {
    if (ctx) ctx.close().catch(() => {});
  }
  stream = playCtx = procCtx = null;
  pending = [];
  pendingBytes = 0;
  retry = 0;
  current = null;
}
