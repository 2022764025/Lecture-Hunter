import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 현재 테마 상태를 관리하는 Provider (기본값: 라이트모드로 변경 완료)
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light; // <-- dark를 light로 수정
});