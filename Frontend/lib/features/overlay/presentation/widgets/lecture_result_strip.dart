

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

Color _tabAccentColor(LectureWidgetTab tab) => const Color(0xFF779586);

Color _tabSoftColor(LectureWidgetTab tab) => const Color(0xFFE8EEE9);

final lectureWidgetTabProvider =
    StateProvider<LectureWidgetTab>((ref) => LectureWidgetTab.caption);

final lectureWidgetVisibleProvider = StateProvider<bool>((ref) => true);

final lectureWidgetSummaryProvider =
    StateProvider<String>((ref) => '강의 내용이 쌓이면 핵심 요약이 여기에 표시됩니다.');

final lectureWidgetSlideProvider =
    StateProvider<String>((ref) => '슬라이드 분석 결과가 여기에 표시됩니다.');

final lectureWidgetOpacityProvider = StateProvider<double>((ref) => 1.0);

final lectureWidgetWidthProvider = StateProvider<double>((ref) => 420);

final lectureWidgetHeightProvider = StateProvider<double>((ref) => 640);

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
                    color: const Color(0xFFF5F3F0),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE7E5E1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ondemand_video_rounded, size: 52, color: Color(0xFF779586)),
                      const SizedBox(height: 20),
                      const Text('강의 영상 주소를 입력하세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF252525))),
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
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE7E5E1),
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
                                borderRadius: BorderRadius.circular(18),
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
                                  child: const SizedBox(width: 30, height: 30),
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
  const _WidgetHeader({required this.tab, this.onResetVideo, this.onMinimize, this.onDragUpdate});
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanUpdate: onDragUpdate,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 8),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFE8EEE9), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.chat_outlined, color: Color(0xFF567D68), size: 23)),
        const SizedBox(width: 9),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Lecture-Hunter', style: TextStyle(fontSize: 17, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF252525))),
          SizedBox(height: 2),
          Text('강의가 조금 더 쉬워지는 그날까지', style: TextStyle(fontSize: 9, color: Color(0xFF77746F))),
        ])),
        if (onResetVideo != null) IconButton(onPressed: onResetVideo, icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF77746F)), tooltip: '강의 URL 초기화', constraints: const BoxConstraints(minWidth: 30, minHeight: 30), padding: EdgeInsets.zero),
        IconButton(onPressed: onMinimize, icon: const Icon(Icons.remove_rounded, size: 23, color: Color(0xFF77746F)), tooltip: '최소화', constraints: const BoxConstraints(minWidth: 30, minHeight: 30), padding: EdgeInsets.zero),
      ]),
    ),
  );
}


class _TabBar extends ConsumerWidget {
  final LectureWidgetTab tab;
  const _TabBar({required this.tab});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE7E5E1)))),
    child: Row(children: [
      for (final entry in const [
        (LectureWidgetTab.caption, '자막'), (LectureWidgetTab.question, '질문'),
        (LectureWidgetTab.notice, '공지'), (LectureWidgetTab.summary, '요약'),
        (LectureWidgetTab.settings, '설정')
      ])
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = entry.$1,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150), height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tab == entry.$1 ? const Color(0xFFE8EEE9) : const Color(0xFFF5F3F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tab == entry.$1 ? const Color(0xFF779586) : const Color(0xFFE7E5E1))),
              child: Text(entry.$2, style: TextStyle(fontSize: 12, fontWeight: tab == entry.$1 ? FontWeight.w800 : FontWeight.w500,
                color: tab == entry.$1 ? const Color(0xFF476C58) : const Color(0xFF77746F))),
            ),
          ),
        )),
    ]),
  );
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
    final history = ref.watch(subtitleHistoryProvider);
    final language = ref.watch(selectedCaptionLanguageProvider);
    final subtitle = subtitleAsync.valueOrNull ??
        (history.isNotEmpty ? history.last : null);
    final original = subtitle?.originalText.trim();
    final translated = subtitle?.translatedText?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(child: Text('실시간 자막',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                color: Color(0xFF252525)))),
            Icon(Icons.circle, size: 9,
              color: subtitleAsync.hasError
                  ? const Color(0xFFBF554E)
                  : subtitle == null
                      ? const Color(0xFFB0ACA6)
                      : const Color(0xFF476C58)),
            const SizedBox(width: 5),
            Text(subtitleAsync.hasError ? '연결 오류'
                : subtitle == null ? '연결 대기' : '자막 수신 중',
              style: const TextStyle(fontSize: 11, color: Color(0xFF476C58))),
          ]),
          const SizedBox(height: 16),
          _LanguageSelector(
            selectedLanguage: language,
            onChanged: (value) =>
                ref.read(selectedCaptionLanguageProvider.notifier).state = value,
          ),
          const SizedBox(height: 18),
          Container(
            height: 135,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(language == 'en' ? 'Original' : language == 'zh' ? '原文' : '원문', style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: Color(0xFF77746F))),
              const SizedBox(height: 12),
              Text(original == null || original.isEmpty
                  ? '강의 원문 자막이 여기에 표시됩니다.' : original,
                maxLines: 4, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Color(0xFF55534F))),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            height: 175,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF779586)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.translate_rounded,
                  color: Color(0xFF476C58), size: 19),
                const SizedBox(width: 7),
                Text(language == 'en' ? 'English Caption'
                    : language == 'zh' ? '中文字幕' : '한국어 자막',
                  style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800, color: Color(0xFF476C58))),
              ]),
              const SizedBox(height: 12),
              Text(
                translated == null || translated.isEmpty
                ? language == 'en'
                  ? 'Translated captions will appear here.'
                  : language == 'zh'
                    ? '翻译后的字幕将在此处显示。'
                    : '번역된 자막이 여기에 표시됩니다.'
                      : translated,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF252525),),),
            ]),
          ),
          if (subtitleAsync.hasError) ...[
            const SizedBox(height: 12),
            const Text('자막 서버 연결 상태를 확인해 주세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFFBF554E))),
          ],
        ],
      ),
    );
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
                color: Color(0xFF779586),
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
                      color: Color(0xFF252525),
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
  const _LanguageSelector({required this.selectedLanguage, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    _LanguageButton(flag: '🇺🇸', label: 'EN', value: 'en', selected: selectedLanguage == 'en', onTap: onChanged),
    const SizedBox(width: 8),
    _LanguageButton(flag: '🇰🇷', label: 'KR', value: 'ko', selected: selectedLanguage == 'ko', onTap: onChanged),
    const SizedBox(width: 8),
    _LanguageButton(flag: '🇨🇳', label: 'CN', value: 'zh', selected: selectedLanguage == 'zh', onTap: onChanged),
  ]);
}


class _LanguageButton extends StatelessWidget {
  final String flag, label, value;
  final bool selected;
  final ValueChanged<String> onTap;
  const _LanguageButton({required this.flag, required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: () => onTap(value), borderRadius: BorderRadius.circular(10),
    child: Container(height: 48, alignment: Alignment.center,
      decoration: BoxDecoration(color: selected ? const Color(0xFFE8EEE9) : const Color(0xFFF5F3F0),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? const Color(0xFF779586) : const Color(0xFFE7E5E1))),
      child: Text('$flag $label', style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? const Color(0xFF476C58) : const Color(0xFF77746F))),
    ),
  ));
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
              : const Color(0xFFE7E5E1),
          width: highlighted ? 1.2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF779586).withValues(alpha: 0.07),
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
        color: const Color(0xFFF5F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E1)),
      ),
      child: const Row(
        children: [
          _LiveDot(),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '실시간 자막 연결 중',
              style: TextStyle(
                color: Color(0xFF77746F),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.graphic_eq_rounded,
            size: 17,
            color: Color(0xFF779586),
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
              color: const Color(0xFFF5F3F0),
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

        Padding(
          padding: const EdgeInsets.fromLTRB(15, 20, 15, 16),
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
  Widget build(BuildContext context) => Row(children: [
    for (final item in const [(0, '익명 질문'), (1, '용어집 조회')])
      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: InkWell(
        onTap: () => onChanged(item.$1), borderRadius: BorderRadius.circular(10),
        child: Container(height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: mode == item.$1 ? const Color(0xFFE8EEE9) : const Color(0xFFF5F3F0),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: mode == item.$1 ? const Color(0xFF779586) : const Color(0xFFE7E5E1))),
          child: Text(item.$2, style: TextStyle(fontSize: 14, fontWeight: mode == item.$1 ? FontWeight.w800 : FontWeight.w500,
            color: mode == item.$1 ? const Color(0xFF476C58) : const Color(0xFF77746F))),
        ),
      ))),
  ]);
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
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Color(0xFF252525),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFF779586),
                  minLines: 6,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '궁금한 내용을 입력하세요.',
                    counterText: '',
                    contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    hintStyle: const TextStyle(
                      color: Color(0xFF77746F),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F3F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF5F3F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF5F3F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF779586),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: const Color(0xFF476C58),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE7E5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _captureForQuestion(ref),
                  icon: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFF779586),
                  ),
                  label: const Text(
                    '화면 캡처',
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
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8EEE9),
                    foregroundColor: const Color(0xFF476C58),
                    minimumSize: const Size.fromHeight(44),
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
                  icon: const Icon(Icons.send_outlined, size: 18, color: Color(0xFF476C58)),
                  label: const Text(
                    '질문 전송',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (state.query.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CompactAnswerCard(
                    label: '질문',
                    body: state.query.trim(),
                    accent: const Color(0xFFE7E5E1),
                  ),
                  const SizedBox(height: 8),
                  _CompactAnswerCard(
                    label: '답변',
                    body: (answer == null || answer.isEmpty)
                        ? '질문이 전달되었습니다. 답변을 기다려주세요.'
                        : answer,
                    accent: const Color(0xFF779586),
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
                    color: Color(0xFF252525),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFF779586),
                  decoration: InputDecoration(
                    hintText: '조회할 용어를 입력하세요.',
                    hintStyle: const TextStyle(
                      color: Color(0xFF77746F),
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
                        color: Color(0xFFE7E5E1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE7E5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF779586),
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
                  backgroundColor: const Color(0xFF779586),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _search,
                child: const Icon(Icons.search, size: 25, color: Colors.white),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 18),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Color(0xFF779586),
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
          color: const Color(0xFFE7E5E1),
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
              color: Color(0xFF252525),
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
              color: const Color(0xFFF5F3F0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '번역 서버 내부 용어집',
              style: TextStyle(
                color: Color(0xFF77746F),
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
                color: Color(0xFFE7E5E1),
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF77746F), fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(body, style: const TextStyle(color: Color(0xFF344054), height: 1.45))]))
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
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE7E5E1))),
          child: const Icon(Icons.refresh_rounded, size: 17, color: Color(0xFF779586)),
        ),
      ),
    );
  }
}

class _NoticeTab extends StatelessWidget {
  const _NoticeTab();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFE8EEE9), borderRadius: BorderRadius.circular(14)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.push_pin_outlined, color: Color(0xFF476C58), size: 19), SizedBox(width: 6), Text('중요 공지', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF476C58)))]),
          SizedBox(height: 10),
          Text('이번 강의에서 우선적으로 알아야 할 내용과 학습 방향을 안내합니다.', style: TextStyle(fontSize: 12.5, color: Color(0xFF595854), height: 1.5)),
        ]),
      ),
      const SizedBox(height: 12),
      _FigmaNoticeCard(title: '교재 및 참고 자료', icon: Icons.menu_book_outlined, rows: const [
        ['추천 교재', '교재명 · 저자 · 출판사 · 참고 범위'],
        ['추가 참고 자료', '자료 제목 · 발행기관 · 출처 링크'],
        ['필요한 학습 환경', '프로그램 · 개발 환경 · 설치 안내'],
      ]),
      const SizedBox(height: 12),
      _FigmaNoticeCard(title: '과제 안내', icon: Icons.assignment_outlined, rows: const [
        ['과제 설명', '과제명 · 수행 내용 · 요구사항'],
        ['제출 방법', '제출 플랫폼 · 파일 형식 · 제출 절차'],
        ['제출 기한', '제출 마감 날짜 및 시간'],
      ]),
    ]),
  );
}

class _FigmaNoticeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<List<String>> rows;
  const _FigmaNoticeCard({required this.title, required this.icon, required this.rows});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE7E5E1)), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 20, color: const Color(0xFF476C58)), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF476C58)))]),
      const SizedBox(height: 9),
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 16, color: Color(0xFFE7E5E1)),
        Text(rows[i][0], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF252525))),
        const SizedBox(height: 5),
        Text(rows[i][1], style: const TextStyle(fontSize: 11.5, color: Color(0xFF77746F))),
      ],
    ]),
  );
}

class _SummaryTab extends ConsumerStatefulWidget {
  const _SummaryTab({super.key});
  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  final _startHour = TextEditingController(text: '00');
  final _startMinute = TextEditingController(text: '00');
  final _endHour = TextEditingController(text: '00');
  final _endMinute = TextEditingController(text: '00');

  @override
  void dispose() {
    _startHour.dispose(); _startMinute.dispose(); _endHour.dispose(); _endMinute.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController h, TextEditingController m) {
    final hour = int.tryParse(h.text);
    final minute = int.tryParse(m.text);
    if (hour == null || minute == null || hour < 0 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  void _run(int minutes) {
    ref.read(summaryLoadingProvider.notifier).state = true;
    ref.read(summaryProvider.notifier).fetchSummary(minutes: minutes).whenComplete(() {
      if (mounted) ref.read(summaryLoadingProvider.notifier).state = false;
    });
  }

  void _submitManual() {
    final start = _parse(_startHour, _startMinute);
    final end = _parse(_endHour, _endMinute);
    if (start == null || end == null || end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('종료 시간을 시작 시간보다 크게 입력해 주세요.')));
      return;
    }
    _run(end - start);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(summaryProvider);
    final loading = ref.watch(summaryLoadingProvider);
    const green = Color(0xFF779586);
    const ink = Color(0xFF252525);
    const border = Color(0xFFE7E5E1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Text('요약할 시간 설정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink)),
              const SizedBox(width: 8),
              const Expanded(child: Text('강의 경과 00:00', style: TextStyle(fontSize: 10, color: Color(0xFF77746F)))),
              const Text('시 : 분', style: TextStyle(fontSize: 10, color: Color(0xFF77746F))),
            ]),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(child: _ManualTimePair(label: '시작 시간', hour: _startHour, minute: _startMinute)),
              const SizedBox(width: 20),
              Expanded(child: _ManualTimePair(label: '종료 시간', hour: _endHour, minute: _endMinute)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _SummaryQuick(label: '전체 구간', onTap: () => _run(60)),
          const SizedBox(width: 6),
          _SummaryQuick(label: '최근 10분', onTap: () => _run(10)),
          const SizedBox(width: 6),
          _SummaryQuick(label: '최근 30분', onTap: () => _run(30)),
          const SizedBox(width: 6),
          _SummaryQuick(label: '직접 선택', onTap: () => FocusScope.of(context).unfocus()),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 43, child: FilledButton(
          onPressed: loading ? null : _submitManual,
          style: FilledButton.styleFrom(backgroundColor: green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(loading ? '요약 중...' : '요약하기', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        )),
        if (state.summary.isNotEmpty || loading) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI 요약 결과', style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
              const SizedBox(height: 10),
              loading ? const Center(child: CircularProgressIndicator()) : Text(state.summary, style: const TextStyle(fontSize: 12, color: ink, height: 1.6)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ManualTimePair extends StatelessWidget {
  final String label;
  final TextEditingController hour;
  final TextEditingController minute;

  const _ManualTimePair({
    required this.label,
    required this.hour,
    required this.minute,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF77746F), fontSize: 11)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _TimeTextField(controller: hour)),
            const SizedBox(
              width: 22,
              height: 42,
              child: Center(
                child: Text(
                  ':',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF252525),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
            Expanded(child: _TimeTextField(controller: minute)),
          ],
        ),
      ],
    );
  }
}

class _TimeTextField extends StatelessWidget {
  final TextEditingController controller;
  const _TimeTextField({required this.controller});
  @override
  Widget build(BuildContext context) => SizedBox(height: 42, child: TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    maxLength: 2,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 14, color: Color(0xFF77746F)),
    decoration: InputDecoration(
      counterText: '', isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      filled: true, fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFE7E5E1)), borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF779586)), borderRadius: BorderRadius.circular(10)),
    ),
  ));
}

class _SummaryQuick extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SummaryQuick({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(height: 40, alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFF5F3F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE7E5E1))),
      child: Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF77746F))),
    ),
  ));
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
                    color: active ? const Color(0xFF779586) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF779586), width: 1.6),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 12,
                    color: active ? Colors.white : const Color(0xFF779586),
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
              style: const TextStyle(color: Color(0xFF476C58), fontSize: 13, fontWeight: FontWeight.w700),
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
              foregroundColor: const Color(0xFF476C58),
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
    return ListView(padding: const EdgeInsets.fromLTRB(15, 18, 15, 15), children: [
      Container(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: const Color(0xFFF5F3F0), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          _SettingSlider(title: '불투명도', valueText: '${(opacity * 100).round()}%', value: opacity, min: 0.2, max: 1, divisions: 16,
            onChanged: (v) => ref.read(lectureWidgetOpacityProvider.notifier).state = v),
          const Divider(color: Color(0xFFDEDCD7)),
          _SettingSlider(title: '너비', valueText: '${width.round()}px', value: width.clamp(300.0, 600.0), min: 300, max: 600, divisions: 30,
            onChanged: (v) {ref.read(lectureWidgetWidthProvider.notifier).state = v;
              html.window.parent?.postMessage({'type':'llai-resize','width':v.toInt(),'height':height.toInt()}, '*');}),
          const Divider(color: Color(0xFFDEDCD7)),
          _SettingSlider(title: '높이', valueText: '${height.round()}px', value: height.clamp(420.0, 800.0), min: 420, max: 800, divisions: 38,
            onChanged: (v) {ref.read(lectureWidgetHeightProvider.notifier).state = v;
              html.window.parent?.postMessage({'type':'llai-resize','width':width.toInt(),'height':v.toInt()}, '*');}),
          const Divider(color: Color(0xFFDEDCD7)),
          _SettingSlider(title: '전체 글자 크기', valueText: '${(fontScale * 100).round()}%', value: fontScale, min: 0.85, max: 1.25, divisions: 8,
            onChanged: (v) => ref.read(lectureWidgetFontScaleProvider.notifier).state = v),
        ]),
      ),
    ]);
  }
}


class _SettingSlider extends StatelessWidget {
  final String title, valueText;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SettingSlider({required this.title, required this.valueText, required this.value,
    required this.min, required this.max, required this.divisions, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF252525)))),
        Text(valueText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF476C58)))]),
      const SizedBox(height: 10),
      SliderTheme(data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF779586), inactiveTrackColor: const Color(0xFFDEDCD7),
        thumbColor: Colors.white, trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0),
        overlayShape: SliderComponentShape.noOverlay,
        valueIndicatorShape: SliderComponentShape.noOverlay,
        showValueIndicator: ShowValueIndicator.never,
        tickMarkShape: SliderTickMarkShape.noTickMark),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
    ]),
  );
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
                Text(subtitle, style: const TextStyle(color: Color(0xFF77746F), fontSize: 12, height: 1.25, fontWeight: FontWeight.w600)),
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
      decoration: BoxDecoration(color: const Color(0xFFF5F3F0), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE7E5E1))),
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
                decoration: BoxDecoration(color: const Color(0xFFF5F3F0), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.attach_file_rounded, color: Color(0xFF77746F), size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller, style: const TextStyle(color: Color(0xFF252525), fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: hintText, hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  filled: true, fillColor: const Color(0xFFF5F3F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE7E5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE7E5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFF779586))),
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
              decoration: BoxDecoration(color: const Color(0xFF779586), borderRadius: BorderRadius.circular(13)),
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
      decoration: BoxDecoration(color: const Color(0xFFF5F3F0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE7E5E1))),
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
          decoration: BoxDecoration(color: selected ? const Color(0xFF779586) : Colors.transparent, borderRadius: BorderRadius.circular(7)),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF77746F), fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
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
