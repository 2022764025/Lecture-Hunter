

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html; 
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import '../../../caption/presentation/controllers/caption_controller.dart';
import '../../../../main.dart'; 

import '../../../../services/api_service.dart';
import '../../../assistant/presentation/controllers/question_model.dart';

enum LectureWidgetTab {
  caption,
  question,
  notice,
  summary,
  settings,
}

Color _tabAccentColor(LectureWidgetTab tab) {
  switch (tab) {
    case LectureWidgetTab.caption:
      return const Color(0xFFE53935); 
    case LectureWidgetTab.question:
      return const Color(0xFFF79009); 
    case LectureWidgetTab.notice:
      return const Color(0xFFF9A825); 
    case LectureWidgetTab.summary:
      return const Color(0xFF43A047); 
    case LectureWidgetTab.settings:
      return const Color(0xFF2F6BFF); 
  }
}

Color _tabSoftColor(LectureWidgetTab tab) {
  switch (tab) {
    case LectureWidgetTab.caption:
      return const Color(0xFFFFEBEE);
    case LectureWidgetTab.question:
      return const Color(0xFFFFF4E5);
    case LectureWidgetTab.notice:
      return const Color(0xFFFFF8E1);
    case LectureWidgetTab.summary:
      return const Color(0xFFE8F5E9);
    case LectureWidgetTab.settings:
      return const Color(0xFFEEF4FF);
  }
}

final lectureWidgetTabProvider =
    StateProvider<LectureWidgetTab>((ref) => LectureWidgetTab.caption);

final lectureWidgetVisibleProvider = StateProvider<bool>((ref) => true);

final lectureWidgetSummaryProvider =
    StateProvider<String>((ref) => '강의 내용이 쌓이면 핵심 요약이 여기에 표시됩니다.');

final lectureWidgetSlideProvider =
    StateProvider<String>((ref) => '슬라이드 분석 결과가 여기에 표시됩니다.');

final lectureWidgetOpacityProvider = StateProvider<double>((ref) => 1.0);

final lectureWidgetWidthProvider = StateProvider<double>((ref) => 360);

final lectureWidgetHeightProvider = StateProvider<double>((ref) => 560);

final lectureWidgetFontScaleProvider = StateProvider<double>((ref) => 1.0);

final vlmLoadingStateProvider = StateProvider<bool>((ref) => false);

final uploadedImagesProvider = StateProvider<List<String>>((ref) => []);

final glossaryLoadingProvider = StateProvider<bool>((ref) => false);
final questionSubTabProvider = StateProvider<int>((ref) => 0);

final vlmSentImagesCardProvider = StateProvider<List<String>>((ref) => []);
final vlmQueryProvider = StateProvider<String?>((ref) => null);

final summaryLoadingProvider = StateProvider<bool>((ref) => false);

final summaryHistoryProvider = StateProvider<List<Map<String, String>>>((ref) => []);

class SummaryState {
  final String summary;
  final int minutes;
  SummaryState({required this.summary, required this.minutes});
  factory SummaryState.initial() => SummaryState(summary: '', minutes: 5);
}

class SummaryNotifier extends StateNotifier<SummaryState> {
  final ApiService _apiService = ApiService();
  SummaryNotifier() : super(SummaryState.initial());

  Future<void> fetchSummary({required int minutes}) async {
    try {
      final response = await _apiService.fetchAdaptiveSummary(minutes);

      state = SummaryState(summary: response.summary ?? '', minutes: minutes);
    } catch (e) {
      state = SummaryState(summary: '요약 데이터 로드 실패: $e', minutes: minutes);
    }
  }
}

final summaryProvider = StateNotifierProvider<SummaryNotifier, SummaryState>((ref) => SummaryNotifier());

class LectureFloatingWidget extends ConsumerStatefulWidget {
  const LectureFloatingWidget({super.key});

  @override
  ConsumerState<LectureFloatingWidget> createState() =>
      _LectureFloatingWidgetState();
}

class _LectureFloatingWidgetState extends ConsumerState<LectureFloatingWidget> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _glossaryController = TextEditingController();
  StreamSubscription? _pasteSubscription;

  html.IFrameElement? _youtubeIframe;
  String? _loadedVideoId;

  double _top = 24.0;
  double _right = 24.0;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _setupPasteListener();
    _checkAndInitYoutube();
  }

  void _checkAndInitYoutube() {
    final currentRoom = globalLectureId ?? '';
    String? videoId;

    if (currentRoom.contains('v=')) {
      videoId = currentRoom.split('v=').last.split('&').first;
    } else if (currentRoom.contains('youtu.be/')) {
      videoId = currentRoom.split('youtu.be/').last.split('?').first;
    } else if (currentRoom.startsWith('https://')) {
      final uri = Uri.tryParse(currentRoom);
      videoId = uri?.queryParameters['v'];
    }

    if (videoId != null) {
      globalLectureId = videoId;
    }

    if (videoId != null && videoId != _loadedVideoId) {
      _loadedVideoId = videoId;
      
      _youtubeIframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=0&controls=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      ui_web.platformViewRegistry.registerViewFactory(
        'youtube-player-$videoId',
        (int viewId) => _youtubeIframe!,
      );

      final sseService = ref.read(sseServiceProvider);
      sseService.connect(lectureId: videoId); 

      try {
        final wsUrl = "ws://127.0.0.1:8000/ws/audio?lecture_id=$videoId";
        print("[플러터 엔진] 유튜브 오디오 스트리밍 웹소켓 직접 연결 시도: $wsUrl");
        
        final youtubeWs = html.WebSocket(wsUrl);
        youtubeWs.onOpen.listen((_) => print("[플러터 엔진] 백엔드 유튜브 오디오 빨대 개통 성공!"));
        youtubeWs.onError.listen((error) => print("[플러터 엔진] 웹소켓 에러: $error"));
      } catch (e) {
        print("[플러터 엔진] 소켓 크래시 방어: $e");
      }
    }
  }

  void _setupPasteListener() {
    _pasteSubscription = html.document.onPaste.listen((html.ClipboardEvent e) {
      final items = e.clipboardData?.items;
      if (items == null) return;
      for (var i = 0; i < (items.length ?? 0); i++) {
        final item = items[i];
        if (item.type != null && item.type!.contains('image')) {
          final file = item.getAsFile();
          if (file != null) {
            final reader = html.FileReader()..readAsDataUrl(file);
            reader.onLoadEnd.listen((loadEvent) {
              final currentList = ref.read(uploadedImagesProvider);
              if (currentList.length < 5) {
                ref.read(uploadedImagesProvider.notifier).state = [...currentList, reader.result as String];
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _pasteSubscription?.cancel(); 
    _questionController.dispose();
    _glossaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(lectureWidgetVisibleProvider);
    final tab = ref.watch(lectureWidgetTabProvider);
    final panelOpacity = ref.watch(lectureWidgetOpacityProvider);
    final panelWidth = ref.watch(lectureWidgetWidthProvider);
    final panelHeight = ref.watch(lectureWidgetHeightProvider);
    final fontScale = ref.watch(lectureWidgetFontScaleProvider);

    _checkAndInitYoutube();

    if (!visible) {
      return Positioned(
        right: 24, bottom: 24,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => ref.read(lectureWidgetVisibleProvider.notifier).state = true,
            child: Image.asset('assets/Lecture-Hunter_Logo1.png', width: 78, height: 78, fit: BoxFit.contain),
          ),
        ),
      );
    }

    return Stack(
      children: [

        if (!_isMinimized && globalLectureId == null)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ondemand_video_rounded, size: 52, color: Color(0xFF2F6BFF)),
                      const SizedBox(height: 20),
                      const Text('강의 영상 주소를 입력하세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF101828))),
                      const SizedBox(height: 20),
                      TextField(
                        onSubmitted: (value) {
                          globalLectureId = value;
                          _checkAndInitYoutube();
                          ref.invalidate(subtitleStreamProvider);
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'https://youtube.com/watch?v=...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFD0D5DD))),
                          prefixIcon: const Icon(Icons.link_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (!_isMinimized && globalLectureId != null && _loadedVideoId != null && _youtubeIframe != null)
          Positioned(
            top: 0, left: 0, bottom: 0, right: panelWidth, 
            child: Container(
              color: Colors.white,
              child: HtmlElementView(viewType: 'youtube-player-$_loadedVideoId'),
            ),
          ),

        Positioned(

          top: _top,
          right: _right,
          child: _isMinimized 
              ?
                GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _top = (_top + details.delta.dy).clamp(0.0, double.infinity);
                      _right = (_right - details.delta.dx).clamp(0.0, double.infinity);
                    });
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _isMinimized = false);
                        html.window.parent?.postMessage({
                          'type': 'llai-resize',
                          'width': panelWidth.toInt(),
                          'height': panelHeight.toInt()
                        }, '*');
                      },
                      child: SizedBox(
                        width: 80,
                        height: 50,
                        child: Image.asset(
                          'assets/Lecture-Hunter_Logo1.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                )
              :
                Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: panelOpacity,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
                      child: Container(
                        width: panelWidth,
                        height: panelHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFE4E7EC),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Column(
                                  children: [
                                    _WidgetHeader(
                                      tab: tab,
                                      onDragUpdate: (details) {
                                        setState(() {
                                          _top = (_top + details.delta.dy).clamp(0.0, double.infinity);
                                          _right = (_right - details.delta.dx).clamp(0.0, double.infinity);
                                        });
                                      },
                                      onMinimize: () {
                                        setState(() => _isMinimized = true);
                                        html.window.parent?.postMessage({
                                          'type': 'llai-resize',
                                          'width': 96,
                                          'height': 64,
                                        }, '*');
                                      },
                                      onResetVideo: _loadedVideoId != null
                                          ? () {
                                              setState(() {
                                                _loadedVideoId = null;
                                                globalLectureId = null;
                                              });
                                            }
                                          : null,
                                    ),
                                    _TabBar(tab: tab),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 140),
                                        layoutBuilder: (currentChild, previousChildren) => Stack(
                                          alignment: Alignment.topCenter,
                                          children: [
                                            ...previousChildren,
                                            if (currentChild != null) currentChild,
                                          ],
                                        ),
                                        child: SizedBox(
                                          key: ValueKey(tab),
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: _TabBody(
                                            tab: tab,
                                            questionController: _questionController,
                                            glossaryController: _glossaryController,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    final currentWidth = ref.read(lectureWidgetWidthProvider);
                                    final currentHeight = ref.read(lectureWidgetHeightProvider);
                                    final nextWidth = (currentWidth - details.delta.dx)
                                        .clamp(300.0, 600.0)
                                        .toDouble();
                                    final nextHeight = (currentHeight + details.delta.dy)
                                        .clamp(420.0, 800.0)
                                        .toDouble();
                                    ref.read(lectureWidgetWidthProvider.notifier).state = nextWidth;
                                    ref.read(lectureWidgetHeightProvider.notifier).state = nextHeight;
                                    html.window.parent?.postMessage({
                                      'type': 'llai-resize',
                                      'width': nextWidth.toInt(),
                                      'height': nextHeight.toInt(),
                                    }, '*');
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.96),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: const Color(0xFFD0D5DD),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.south_west_rounded,
                                      size: 17,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _WidgetHeader extends StatelessWidget {
  final LectureWidgetTab tab;
  final VoidCallback? onResetVideo;
  final VoidCallback? onMinimize;
  final GestureDragUpdateCallback? onDragUpdate;

  const _WidgetHeader({
    required this.tab,
    this.onResetVideo,
    this.onMinimize,
    this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: onDragUpdate,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12, right: 12, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: Image.asset(
                  'assets/Lecture-Hunter_Logo4.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'Lecture Hunter',
                    style: TextStyle(
                      color: Color(0xFF2F6BFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMinimize != null)
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, color: Colors.black54, size: 22),
                    onPressed: onMinimize,
                    tooltip: '위젯 최소화',
                  ),
                if (onMinimize != null && onResetVideo != null) const SizedBox(width: 4),
                if (onResetVideo != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.black54, size: 20),
                      splashRadius: 18,
                      tooltip: '강의실 URL 초기화',
                      onPressed: onResetVideo,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends ConsumerWidget {
  final LectureWidgetTab tab;
  const _TabBar({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAECF0), width: 1)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '자막',
            accentColor: _tabAccentColor(LectureWidgetTab.caption),
            softColor: _tabSoftColor(LectureWidgetTab.caption),
            selected: tab == LectureWidgetTab.caption,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.caption,
          ),
          _TabButton(
            label: '질문',
            accentColor: _tabAccentColor(LectureWidgetTab.question),
            softColor: _tabSoftColor(LectureWidgetTab.question),
            selected: tab == LectureWidgetTab.question,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.question,
          ),
          _TabButton(
            label: '공지',
            accentColor: _tabAccentColor(LectureWidgetTab.notice),
            softColor: _tabSoftColor(LectureWidgetTab.notice),
            selected: tab == LectureWidgetTab.notice,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.notice,
          ),
          _TabButton(
            label: '요약',
            accentColor: _tabAccentColor(LectureWidgetTab.summary),
            softColor: _tabSoftColor(LectureWidgetTab.summary),
            selected: tab == LectureWidgetTab.summary,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.summary,
          ),
          _TabButton(
            label: '설정',
            accentColor: _tabAccentColor(LectureWidgetTab.settings),
            softColor: _tabSoftColor(LectureWidgetTab.settings),
            selected: tab == LectureWidgetTab.settings,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.settings,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final Color softColor;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.accentColor,
    required this.softColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? softColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? accentColor.withValues(alpha: 0.55)
                    : accentColor.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? accentColor : const Color(0xFF667085),
                fontSize: 11.8,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBody extends ConsumerWidget {
  final LectureWidgetTab tab;
  final TextEditingController questionController;
  final TextEditingController glossaryController;

  const _TabBody({
    super.key,
    required this.tab,
    required this.questionController,
    required this.glossaryController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late final Widget child;

    switch (tab) {
      case LectureWidgetTab.caption:
        child = const _CaptionTab();
        break;
      case LectureWidgetTab.question:
        child = _QuestionTab(controller: questionController);
        break;
      case LectureWidgetTab.notice:
        child = const _NoticeTab();
        break;
      case LectureWidgetTab.summary:
        child = const _SummaryTab();
        break;
      case LectureWidgetTab.settings:
        child = const _SettingsTab();
        break;
    }

    return child;
  }
}

final selectedCaptionLanguageProvider =
    StateProvider<String>((ref) => 'ko');

class _CaptionTab extends ConsumerWidget {
  const _CaptionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleAsync = ref.watch(subtitleStreamProvider);
    final selectedLanguage = ref.watch(selectedCaptionLanguageProvider);

    return subtitleAsync.when(
      data: (latestSubtitle) {
        if (latestSubtitle == null) {
          return _CaptionEmptyState(
            selectedLanguage: selectedLanguage,
            onLanguageChanged: (language) {
              ref.read(selectedCaptionLanguageProvider.notifier).state = language;
            },
          );
        }

        final originalText = '강의가 조금 더 쉬워지는 그날까지';
        final translatedText = _slogan(selectedLanguage);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CaptionHeader(
                selectedLanguage: selectedLanguage,
                onLanguageChanged: (language) {
                  ref.read(selectedCaptionLanguageProvider.notifier).state = language;
                },
              ),
              const SizedBox(height: 16),
              _ModernSubtitleCard(
                label: _originalTitle(selectedLanguage),
                text: originalText,
                accentColor: const Color(0xFF667085),
                backgroundColor: const Color(0xFFF9FAFB),
              ),
              const SizedBox(height: 12),
              _ModernSubtitleCard(
                label: _languageTitle(selectedLanguage),
                text: translatedText,
                accentColor: const Color(0xFF2F6BFF),
                backgroundColor: const Color(0xFFF9FAFB),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2F6BFF),
          strokeWidth: 2.5,
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '자막 연동 오류\n$err',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD92D20),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  static String _originalTitle(String language) {
    switch (language) {
      case 'en':
        return 'Original';
      case 'zh':
        return '原文';
      case 'ko':
      default:
        return '원문';
    }
  }

  static String _languageTitle(String language) {
    switch (language) {
      case 'en':
        return 'English Caption';
      case 'zh':
        return '中文字幕';
      case 'ko':
      default:
        return '한국어 자막';
    }
  }

  static String _languageBadge(String language) {
    switch (language) {
      case 'en':
        return 'EN';
      case 'zh':
        return '中文';
      case 'ko':
      default:
        return 'KO';
    }
  }


  static String _slogan(String language) {
    switch (language) {
      case 'en':
        return 'Until the day lectures become '
            'a little easier';

      case 'zh':
        return '直到课程变得更轻松的那一天';

      case 'ko':
      default:
        return '강의가 조금 더 쉬워지는 그날까지';
    }
  }
}

class _CaptionHeader extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const _CaptionHeader({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.closed_caption_rounded,
                color: Color(0xFFE53935),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실시간 자막',
                    style: TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LanguageSelector(
          selectedLanguage: selectedLanguage,
          onChanged: onLanguageChanged,
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _LanguageButton(
            flag: '🇺🇸',
            label: 'EN',
            value: 'en',
            selected: selectedLanguage == 'en',
            onTap: onChanged,
          ),
          const SizedBox(width: 4),
          _LanguageButton(
            flag: '🇰🇷',
            label: 'KR',
            value: 'ko',
            selected: selectedLanguage == 'ko',
            onTap: onChanged,
          ),
          const SizedBox(width: 4),
          _LanguageButton(
            flag: '🇨🇳',
            label: 'CN',
            value: 'zh',
            selected: selectedLanguage == 'zh',
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String flag;
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _LanguageButton({
    required this.flag,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(value),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: const Color(0xFFD0D5DD),
                      width: 0.8,
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF2F6BFF)
                        : const Color(0xFF667085),
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernSubtitleCard extends StatelessWidget {
  final String label;
  final String text;
  final Color accentColor;
  final Color backgroundColor;
  final bool highlighted;

  const _ModernSubtitleCard({
    required this.label,
    required this.text,
    required this.accentColor,
    required this.backgroundColor,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFB2CCFF)
              : const Color(0xFFEAECF0),
          width: highlighted ? 1.2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF2F6BFF).withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1D2939),
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionStatusBar extends StatelessWidget {
  const _CaptionStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: const Row(
        children: [
          _LiveDot(),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '실시간 자막 연결 중',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.graphic_eq_rounded,
            size: 17,
            color: Color(0xFF2F6BFF),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.35, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF12B76A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _CaptionEmptyState extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const _CaptionEmptyState({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          _CaptionHeader(
            selectedLanguage: selectedLanguage,
            onLanguageChanged: onLanguageChanged,
          ),
          const SizedBox(height: 60),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.subtitles_rounded,
              size: 29,
              color: Color(0xFF98A2B3),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '자막을 기다리고 있어요',
            style: TextStyle(
              color: Color(0xFF344054),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '강의가 시작되면 원문과 번역 자막이\n실시간으로 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

void _showOriginalImage(BuildContext context, String base64Image) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(base64Image, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 10, right: 10,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuestionTab extends ConsumerWidget {
  final TextEditingController controller;
  const _QuestionTab({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(questionSubTabProvider);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: _SectionTitle(
            tab: LectureWidgetTab.question,
            icon: Icons.help_outline_rounded,
            title: '질문',
            subtitle: '',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: _QuestionModeToggle(
            mode: mode,
            onChanged: (value) => ref.read(questionSubTabProvider.notifier).state = value,
          ),
        ),
        Expanded(
          child: mode == 0
              ? _AnonymousQuestionView(controller: controller)
              : _GlossaryLookupView(controller: controller),
        ),
      ],
    );
  }
}

class _QuestionModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChanged;
  const _QuestionModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(String text, int value, IconData? icon) {
      final selected = mode == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF4E5) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFFED7AA) : const Color(0xFFE4E7EC),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? const Color(0xFFF79009) : const Color(0xFF98A2B3),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF7A2E0E) : const Color(0xFF475467),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('익명 질문', 0, null),
        const SizedBox(width: 8),
        item('용어집 조회', 1, null),
      ],
    );
  }
}

class _AnonymousQuestionView extends ConsumerWidget {
  final TextEditingController controller;
  const _AnonymousQuestionView({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionResponseProvider);
    final attached = ref.watch(uploadedImagesProvider);
    final answer = state.response?.answer.trim();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFFF79009),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '궁금한 내용을 입력하세요.',
                    hintStyle: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFF79009),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: const Color(0xFF7A2E0E),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFFED7AA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _captureForQuestion(ref),
                  icon: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFFF79009),
                  ),
                  label: const Text(
                    '화면 캡처하기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (attached.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          attached.first,
                          height: 115,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: InkWell(
                          onTap: () => ref.read(uploadedImagesProvider.notifier).state = [],
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xCC1D2939),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF79009),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    ref.read(questionModeProvider.notifier).state = QuestionMode.professor;
                    await ref.read(questionResponseProvider.notifier).submit(
                          text,
                          QuestionTarget.professor,
                        );
                    controller.clear();
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    '익명 질문 보내기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (state.query.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CompactAnswerCard(
                    label: '질문',
                    body: state.query.trim(),
                    accent: const Color(0xFFFED7AA),
                  ),
                  const SizedBox(height: 8),
                  _CompactAnswerCard(
                    label: '답변',
                    body: (answer == null || answer.isEmpty)
                        ? '질문이 전달되었습니다. 답변을 기다려주세요.'
                        : answer,
                    accent: const Color(0xFFF79009),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _captureForQuestion(WidgetRef ref) async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      final promise = js_util.callMethod(
        mediaDevices!,
        'getDisplayMedia',
        [js_util.jsify({'video': true})],
      );
      final html.MediaStream stream = await js_util.promiseToFuture(promise);
      final track = stream.getVideoTracks().first;
      final video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true;
      await video.onCanPlay.first;
      final canvas = html.CanvasElement(
        width: video.videoWidth,
        height: video.videoHeight,
      );
      canvas.context2D.drawImage(video, 0, 0);
      track.stop();
      ref.read(uploadedImagesProvider.notifier).state = [
        canvas.toDataUrl('image/png'),
      ];
    } catch (_) {}
  }
}

class _GlossaryLookupView extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const _GlossaryLookupView({
    required this.controller,
  });

  @override
  ConsumerState<_GlossaryLookupView> createState() => _GlossaryLookupViewState();
}

class _GlossaryLookupViewState extends ConsumerState<_GlossaryLookupView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(glossarySearchProvider);
    final loading = ref.watch(glossaryLoadingProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFFF79009),
                  decoration: InputDecoration(
                    hintText: '용어를 입력하세요...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B7C3),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD0D5DD),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFF79009),
                        width: 1.4,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF79009),
                  foregroundColor: const Color(0xFF172033),
                  minimumSize: const Size(68, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _search,
                child: const Text(
                  '조회',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 18),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Color(0xFFF79009),
                  strokeWidth: 2.4,
                ),
              ),
            ),
          ],
          if (!loading && state.results.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...state.results.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GlossaryResultCard(
                  term: e.term,
                  definition: e.definition,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _search() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    ref.read(glossaryLoadingProvider.notifier).state = true;
    ref.read(glossarySearchProvider.notifier).search(text);
  }
}

class _GlossaryResultCard extends StatelessWidget {
  final String term;
  final String definition;

  const _GlossaryResultCard({
    required this.term,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '번역 서버 내부 용어집',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '요약',
            style: TextStyle(
              color: Color(0xFFB54708),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            definition,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 13.2,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
            ),
            label: const Text(
              '추가 설명 요청',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              foregroundColor: const Color(0xFFB54708),
              side: const BorderSide(
                color: Color(0xFFFED7AA),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAnswerCard extends StatelessWidget {
  final String label, body; final Color accent;
  const _CompactAnswerCard({required this.label, required this.body, required this.accent});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 4, height: 54, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(body, style: const TextStyle(color: Color(0xFF344054), height: 1.45))]))
    ]),
  );
}

class _SmallResetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '질문 초기화',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFFED7AA))),
          child: const Icon(Icons.refresh_rounded, size: 17, color: Color(0xFFF79009)),
        ),
      ),
    );
  }
}

class _NoticeTab extends StatelessWidget {
  const _NoticeTab();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              tab: LectureWidgetTab.notice,
              icon: Icons.campaign_rounded,
              title: '공지',
              subtitle: '',
            ),
            const SizedBox(height: 14),
            _NoticeSection(
              icon: null,
              title: '',
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: '이번 주 강의는 '),
                    TextSpan(
                      text: '진도 흐름 파악이 중요합니다.',
                      style: TextStyle(
                        color: Color(0xFFF79009),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '\n다음 주부터 중간 평가 관련 내용이 진행될 예정이니, 반드시 이번 주 내용을 숙지해 주세요.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _NoticeSection(
              icon: Icons.description_rounded,
              title: '강의 자료',
              child: Column(
                children: [
                  _NoticeRow(
                    icon: Icons.attach_file_rounded,
                    title: '강의 슬라이드',
                    subtitle: '출처: 교수님 제공',
                    trailing: Icons.open_in_new_rounded,
                    actionMessage: '강의 슬라이드 바로가기',
                  ),
                  SizedBox(height: 8),
                  _NoticeRow(
                    icon: Icons.attach_file_rounded,
                    title: '추가 참고 자료',
                    subtitle: '출처: 논문 (Smith et al., 2023)',
                    trailing: Icons.open_in_new_rounded,
                    actionMessage: '추가 참고 자료 바로가기',
                  ),
                  SizedBox(height: 8),
                  _NoticeRow(
                    icon: Icons.laptop_mac_rounded,
                    title: '필요한 환경',
                    subtitle: '구글 코랩(Google Colab), VS Code 권장\n필요한 라이브러리: numpy, matplotlib 등',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _NoticeSection(
              icon: Icons.assignment_rounded,
              title: '과제 안내',
              child: Column(
                children: [
                  _NoticeRow(
                    icon: Icons.description_outlined,
                    title: '과제 설명',
                    subtitle: '신경망 모델 구현 및 성능 비교',
                    trailing: Icons.chevron_right_rounded,
                    actionMessage: '과제 설명 열기',
                  ),
                  SizedBox(height: 8),
                  _NoticeRow(
                    icon: Icons.attach_file_rounded,
                    title: '과제 제출 방법',
                    subtitle: 'LMS에 코드 파일(.ipynb) 업로드',
                    trailing: Icons.chevron_right_rounded,
                    actionMessage: '과제 제출 방법 열기',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
class _NoticeSection extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget child;

  const _NoticeSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF9A825);
    const soft = Color(0xFFFFF8E1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
class _NoticeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final String? actionMessage;

  const _NoticeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.actionMessage,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: actionMessage == null
              ? null
              : () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(actionMessage!),
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF9A825).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFF9A825),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF667085),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Icon(
                    trailing,
                    color: const Color(0xFFF9A825),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      );
}

class _SummaryTab extends ConsumerStatefulWidget {
  const _SummaryTab({super.key});

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  int _startHour = 0;
  int _startMinutePart = 0;
  int _endHour = 0;
  int _endMinutePart = 5;

  int get _startTotal => _startHour * 60 + _startMinutePart;
  int get _endTotal => _endHour * 60 + _endMinutePart;
  bool get _hasValidRange => _endTotal > _startTotal;

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(summaryProvider);
    final loading = ref.watch(summaryLoadingProvider);
    final body = state.summary.isEmpty
        ? '요약을 실행하면 선택한 구간의 핵심 내용이 여기에 표시됩니다.'
        : state.summary;
    final summaryAccent = _tabAccentColor(LectureWidgetTab.summary);
    final summarySoft = _tabSoftColor(LectureWidgetTab.summary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            tab: LectureWidgetTab.summary,
            icon: Icons.auto_awesome_rounded,
            title: '구간요약',
            subtitle: '',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: _box(summaryAccent, summarySoft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimePointSelector(
                        label: '시작',
                        accentColor: summaryAccent,
                        softColor: summarySoft,
                        hour: _startHour,
                        minute: _startMinutePart,
                        onHourChanged: (value) {
                          setState(() => _startHour = value);
                        },
                        onMinuteChanged: (value) {
                          setState(() => _startMinutePart = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TimePointSelector(
                        label: '종료',
                        accentColor: summaryAccent,
                        softColor: summarySoft,
                        hour: _endHour,
                        minute: _endMinutePart,
                        onHourChanged: (value) {
                          setState(() => _endHour = value);
                        },
                        onMinuteChanged: (value) {
                          setState(() => _endMinutePart = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: summaryAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: summaryAccent.withValues(alpha: 0.28),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _hasValidRange ? _summarizeSelectedRange : null,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text(
                      '요약하기',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _Quick('전체 구간', () => _summarize(30)),
                    _Quick('최근 5분', () => _summarize(5)),
                    _Quick('최근 10분', () => _summarize(10)),
                    _Quick('직접 선택', () {}),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _box(summaryAccent, summarySoft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_rounded, color: summaryAccent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI 요약',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Icon(Icons.refresh_rounded, color: summaryAccent, size: 19),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                  decoration: BoxDecoration(
                    color: summarySoft.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: summaryAccent.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        constraints: const BoxConstraints(minHeight: 54),
                        decoration: BoxDecoration(
                          color: summaryAccent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: loading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: summaryAccent,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                body,
                                style: const TextStyle(
                                  color: Color(0xFF344054),
                                  height: 1.55,
                                  fontSize: 12.2,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: _box(summaryAccent, summarySoft),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: summarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.timeline_rounded,
                        color: summaryAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      '주요 타임라인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _TimelineItem(
                  time: '00:00',
                  title: '강의 시작 및 핵심 개념 소개',
                  active: true,
                ),
                const _TimelineItem(
                  time: '15:00',
                  title: '주요 개념 및 내용 정리',
                ),
                const _TimelineItem(
                  time: '30:00',
                  title: '핵심 내용 심화 설명',
                ),
                const _TimelineItem(
                  time: '45:00',
                  title: '정리 및 예제 설명',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box(Color accent, Color soft) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: 0.23)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  void _summarizeSelectedRange() {
    if (!_hasValidRange) return;
    _summarize(_endTotal - _startTotal);
  }

  void _summarize(int minutes) {
    ref.read(summaryLoadingProvider.notifier).state = true;
    ref.read(summaryProvider.notifier).fetchSummary(minutes: minutes).whenComplete(
          () => ref.read(summaryLoadingProvider.notifier).state = false,
        );
  }
}

class _TimePointSelector extends StatelessWidget {
  final String label;
  final Color accentColor;
  final Color softColor;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _TimePointSelector({
    required this.label,
    required this.accentColor,
    required this.softColor,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeUnitStepper(
                  value: hour,
                  min: 0,
                  max: 23,
                  step: 1,
                  accentColor: accentColor,
                  softColor: softColor,
                  onChanged: onHourChanged,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _TimeUnitStepper(
                  value: minute,
                  min: 0,
                  max: 55,
                  step: 5,
                  accentColor: accentColor,
                  softColor: softColor,
                  onChanged: onMinuteChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeUnitStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final Color accentColor;
  final Color softColor;
  final ValueChanged<int> onChanged;

  const _TimeUnitStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.accentColor,
    required this.softColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = value < max;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: softColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: canDecrease
                ? () => onChanged((value - step).clamp(min, max).toInt())
                : null,
            child: SizedBox(
              width: 18,
              height: 40,
              child: Icon(
                Icons.remove_rounded,
                size: 15,
                color: canDecrease
                    ? accentColor
                    : const Color(0xFFD0D5DD),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1D2939),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: canIncrease
                ? () => onChanged((value + step).clamp(min, max).toInt())
                : null,
            child: SizedBox(
              width: 18,
              height: 40,
              child: Icon(
                Icons.add_rounded,
                size: 15,
                color: canIncrease
                    ? accentColor
                    : const Color(0xFFD0D5DD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback onTap;

  const _StepArrow({
    required this.icon,
    required this.enabled,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 19,
        height: 17,
        child: Icon(
          icon,
          size: 17,
          color: enabled ? accentColor : const Color(0xFFD0D5DD),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final bool active;
  final bool last;

  const _TimelineItem({
    required this.time,
    required this.title,
    this.active = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF43A047) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF43A047), width: 1.6),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: active ? Colors.white : const Color(0xFF43A047),
                  ),
                ),
                if (!last) Container(width: 1.5, height: 25, color: const Color(0xFFCFE8D3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: const TextStyle(color: Color(0xFF35883B), fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}

class _Quick extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Quick(this.text, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              foregroundColor: const Color(0xFF35883B),
              backgroundColor: const Color(0xFFFAFCFA),
              side: const BorderSide(color: Color(0xFFCFE8D3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = ref.watch(lectureWidgetOpacityProvider);
    final width = ref.watch(lectureWidgetWidthProvider);
    final height = ref.watch(lectureWidgetHeightProvider);
    final fontScale = ref.watch(lectureWidgetFontScaleProvider);
    final accent = _tabAccentColor(LectureWidgetTab.settings);
    final soft = _tabSoftColor(LectureWidgetTab.settings);

    return _PanelScroll(
      children: [
        const _SectionTitle(
          tab: LectureWidgetTab.settings,
          icon: Icons.tune_rounded,
          title: '설정',
          subtitle: '',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE6F8)),
          ),
          child: Column(
            children: [
              _SettingSlider(
                icon: Icons.opacity_rounded,
                title: '투명도',
                valueText: '${(opacity * 100).round()}%',
                value: opacity,
                min: 0.20,
                max: 1.0,
                divisions: 16,
                accentColor: accent,
                softColor: soft,
                onChanged: (value) =>
                    ref.read(lectureWidgetOpacityProvider.notifier).state = value,
              ),
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
              _SettingSlider(
                icon: Icons.width_normal_rounded,
                title: '너비',
                valueText: '${width.round()} px',
                value: width.clamp(300.0, 600.0),
                min: 300,
                max: 600,
                divisions: 30,
                accentColor: accent,
                softColor: soft,
                onChanged: (value) {
                  ref.read(lectureWidgetWidthProvider.notifier).state = value;
                  html.window.parent?.postMessage({
                    'type': 'llai-resize',
                    'width': value.toInt(),
                    'height': height.toInt(),
                  }, '*');
                },
              ),
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
              _SettingSlider(
                icon: Icons.height_rounded,
                title: '높이',
                valueText: '${height.round()} px',
                value: height.clamp(420.0, 800.0),
                min: 420,
                max: 800,
                divisions: 38,
                accentColor: accent,
                softColor: soft,
                onChanged: (value) {
                  ref.read(lectureWidgetHeightProvider.notifier).state = value;
                  html.window.parent?.postMessage({
                    'type': 'llai-resize',
                    'width': width.toInt(),
                    'height': value.toInt(),
                  }, '*');
                },
              ),
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
              _SettingSlider(
                icon: Icons.text_fields_rounded,
                title: '전체 글자 크기',
                valueText: '${(fontScale * 100).round()}%',
                value: fontScale,
                min: 0.85,
                max: 1.25,
                divisions: 8,
                accentColor: accent,
                softColor: soft,
                onChanged: (value) =>
                    ref.read(lectureWidgetFontScaleProvider.notifier).state = value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accentColor;
  final Color softColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _SettingSlider({
    required this.icon,
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accentColor,
    required this.softColor,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1D2939),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: accentColor.withValues(alpha: 0.13),
              thumbColor: Colors.white,
              overlayColor: accentColor.withValues(alpha: 0.08),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 14,
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelScroll extends StatelessWidget {
  final List<Widget> children;
  const _PanelScroll({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 18), children: children);
  }
}

class _SectionTitle extends StatelessWidget {
  final LectureWidgetTab tab; final IconData icon; final String title; final String subtitle;
  const _SectionTitle({required this.tab, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final accentColor = _tabAccentColor(tab);
    final softColor = _tabSoftColor(tab);
    return Row(
      children: [
        Container(
          width: 42, height: 42, alignment: Alignment.center,
          decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.w700)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, height: 1.25, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title; final String body; final Color accentColor;
  const _ResultCard({required this.title, required this.body, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 5, height: 58, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(999))),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 9),
                  Text(body, style: const TextStyle(color: Color(0xFF344054), fontSize: 14, height: 1.45, fontWeight: FontWeight.w700), softWrap: true, overflow: TextOverflow.visible),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFEDF89))),
      child: Text(text, style: const TextStyle(color: Color(0xFF93370D), fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller; final String hintText; final IconData buttonIcon; final VoidCallback onSubmit; final VoidCallback? onAttachTap;
  const _InputArea({required this.controller, required this.hintText, required this.buttonIcon, required this.onSubmit, this.onAttachTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE8ECF5)))),
      child: Row(
        children: [
          if (onAttachTap != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(13), onTap: onAttachTap,
              child: Container(
                width: 42, height: 42, alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.attach_file_rounded, color: Color(0xFF667085), size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller, style: const TextStyle(color: Color(0xFF101828), fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: hintText, hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFF2F6BFF))),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(13), onTap: onSubmit,
            child: Container(
              width: 42, height: 42, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF2F6BFF), borderRadius: BorderRadius.circular(13)),
              child: Icon(buttonIcon, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTargetToggle extends StatelessWidget {
  final QuestionTarget target; final ValueChanged<QuestionTarget> onChanged;
  const _QuestionTargetToggle({required this.target, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Row(
        children: [
          _TargetTabButton(label: 'AI에게 질문', selected: target == QuestionTarget.ai, onTap: () => onChanged(QuestionTarget.ai)),
          _TargetTabButton(label: '교수님께 익명 질문', selected: target == QuestionTarget.professor, onTap: () => onChanged(QuestionTarget.professor)),
        ],
      ),
    );
  }
}

class _TargetTabButton extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _TargetTabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(7), onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? const Color(0xFFF79009) : Colors.transparent, borderRadius: BorderRadius.circular(7)),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF667085), fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ),
      ),
    );
  }
}

class _VlmCaptureButton extends StatelessWidget {
  final bool isLoading; final VoidCallback onTap;
  const _VlmCaptureButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13), onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity, height: 42, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFF94E2DE))),
        child: isLoading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF14B8A6))))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, color: Color(0xFF14B8A6), size: 18),
                  SizedBox(width: 8),
                  Text('현재 화면 캡처해서 AI 질문', style: TextStyle(color: Color(0xFF0D9488), fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
