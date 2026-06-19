let ws, audioCtx, processor, source, stream, silentGain;

chrome.runtime.onMessage.addListener(async (msg) => {
  if (msg.type === "start-capture") {
    stream = await navigator.mediaDevices.getUserMedia({
      audio: { mandatory: { chromeMediaSource: "tab", chromeMediaSourceId: msg.streamId } }
    });

    ws = new WebSocket(`${msg.wsBase}/${msg.lectureId}?target_lang=Korean`);
    ws.binaryType = "arraybuffer";

    audioCtx = new AudioContext({ sampleRate: 16000 });
    source = audioCtx.createMediaStreamSource(stream);
    processor = audioCtx.createScriptProcessor(4096, 1, 1);
    silentGain = audioCtx.createGain();
    silentGain.gain.value = 0;

    // 원본 소리는 그대로 스피커로 (캡처해도 학생이 강의 소리 계속 들림)
    source.connect(audioCtx.destination);
    // 분석/전송용 경로는 무음 처리
    source.connect(processor);
    processor.connect(silentGain);
    silentGain.connect(audioCtx.destination);

    processor.onaudioprocess = (e) => {
      if (ws.readyState !== WebSocket.OPEN) return;
      const input = e.inputBuffer.getChannelData(0);
      const pcm16 = new Int16Array(input.length);
      for (let i = 0; i < input.length; i++) {
        const s = Math.max(-1, Math.min(1, input[i]));
        pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
      }
      ws.send(pcm16.buffer);
    };
  }

  if (msg.type === "stop-capture") {
    processor?.disconnect();
    source?.disconnect();
    silentGain?.disconnect();
    audioCtx?.close();
    stream?.getTracks().forEach((t) => t.stop());
    ws?.close();
  }
});
