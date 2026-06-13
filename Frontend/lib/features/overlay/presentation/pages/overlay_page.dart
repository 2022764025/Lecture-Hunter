// lib/screens/lecture_screen.dart
import 'dart:html' as html;
import 'dart:ui_web' as ui;
// [Step 4] 전체 통합 메인 스크린
// 자막 오버레이 + 질문 패널 + 용어집 + 연결 상태 모두 통합

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../caption/presentation/controllers/caption_controller.dart';
import '../widgets/lecture_result_strip.dart';

const String _lectureVideoViewType = 'lecture-shared-video-view';
bool _lectureVideoViewRegistered = false;

class OverlayPage extends ConsumerStatefulWidget {
  const OverlayPage({super.key});

  @override
  ConsumerState<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends ConsumerState<OverlayPage> {
  @override
  void initState() {
    super.initState();
    _registerLectureVideoView();

    // 앱 시작 시 SSE 연결 (Mock 모드)
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  void _registerLectureVideoView() {
    if (_lectureVideoViewRegistered) {
      return;
    }

    _lectureVideoViewRegistered = true;

    ui.platformViewRegistry.registerViewFactory(
      _lectureVideoViewType,
      (int viewId) {
        final video = html.VideoElement()
          ..id = 'lecture-shared-video'
          ..autoplay = true
          ..muted = true
          ..controls = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000000';

        video.setAttribute('playsinline', 'true');
        return video;
      },
    );
  }

  void _connect() {
    final isMock = ref.read(mockModeProvider);
    final sseService = ref.read(sseServiceProvider);

    if (isMock) {
      sseService.startMock();
    } else {
      sseService.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Stack(
          children: [
            // ── 배경 (실제 강의 영상 자리) ──────────────────────
            _LectureBackground(),

            // ── 최종 형태: 작은 우리 위젯 + 펼쳐지는 결과 스트립 ───
            const LectureFloatingWidget(),

            // ── 기존 패널형 자막/질문 UI는 최종 스트립 구조로 대체 ───
            // // const CaptionOverlay(),
            // // const StatusBar(),
            // if (questionPanelVisible)
            //   const Positioned(
            //     right: 12,
            //     top: 80,
            //     child: AssistantPanel(),
            //   ),

            // ── 디버그 컨트롤 바 (개발용) ────────────────────────
          ],
        ),
      ),
    );
  }
}

// ─── 강의 배경 (영상 자리 placeholder) ───────────────────────

class _LectureBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const HtmlElementView(
            viewType: _lectureVideoViewType,
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 개발용 컨트롤 바 ─────────────────────────────────────────



