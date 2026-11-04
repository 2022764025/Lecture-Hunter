import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class CaptureCancelled implements Exception {}

class CaptureUnavailable implements Exception {
  final String message;
  CaptureUnavailable(this.message);
  @override
  String toString() => message;
}

/// 화면 공유 창에서 고른 화면/탭을 한 장 캡처해 data URL(JPEG)로 돌려준다.
///
/// 크롬 확장 iframe 안에서는 iframe에 allow="display-capture" 권한이 있어야 한다.
/// 사용자가 공유를 취소하면 [CaptureCancelled], 브라우저가 지원하지 않거나 막히면 [CaptureUnavailable].
Future<String> captureScreen({int maxSide = 1600}) async {
  web.MediaStream? stream;
  try {
    stream = await web.window.navigator.mediaDevices
        .getDisplayMedia(web.DisplayMediaStreamOptions(video: true.toJS, audio: false.toJS))
        .toDart;
  } catch (e) {
    final text = e.toString();
    if (text.contains('NotAllowedError') || text.contains('Permission denied')) {
      // 권한 정책(iframe allow)으로 막힌 경우도 NotAllowedError라 메시지로 구분한다
      if (text.contains('display-capture') || text.contains('permissions policy')) {
        throw CaptureUnavailable('이 페이지에서는 화면 캡처가 허용되지 않습니다.');
      }
      throw CaptureCancelled();
    }
    throw CaptureUnavailable('화면 캡처를 시작할 수 없습니다: $text');
  }

  try {
    final video = web.HTMLVideoElement()
      ..muted = true
      ..autoplay = true
      ..srcObject = stream;
    video.setAttribute('playsinline', 'true');
    await video.play().toDart;
    await Future<void>.delayed(const Duration(milliseconds: 200)); // 첫 프레임이 그려질 시간

    var w = video.videoWidth, h = video.videoHeight;
    if (w == 0 || h == 0) throw CaptureUnavailable('캡처한 화면이 비어 있습니다.');
    final scale = (w > h ? w : h) > maxSide ? maxSide / (w > h ? w : h) : 1.0;
    w = (w * scale).round();
    h = (h * scale).round();

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0, w, h);
    return canvas.toDataURL('image/jpeg', 0.85.toJS);
  } finally {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }
}

/// 화면 캡처를 쓸 수 없을 때 이미지 파일을 직접 고르게 한다. 취소하면 null.
Future<({String dataUrl, String name})?> pickImageFile() {
  final completer = Completer<({String dataUrl, String name})?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';

  void finish(({String dataUrl, String name})? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) return finish(null);
      final reader = web.FileReader();
      reader.addEventListener(
        'load',
        ((web.Event _) => finish((dataUrl: (reader.result as JSString).toDart, name: file.name))).toJS,
      );
      reader.addEventListener('error', ((web.Event _) => finish(null)).toJS);
      reader.readAsDataURL(file);
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
