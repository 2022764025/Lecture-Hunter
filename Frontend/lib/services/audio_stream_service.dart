import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/app_config.dart';

enum AudioConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class AudioStreamService {
  static const String _wsBaseUrl = AppConfig.wsBaseUrl;

  WebSocketChannel? _channel;
  StreamController<AudioConnectionStatus>? _statusController;

  bool _isConnected = false;
  String? _lectureId;
  String _targetLang = AppConfig.defaultTargetLang;

  Stream<AudioConnectionStatus> get statusStream =>
      _statusController?.stream ?? const Stream.empty();

  bool get isConnected => _isConnected;

  Future<void> connect({
    required String lectureId,
    String targetLang = AppConfig.defaultTargetLang,
  }) async {
    disconnect();

    _lectureId = lectureId;
    _targetLang = targetLang;
    _statusController ??= StreamController<AudioConnectionStatus>.broadcast();
    _statusController?.add(AudioConnectionStatus.connecting);

    try {
      final uri = Uri.parse('$_wsBaseUrl/ws/audio/$lectureId').replace(
        queryParameters: {
          'target_lang': targetLang,
        },
      );

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _isConnected = true;
      _statusController?.add(AudioConnectionStatus.connected);

      _channel!.stream.listen(
        (_) {},
        onError: (_) {
          _isConnected = false;
          _statusController?.add(AudioConnectionStatus.error);
        },
        onDone: () {
          _isConnected = false;
          _statusController?.add(AudioConnectionStatus.disconnected);
        },
      );
    } catch (_) {
      _isConnected = false;
      _statusController?.add(AudioConnectionStatus.error);
    }
  }

  /// 마이크 입력 연결 지점
  ///
  /// 추후 마이크 캡처 기능에서 생성한 audio chunk를 이 함수로 전달하면
  /// 백엔드 WebSocket(`/ws/audio/{lecture_id}`)으로 전송된다.
  ///
  /// Frontend 담당:
  /// - 마이크 권한 요청
  /// - 오디오 chunk 생성
  /// - sendAudioBytes(audioChunk) 호출
  ///
  /// Backend 담당:
  /// - WebSocket bytes 수신
  /// - VAD/STT/번역 처리
  /// - Supabase Realtime 자막 broadcast
  void sendAudioBytes(List<int> audioBytes) {
    if (!_isConnected || _channel == null || audioBytes.isEmpty) return;

    _channel!.sink.add(Uint8List.fromList(audioBytes));
  }

  Future<void> reconnect() async {
    final lectureId = _lectureId;
    if (lectureId == null) return;

    await connect(
      lectureId: lectureId,
      targetLang: _targetLang,
    );
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    _statusController?.add(AudioConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController?.close();
    _statusController = null;
  }
}
