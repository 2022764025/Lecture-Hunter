import 'dart:async';
import 'dart:html' as html;

import 'audio_stream_service.dart';

class DisplayAudioCaptureService {
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;

  Future<void> start({
    required AudioStreamService audioStreamService,
    required String lectureId,
    required String targetLang,
  }) async {
    if (_isCapturing) return;

    await audioStreamService.connect(
      lectureId: lectureId,
      targetLang: targetLang,
    );

    final completer = Completer<void>();

    _messageSub?.cancel();
    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;

      final type = data['type']?.toString();

      if (type == 'lecture_capture_started') {
        _isCapturing = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }

      if (type == 'lecture_capture_error') {
        stop(audioStreamService: audioStreamService);
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(data['message']?.toString() ?? '강의 화면 연결 실패'),
          );
        }
      }

      if (type == 'lecture_capture_stopped') {
        stop(audioStreamService: audioStreamService);
      }
    });

    html.window.postMessage({
      'type': 'lecture_capture_start',
    }, '*');

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        stop(audioStreamService: audioStreamService);
        throw Exception('강의 화면 연결 시간이 초과되었습니다.');
      },
    );
  }

  void stop({
    required AudioStreamService audioStreamService,
  }) {
    _isCapturing = false;
    _messageSub?.cancel();
    _messageSub = null;

    html.window.postMessage({
      'type': 'lecture_capture_stop',
    }, '*');

    audioStreamService.disconnect();
  }
}
