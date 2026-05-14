// lib/screens/lecture_screen.dart
// [Step 4] 전체 통합 메인 스크린
// 자막 오버레이 + 질문 패널 + 용어집 + 연결 상태 모두 통합

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subtitle_provider.dart';
import '../widgets/subtitle_overlay_widget.dart';
import '../widgets/question_panel_widget.dart';
import '../widgets/connection_bar_widget.dart';

class LectureScreen extends ConsumerStatefulWidget {
  const LectureScreen({super.key});

  @override
  ConsumerState<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends ConsumerState<LectureScreen> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 SSE 연결 (Mock 모드)
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
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
    final questionPanelVisible = ref.watch(questionPanelVisibleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Stack(
          children: [
            // ── 배경 (실제 강의 영상 자리) ──────────────────────
            _LectureBackground(),

            // ── [Step 1] 자막 오버레이 ───────────────────────────
            const SubtitleOverlayWidget(),

            // ── [Step 2+3] 질문/용어집 패널 ─────────────────────
            if (questionPanelVisible)
              const Positioned(
                right: 12,
                top: 80,
                child: QuestionPanelWidget(),
              ),

            // ── 자막 숨김 시 복원 버튼 ──────────────────────────
            const ConnectionBarWidget(),

            // ── 디버그 컨트롤 바 (개발용) ────────────────────────
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _DevControlBar(),
            ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D0D1A),
            Color(0xFF111128),
            Color(0xFF0D0D1A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 80,
              color: Colors.white.withOpacity(0.06),
            ),
            const SizedBox(height: 16),
            Text(
              '강의 영상 영역',
              style: TextStyle(
                color: Colors.white.withOpacity(0.08),
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LiveLectureAI Overlay Demo',
              style: TextStyle(
                color: Colors.white.withOpacity(0.05),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 개발용 컨트롤 바 ─────────────────────────────────────────

class _DevControlBar extends ConsumerWidget {
  const _DevControlBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMock = ref.watch(mockModeProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final status = connectionStatus.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black54,
      child: Row(
        children: [
          // 앱 이름
          const Text(
            'LiveLectureAI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          // 모드 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMock
                  ? Colors.orangeAccent.withOpacity(0.3)
                  : Colors.greenAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isMock ? 'MOCK' : 'LIVE',
              style: TextStyle(
                color: isMock ? Colors.orangeAccent : Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Mock 모드 토글
          TextButton.icon(
            onPressed: () {
              final newMock = !isMock;
              ref.read(mockModeProvider.notifier).state = newMock;
              final sseService = ref.read(sseServiceProvider);
              if (newMock) {
                sseService.disconnect();
                sseService.startMock();
              } else {
                sseService.stopMock();
                sseService.connect();
              }
            },
            icon: Icon(
              isMock ? Icons.wifi_off : Icons.wifi,
              size: 14,
              color: Colors.white54,
            ),
            label: Text(
              isMock ? '실서버 연결' : 'Mock 모드',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          // 자막 히스토리 보기
          IconButton(
            onPressed: () => _showHistory(context, ref),
            icon: const Icon(Icons.history, color: Colors.white38, size: 18),
            tooltip: '자막 히스토리',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final history = ref.read(subtitleHistoryProvider);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          '자막 히스토리',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: history.isEmpty
              ? const Center(
                  child: Text(
                    '아직 자막이 없습니다',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withOpacity(0.05),
                  ),
                  itemBuilder: (_, i) {
                    final seg = history[history.length - 1 - i]; // 최신 순
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seg.originalText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (seg.translatedText != null)
                            Text(
                              seg.translatedText!,
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 11,
                              ),
                            ),
                          Text(
                            _formatTime(seg.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(subtitleHistoryProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: const Text('전체 삭제',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
