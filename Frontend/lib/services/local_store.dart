import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 브라우저 localStorage에 저장하는 값 (위젯 설정, 자막 언어, 익명 클라이언트 ID)
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _clientIdKey = 'llai_client_id';
  static const _langKey = 'llai_caption_lang';
  static const _widgetKey = 'llai_widget_settings';

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  /// 브라우저마다 한 번 만드는 임의 ID. 이름·계정이 아니라 익명성은 유지되고,
  /// "내가 보낸 질문" 표시와 AI 대화 기록 분리에만 쓴다.
  String clientId() {
    final saved = _prefs.getString(_clientIdKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final rand = Random.secure();
    final id = List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _prefs.setString(_clientIdKey, id);
    return id;
  }

  String? captionLanguage() => _prefs.getString(_langKey);
  Future<void> saveCaptionLanguage(String code) => _prefs.setString(_langKey, code);

  Map<String, dynamic>? widgetSettings() {
    final raw = _prefs.getString(_widgetKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWidgetSettings(Map<String, dynamic> value) =>
      _prefs.setString(_widgetKey, jsonEncode(value));
}
