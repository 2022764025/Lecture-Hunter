// lib/main.dart
// LiveLectureAI - 앱 진입점 (민재 동적 룸 파싱 + 여자친구 투명 테마 대통합)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:js' as js; // 자바스크립트 변수 접근용
import 'dart:html' as html; // 브라우저 주소창(URL) 파싱을 위한 웹 네이티브 임포트
import 'features/overlay/presentation/pages/overlay_page.dart';

String? globalLectureId;

void main() {
  // 1. index.html이 미리 대피시켜준 강의 ID가 있는지 먼저 체크
  String? lectureId = js.context['initialLectureId'] as String?;

  // 만약 자바스크립트 주입 값이 없다면 (LMS 크롬 확장 프로그램 인젝션 모드), 
  // background.js가 던져준 주소창 뒤의 ?room=xxx 파라미터를 동적으로 스캔하여 방 번호 획득!
  if (lectureId == null || lectureId.isEmpty) {
    final uri = Uri.parse(html.window.location.href);
    lectureId = uri.queryParameters['room']; 
  }

  // 로컬 디버깅 환경 등 두 군데 모두 값이 없을 때 최종 폴백될 실제 테스트 강의 ID 지정
  lectureId ??= 'lecture-715903747';

  globalLectureId = lectureId;

  print("==========================================================");
  print("[최종 연동 대성공] index.html 및 URL 파라미터 복원 완료 | 강의 방 ID: $globalLectureId");
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
      
      // 외부 LMS 강의창에 오버레이 되었을 때 사이트를 가리지 않도록 배경 도화지를 완전히 투명화
      scaffoldBackgroundColor: Colors.transparent,

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