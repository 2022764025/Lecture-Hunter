/*
 * 오디오 스레드에서 Float32 샘플을 16-bit PCM으로 바꿔 100ms(1,600샘플)씩 묶어 보낸다.
 * AudioContext를 16kHz로 만들어 쓰므로 리샘플은 브라우저가 한다.
 * 채널은 노드 옵션(channelCount: 1, explicit)으로 모노로 섞여 들어온다.
 */
class Pcm16Processor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.chunk = new Int16Array(1600);
    this.filled = 0;
  }

  process(inputs) {
    const channel = inputs[0] && inputs[0][0];
    if (channel) {
      for (let i = 0; i < channel.length; i++) {
        const s = Math.max(-1, Math.min(1, channel[i]));
        this.chunk[this.filled++] = s < 0 ? s * 0x8000 : s * 0x7fff;
        if (this.filled === this.chunk.length) {
          this.port.postMessage(this.chunk.buffer, [this.chunk.buffer]);
          this.chunk = new Int16Array(1600);
          this.filled = 0;
        }
      }
    }
    return true;
  }
}

registerProcessor('llai-pcm16', Pcm16Processor);
