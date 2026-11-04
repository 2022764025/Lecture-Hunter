import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// web/index.html 의 window.llaiAudio (마이크 · 탭 오디오 공유 · 유튜브 서버 수집) 를 부르는 브리지.
///
/// 크롬 확장으로 쓸 때는 확장의 offscreen 문서가 탭 오디오를 보내므로 이 브리지를 쓰지 않는다.
/// 위젯을 단독으로 열었을 때(개발·시연) 강의 음성을 백엔드로 보내는 경로다.
///   mic     : 마이크 입력 (트랙 A, 오프라인 강의실)
///   tab     : 화면/탭 공유의 오디오 (트랙 A, 시스템 오디오)
///   youtube : 오디오는 서버가 yt-dlp로 직접 받고, 브라우저는 연결만 유지 (트랙 B)
@JS('llaiAudio.start')
external JSPromise<JSAny?> _start(JSString mode, JSString wsUrl);

@JS('llaiAudio.stop')
external void _stop();

enum AudioBridgeState { idle, starting, connected, reconnecting, ended, error }

class AudioBridgeEvent {
  final AudioBridgeState state;
  final String message;
  const AudioBridgeEvent(this.state, [this.message = '']);
}

class AudioBridge {
  AudioBridge() {
    _sub = web.window.onMessage.listen(_onMessage);
  }

  final _events = StreamController<AudioBridgeEvent>.broadcast();
  late final StreamSubscription<web.MessageEvent> _sub;

  Stream<AudioBridgeEvent> get events => _events.stream;

  void _onMessage(web.MessageEvent event) {
    // index.html 의 llaiAudio 가 같은 창에 보낸 것만 받는다 (부모 창·다른 iframe 메시지는 무시)
    final source = event.source;
    if (source == null || !(source as JSAny).strictEquals(web.window as JSAny).toDart) return;
    final data = event.data.dartify();
    if (data is! Map || data['source'] != 'llai-audio') return;
    final message = (data['message'] ?? '').toString();
    final state = switch (data['state']) {
      'connected' => AudioBridgeState.connected,
      'reconnecting' => AudioBridgeState.reconnecting,
      'ended' => AudioBridgeState.ended,
      'error' => AudioBridgeState.error,
      'stopped' => AudioBridgeState.idle,
      _ => null,
    };
    if (state != null) _events.add(AudioBridgeEvent(state, message));
  }

  Future<void> start({required String mode, required String wsUrl}) async {
    _events.add(const AudioBridgeEvent(AudioBridgeState.starting));
    try {
      await _start(mode.toJS, wsUrl.toJS).toDart;
    } catch (e) {
      final text = e.toString().replaceFirst('Error: ', '');
      _events.add(AudioBridgeEvent(AudioBridgeState.error, text));
      rethrow;
    }
  }

  void stop() => _stop();

  void dispose() {
    _sub.cancel();
    _events.close();
  }
}
