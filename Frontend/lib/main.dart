// lib/main.dart
// LiveLectureAI - 앱 진입점

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/lecture_screen.dart';

void main() {
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
      home: const LectureScreen(),
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
      fontFamily: 'Pretendard', // 실제 사용 시 assets에 폰트 추가 필요
      scaffoldBackgroundColor: const Color(0xFF0D0D1A),

      // 텍스트 테마
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.white54),
      ),

      // 슬라이더 테마
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.blueAccent,
        inactiveTrackColor: Colors.white12,
        thumbColor: Colors.blueAccent,
        overlayColor: Colors.blueAccent.withOpacity(0.2),
      ),

      // 스위치 테마
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white38,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.blueAccent
              : Colors.white12,
        ),
      ),
    );
  }
}
