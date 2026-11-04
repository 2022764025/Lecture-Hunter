import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';

// ─── 위젯 설정 (설정 탭) ───────────────────────────────────────

/// 과제헌터.html 설정 항목과 같은 범위
class WidgetSettings {
  final int opacity;   // 배경 불투명도 % (0~100). 글자는 그대로 보인다
  final int width;     // px (280~700)
  final int height;    // px (400~950)
  final int textSize;  // 전체 글자 크기 % (60~180)

  const WidgetSettings({this.opacity = 100, this.width = 420, this.height = 640, this.textSize = 100});

  static const ranges = {
    'opacity': (min: 0, max: 100),
    'width': (min: 280, max: 700),
    'height': (min: 400, max: 950),
    'textSize': (min: 60, max: 180),
  };

  int get(String key) => switch (key) {
        'opacity' => opacity,
        'width' => width,
        'height' => height,
        _ => textSize,
      };

  WidgetSettings with_(String key, int value) {
    final r = ranges[key]!;
    final v = value.clamp(r.min, r.max);
    return WidgetSettings(
      opacity: key == 'opacity' ? v : opacity,
      width: key == 'width' ? v : width,
      height: key == 'height' ? v : height,
      textSize: key == 'textSize' ? v : textSize,
    );
  }

  Map<String, dynamic> toJson() => {'opacity': opacity, 'width': width, 'height': height, 'textSize': textSize};

  factory WidgetSettings.fromJson(Map<String, dynamic>? json) {
    var s = const WidgetSettings();
    for (final key in ranges.keys) {
      final v = json?[key];
      if (v is num) s = s.with_(key, v.round());
    }
    return s;
  }
}

class WidgetSettingsController extends Notifier<WidgetSettings> {
  Timer? _saveTimer;

  @override
  WidgetSettings build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return WidgetSettings.fromJson(ref.read(localStoreProvider).widgetSettings());
  }

  void set(String key, int value) {
    state = state.with_(key, value);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(localStoreProvider).saveWidgetSettings(state.toJson());
    });
  }
}

final widgetSettingsProvider = NotifierProvider<WidgetSettingsController, WidgetSettings>(WidgetSettingsController.new);

// ─── 탭·최소화 ────────────────────────────────────────────────

enum WidgetTab { caption, question, notice, summary, settings }

extension WidgetTabLabel on WidgetTab {
  String get label => const ['자막', '질문', '공지', '요약', '설정'][index];
}

/// 주소창 ?tab=caption|question|notice|summary|settings 로 처음 열 탭을 고를 수 있다 (시연·화면 캡처용)
final widgetTabProvider = StateProvider<WidgetTab>((ref) {
  final name = Uri.base.queryParameters['tab'];
  return WidgetTab.values.firstWhere((t) => t.name == name, orElse: () => WidgetTab.caption);
});
final minimizedProvider = StateProvider<bool>((ref) => Uri.base.queryParameters['minimized'] == '1');

/// 질문 탭 안의 하위 탭: 0 = 익명 질문, 1 = 용어집 조회 (?sub=glossary)
final questionSubTabProvider = StateProvider<int>((ref) => Uri.base.queryParameters['sub'] == 'glossary' ? 1 : 0);

// ─── 토스트 (디자인의 화면 하단 안내 문구) ─────────────────────

class ToastController extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String message) {
    state = message;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2800), () => state = null);
  }
}

final toastProvider = NotifierProvider<ToastController, String?>(ToastController.new);
