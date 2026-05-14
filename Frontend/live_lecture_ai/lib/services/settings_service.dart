// lib/services/settings_service.dart
// 자막 설정 로컬 저장 (SharedPreferences)

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subtitle_model.dart';

class SettingsService {
  static const String _key = 'subtitle_settings';

  Future<SubtitleSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return const SubtitleSettings();

    try {
      return SubtitleSettings.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SubtitleSettings();
    }
  }

  Future<void> save(SubtitleSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
