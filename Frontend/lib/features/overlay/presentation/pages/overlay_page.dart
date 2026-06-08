// lib/screens/lecture_screen.dart
import 'dart:html' as html;
import 'dart:typed_data';
// [Step 4] 전체 통합 메인 스크린
// 자막 오버레이 + 질문 패널 + 용어집 + 연결 상태 모두 통합

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../caption/presentation/controllers/caption_controller.dart';
import '../../../caption/presentation/widgets/caption_overlay.dart';
import '../../../assistant/presentation/panels/assistant_panel.dart';
import '../widgets/status_bar.dart';
import '../../../../services/api_service.dart';
import '../../../../services/display_audio_capture_service.dart';
import '../../../assistant/presentation/controllers/question_model.dart';

class OverlayPage extends ConsumerStatefulWidget {
  const OverlayPage({super.key});

  @override
  ConsumerState<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends ConsumerState<OverlayPage> {
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
            const CaptionOverlay(),

            // ── [Step 2+3] 질문/용어집 패널 ─────────────────────
            if (questionPanelVisible)
              const Positioned(
                right: 12,
                top: 80,
                child: AssistantPanel(),
              ),

            // ── 자막 숨김 시 복원 버튼 ──────────────────────────
            const StatusBar(),

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
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 16),
            Text(
              '강의 영상 영역',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LiveLectureAI Overlay Demo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.05),
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
                  ? Colors.orangeAccent.withValues(alpha: 0.3)
                  : Colors.greenAccent.withValues(alpha: 0.3),
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
            onPressed: () async {
              final newMock = !isMock;
              ref.read(mockModeProvider.notifier).state = newMock;
              final sseService = ref.read(sseServiceProvider);
              if (newMock) {
                sseService.disconnect();
                sseService.startMock();
              } else {
                sseService.stopMock();
                await sseService.connect();
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
          // 핵심 요약 보기
          TextButton.icon(
            onPressed: () => _showSummary(context),
            icon: const Icon(
              Icons.summarize,
              size: 14,
              color: Colors.white54,
            ),
            label: const Text(
              '핵심 요약',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          // 강의 화면 연결
          TextButton.icon(
            onPressed: () => _connectLectureScreen(context, ref),
            icon: const Icon(
              Icons.cast_connected,
              size: 14,
              color: Colors.white54,
            ),
            label: const Text(
              '강의 화면 연결',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          // 슬라이드 분석
          TextButton.icon(
            onPressed: () => _analyzeSlide(context),
            icon: const Icon(
              Icons.image_search,
              size: 14,
              color: Colors.white54,
            ),
            label: const Text(
              '슬라이드 분석',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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

  Future<void> _connectLectureScreen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final audioStreamService = ref.read(audioStreamServiceProvider);
    final captureService = DisplayAudioCaptureService();

    try {
      await captureService.start(
        audioStreamService: audioStreamService,
        lectureId: 'demo-lecture',
        targetLang: 'Korean',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('강의 화면/탭 오디오 연결 시작'),
          duration: Duration(seconds: 2),
        ),
      );
    } on Exception catch (e) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            '강의 화면 연결 실패',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '$e',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '닫기',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _analyzeSlide(BuildContext context) async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*';

    input.click();
    await input.onChange.first;

    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final bytes = Uint8List.fromList(
      (reader.result as List<int>),
    );

    if (!context.mounted) {
      return;
    }

    final apiService = ApiService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text(
              '슬라이드 분석 중...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    final SlideAnalysisResponse result = await apiService.analyzeSlide(
      imageBytes: bytes,
      filename: file.name,
    );

    if (!context.mounted) {
      apiService.dispose();
      return;
    }

    Navigator.pop(context);

    final bodyText = result.visualContext.isNotEmpty
        ? result.visualContext
        : result.message.isNotEmpty
            ? result.message
            : '분석 결과가 없습니다.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          result.hasVisual ? '슬라이드 분석 결과' : '슬라이드 분석',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 460,
          child: Text(
            bodyText,
            style: TextStyle(
              color: result.status == ResponseStatus.error
                  ? Colors.redAccent
                  : Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '닫기',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );

    apiService.dispose();
  }

  Future<void> _showSummary(BuildContext context) async {
    final apiService = ApiService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text(
              '핵심 요약 생성 중...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

    final SummaryResponse result = await apiService.fetchAdaptiveSummary();

    if (!context.mounted) {
      apiService.dispose();
      return;
    }

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          '핵심 요약',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: Text(
            result.summary.isEmpty ? '요약 내용이 없습니다.' : result.summary,
            style: TextStyle(
              color: result.status == ResponseStatus.error
                  ? Colors.redAccent
                  : Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '닫기',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );

    apiService.dispose();
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
                    color: Colors.white.withValues(alpha: 0.05),
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
