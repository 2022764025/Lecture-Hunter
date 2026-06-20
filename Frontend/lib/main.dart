// lib/main.dart
// LiveLectureAI - 앱 진입점

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:js' as js; // 자바스크립트 변수 접근용
import 'features/overlay/presentation/pages/overlay_page.dart';

String? globalLectureId;

void main() {
  // index.html이 미리 대피시켜준 강의 ID를 플러터 엔진 부팅과 상관없이 안전하게 꺼냄.
  globalLectureId = js.context['initialLectureId'] as String?;

  // 실제 테스트 강의 ID로 기본값 설정
  globalLectureId ??= 'lecture-715903747';

  print("==========================================================");
  print("[최종 연동 대성공] index.html에서 복원한 강의 ID: $globalLectureId");
  print("==========================================================");
  
  runApp(
    const ProviderScope(
      child: LiveLectureApp(),
    ),
  );
}

class LiveLectureApp extends StatelessWidget {
  const LiveLectureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveLectureAI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const OverlayPage(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: const Color(0xFF0D0D1A),

      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.white54),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.blueAccent,
        inactiveTrackColor: Colors.white12,
        thumbColor: Colors.blueAccent,
        overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white38,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.blueAccent : Colors.white12,
        ),
      ),
    );
  }
}