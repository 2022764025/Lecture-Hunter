import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:math'; // 추가됨
import 'dart:typed_data'; // 추가됨

class AudioService {
    final _recorder = AudioRecorder();
    WebSocketChannel? _channel;

    // [정확도 개선] 소리 감지 임계값 (20.0~30.0 사이에서 본인 마이크에 맞게 조절)
    final double threshold = 40.0; 

    Future<void> startStreaming(String lectureId) async {
        final url = Uri.parse('ws://127.0.0.1:8000/ws/audio/$lectureId');
        _channel = WebSocketChannel.connect(url);

        const config = RecordConfig(
            encoder: AudioEncoder.pcm16bits, 
            sampleRate: 16000, 
            numChannels: 1
        );

        if (await _recorder.hasPermission()) {
            final stream = await _recorder.startStream(config);

            stream.listen((data) {
                // 1. 오디오 데이터(Uint8List)의 실효치(RMS) 계산
                double rms = _calculateRMS(data);
                
                // 2. RMS를 데시벨(dB)로 변환
                double db = 20 * log(rms + 1) / ln10;

                // 3. 임계치 이상의 소리가 날 때만 서버로 전송 (VAD 적용)
                if (db > threshold) {
                    _channel?.sink.add(data);
                } else {
                    // 소리가 작으면 전송하지 않음 (서버 리소스 및 네트워크 절약)
                    // 테스트할 때는 아래 주석을 풀어서 데시벨을 확인해보세요.
                    print("Silent... (dB: ${db.toStringAsFixed(2)})");
                }
            });
        }
    }

    // RMS 계산용 헬퍼 함수
    double _calculateRMS(Uint8List data) {
        double sum = 0;
        for (int i = 0; i < data.length; i += 2) {
            // 16-bit PCM 데이터를 정수로 변환 (Little-endian 방식)
            int sample = data[i] | (data[i + 1] << 8);
            if (sample > 32767) sample -= 65536;
            sum += sample * sample;
        }
        return sqrt(sum / (data.length / 2));
    }

    Future<void> stopStreaming() async {
        await _recorder.stop();
        await _channel?.sink.close();
        _channel = null;
    }
}