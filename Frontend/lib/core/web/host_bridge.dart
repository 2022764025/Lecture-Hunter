import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

/// 위젯을 감싸는 페이지(크롬 확장의 frame.html)와 주고받는 메시지.
///
/// 위젯 → 부모 창
///   {type: 'llai-ready'}
///   {type: 'llai-layout', width, height, minimized, dragHandle: {x, y, width, height}}
///     iframe 크기를 위젯 크기에 맞추고, 드래그 손잡이(헤더의 로고·제목 영역)를 부모 창에 만든다.
///     iframe 안에서 드래그를 처리하면 iframe이 움직일 때 좌표가 같이 바뀌어 위젯이 떨리기 때문에
///     드래그는 부모 창이 직접 처리한다.
///   {type: 'llai-capture-request', id}   보이는 탭 화면 캡처 요청 (확장이 위젯을 잠깐 숨기고 찍는다)
///
/// 부모 창 → 위젯 (부모 창이 보낸 것만 받는다)
///   {type: 'llai-host', host: 'chrome-extension', features: [...]}   확장 안에서 실행 중
///   {type: 'llai-audio', state: connecting|connected|reconnecting|error, message}   탭 오디오 전송 상태
///   {type: 'llai-capture-result', id, dataUrl?, error?}
class HostBridge {
  HostBridge._();

  /// iframe(크롬 확장) 안에서 실행 중인지
  static final bool embedded = _detectEmbedded();

  static bool _detectEmbedded() {
    try {
      final top = web.window.top;
      if (top == null) return false;
      return !(top as JSAny).strictEquals(web.window as JSAny).toDart;
    } catch (_) {
      return true; // 다른 출처의 top에 접근이 막히면 iframe 안이다
    }
  }

  static final _messages = StreamController<Map<Object?, Object?>>.broadcast();
  static StreamSubscription<web.MessageEvent>? _sub;
  static final _hostFeatures = <String>{};
  static final _random = Random();

  /// 부모 창이 보낸 메시지 듣기 시작 (main에서 한 번)
  static void init() {
    if (!embedded || _sub != null) return;
    _sub = web.window.onMessage.listen((event) {
      final parent = web.window.parent;
      final source = event.source;
      if (parent == null || source == null || !(source as JSAny).strictEquals(parent as JSAny).toDart) return;
      final data = event.data.dartify();
      if (data is! Map || data['type'] is! String) return;
      if (data['type'] == 'llai-host') {
        final features = data['features'];
        if (features is List) _hostFeatures.addAll(features.whereType<String>());
      }
      _messages.add(data);
    });
  }

  /// 크롬 확장이 탭 화면 캡처를 해 줄 수 있는지 (llai-host 를 받은 뒤 true)
  static bool get canCaptureTab => _hostFeatures.contains('tab-capture');

  /// 크롬 확장이 보내는 탭 오디오 전송 상태
  static Stream<({String state, String message})> get audioStatus => _messages.stream
      .where((m) => m['type'] == 'llai-audio')
      .map((m) => (state: '${m['state'] ?? ''}', message: '${m['message'] ?? ''}'));

  static void post(Map<String, Object?> message) {
    if (!embedded) return;
    web.window.parent?.postMessage(message.jsify(), '*'.toJS);
  }

  static void ready() => post({'type': 'llai-ready'});

  static void layout({
    required double width,
    required double height,
    required bool minimized,
    required Rectangle dragHandle,
  }) {
    post({
      'type': 'llai-layout',
      'width': width.round(),
      'height': height.round(),
      'minimized': minimized,
      'dragHandle': {
        'x': dragHandle.x.round(),
        'y': dragHandle.y.round(),
        'width': dragHandle.width.round(),
        'height': dragHandle.height.round(),
      },
    });
  }

  /// 확장에게 지금 보이는 탭 화면을 찍어 달라고 한다. JPEG data URL을 돌려준다.
  static Future<String> captureTab({Duration timeout = const Duration(seconds: 15)}) async {
    if (!canCaptureTab) throw StateError('확장이 화면 캡처를 지원하지 않습니다.');
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}';
    final reply = _messages.stream
        .firstWhere((m) => m['type'] == 'llai-capture-result' && m['id'] == id)
        .timeout(timeout);
    post({'type': 'llai-capture-request', 'id': id});
    final result = await reply;
    final dataUrl = result['dataUrl'];
    if (dataUrl is String && dataUrl.startsWith('data:image/')) return dataUrl;
    throw StateError('${result['error'] ?? '화면 캡처 실패'}');
  }

  static void openUrl(String url) => web.window.open(url, '_blank', 'noopener');
}

class Rectangle {
  final double x, y, width, height;
  const Rectangle(this.x, this.y, this.width, this.height);
}
