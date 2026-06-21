// lib/features/overlay/presentation/widgets/lecture_result_strip.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html; 
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import '../../../caption/presentation/controllers/caption_controller.dart';
import '../../../../main.dart'; 

enum LectureWidgetTab {
  caption,
  question,
  glossary,
  summary,
  settings,
}

Color _tabAccentColor(LectureWidgetTab tab) {
  switch (tab) {
    case LectureWidgetTab.caption:
      return const Color(0xFFE53935); 
    case LectureWidgetTab.question:
      return const Color(0xFFFB8C00); 
    case LectureWidgetTab.glossary:
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
      return const Color(0xFFFFF3E0);
    case LectureWidgetTab.glossary:
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

final lectureWidgetFontScaleProvider = StateProvider<double>((ref) => 1.0);

final vlmLoadingStateProvider = StateProvider<bool>((ref) => false);

// [다중 이미지 체계 구축] 최대 5장 이미지 관리를 위해 List<String> 구조로 전면 마이그레이션
final uploadedImagesProvider = StateProvider<List<String>>((ref) => []);

// [추가] 용어집 LLM 실시간 빌드 중인지 감시하는 상태 스위치
final glossaryLoadingProvider = StateProvider<bool>((ref) => false);

final vlmSentImagesCardProvider = StateProvider<List<String>>((ref) => []);
final vlmQueryProvider = StateProvider<String?>((ref) => null);

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

  @override
  void initState() {
    super.initState();
    // Cmd+Shift+3 또는 4 상관없이 클립보드에 복사된 이미지를 Cmd+V로 최대 5장까지 누적 스캔하는 오토 포트 가동
    _pasteSubscription = html.document.onPaste.listen((html.ClipboardEvent e) {
      final items = e.clipboardData?.items;
      if (items != null) {
        // (items.length ?? 0) 구조 결합으로 int? num 할당 에러 완전 소멸
        for (var i = 0; i < (items.length ?? 0); i++) {
          final item = items[i];
          if (item.type != null && item.type!.contains('image')) {
            final file = item.getAsFile();
            if (file != null) {
              final reader = html.FileReader();
              reader.readAsDataUrl(file);
              reader.onLoadEnd.listen((loadEvent) {
                final currentList = ref.read(uploadedImagesProvider);
                if (currentList.length < 5) {
                  ref.read(uploadedImagesProvider.notifier).state = [
                    ...currentList,
                    reader.result as String
                  ];
                }
              });
            }
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
    final fontScale = ref.watch(lectureWidgetFontScaleProvider);

    if (!visible) {
      return Positioned(
        right: 24,
        bottom: 24,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              ref.read(lectureWidgetVisibleProvider.notifier).state = true;
            },
            child: Image.asset(
              'assets/lecture_hunter_icon.png',
              width: 78,
              height: 78,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: 24,
      right: 24,
      bottom: 24,
      width: panelWidth,
      child: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: panelOpacity,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [
                    _WidgetHeader(tab: tab),
                    _TabBar(tab: tab),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        child: _TabBody(
                          key: ValueKey(tab),
                          tab: tab,
                          questionController: _questionController,
                          glossaryController: _glossaryController,
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
    );
  }
}

class _WidgetHeader extends StatelessWidget {
  final LectureWidgetTab tab;
  const _WidgetHeader({required this.tab});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        // 위젯 상단을 마우스로 휠/드래그 시 iframe 위치를 강제 동기화
        html.window.parent?.postMessage(
          {
            'type': 'llai-drag',
            'dx': details.delta.dx,
            'dy': details.delta.dy,
          },
          '*',
        );
      },
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Lecture ',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              TextSpan(
                text: 'Hunter',
                style: TextStyle(
                  color: Color(0xFF14B8A6),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
            ],
          ),
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF5), width: 1)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '자막',
            selected: tab == LectureWidgetTab.caption,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.caption,
          ),
          _TabButton(
            label: '질문',
            selected: tab == LectureWidgetTab.question,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.question,
          ),
          _TabButton(
            label: '용어집',
            selected: tab == LectureWidgetTab.glossary,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.glossary,
          ),
          _TabButton(
            label: '요약',
            selected: tab == LectureWidgetTab.summary,
            onTap: () => ref.read(lectureWidgetTabProvider.notifier).state = LectureWidgetTab.summary,
          ),
          _TabButton(
            label: '설정',
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
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F6BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF667085),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    switch (tab) {
      case LectureWidgetTab.caption:
        return const _CaptionTab();
      case LectureWidgetTab.question:
        return _QuestionTab(controller: questionController);
      case LectureWidgetTab.glossary:
        return _GlossaryTab(controller: glossaryController);
      case LectureWidgetTab.summary:
        return const _SummaryTab();
      case LectureWidgetTab.settings:
        return const _SettingsTab();
    }
  }
}

class _CaptionTab extends ConsumerWidget {
  const _CaptionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = ref.watch(currentSubtitleProvider);
    final currentText = subtitle?.displayText.trim();
    final originalText = subtitle?.originalText.trim();

    return _PanelScroll(
      children: [
        const _SectionTitle(tab: LectureWidgetTab.caption, icon: Icons.closed_caption_rounded, title: '실시간 자막', subtitle: ''),
        const SizedBox(height: 14),
        _ResultCard(
          title: '현재 자막',
          body: currentText == null || currentText.isEmpty ? '자막 대기 중입니다.' : currentText,
          accentColor: const Color(0xFFE53935),
        ),
        if (originalText != null && originalText.isNotEmpty && originalText != currentText) ...[
          const SizedBox(height: 10),
          _ResultCard(title: '원문', body: originalText, accentColor: const Color(0xFF98A2B3)),
        ],
      ],
    );
  }
}

// 이미지 클릭 시 원본을 확대/축소하며 볼 수 있는 네이티브 모달 팝업 함수
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
    final state = ref.watch(questionResponseProvider);
    final answer = state.response?.answer.trim();
    final target = ref.watch(questionTargetProvider);
    final slideResult = ref.watch(lectureWidgetSlideProvider);
    
    final attachedImages = ref.watch(uploadedImagesProvider);
    final cardImages = ref.watch(vlmSentImagesCardProvider);
    final vlmQuery = ref.watch(vlmQueryProvider);

    return Column(
      children: [
        Expanded(
          child: _PanelScroll(
            children: [
              Row(
                children: [
                  const Expanded(child: _SectionTitle(tab: LectureWidgetTab.question, icon: Icons.help_outline_rounded, title: '익명 질문', subtitle: '')),
                  _SmallResetButton(
                    onTap: () {
                      controller.clear();
                      ref.invalidate(questionResponseProvider);
                      ref.invalidate(lectureWidgetSlideProvider);
                      ref.invalidate(uploadedImagesProvider); 
                      ref.invalidate(vlmSentImagesCardProvider);
                      ref.invalidate(vlmQueryProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _QuestionTargetToggle(
                target: target,
                onChanged: (newTarget) {
                  ref.read(questionTargetProvider.notifier).state = newTarget;
                  ref.invalidate(questionResponseProvider);
                  controller.clear();
                },
              ),
              const SizedBox(height: 14),

              if (target == QuestionTarget.ai) ...[
                _VlmCaptureButton(
                  isLoading: ref.watch(vlmLoadingStateProvider),
                  onTap: () async {
                    try {
                      final navigator = html.window.navigator;
                      final mediaDevices = navigator.mediaDevices;
                      final displayMediaPromise = js_util.callMethod(
                        mediaDevices!, 
                        'getDisplayMedia', 
                        [js_util.jsify({'video': true})]
                      );
                      
                      final html.MediaStream stream = await js_util.promiseToFuture(displayMediaPromise);
                      ref.read(vlmLoadingStateProvider.notifier).state = true;
                      ref.read(lectureWidgetSlideProvider.notifier).state = 'VLM 모델이 캡처 화면을 분석 중입니다...';

                      final videoTrack = stream.getVideoTracks().first;
                      final html.VideoElement videoElement = html.VideoElement()..srcObject = stream..autoplay = true;
                      await videoElement.onCanPlay.first;
                      
                      final canvas = html.CanvasElement(width: videoElement.videoWidth, height: videoElement.videoHeight);
                      canvas.context2D.drawImage(videoElement, 0, 0);
                      videoTrack.stop();
                      
                      final base64Snapshot = canvas.toDataUrl('image/png');
                      
                      ref.read(uploadedImagesProvider.notifier).state = [base64Snapshot];
                      ref.read(vlmSentImagesCardProvider.notifier).state = [base64Snapshot];
                      ref.read(vlmQueryProvider.notifier).state = "[전체 화면 캡처 분석 요청]";

                      const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
                      final response = await http.post(
                        Uri.parse('$apiBaseUrl/api/vlm/analyze'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'images': [base64Snapshot], 
                          'lecture_id': globalLectureId ?? 'lecture-default-room',
                          'question': '캡처된 화면 슬라이드의 내용을 상세하게 독해하고 설명해줘.',
                        }),
                      );

                      if (response.statusCode == 200) {
                        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
                        final resultText = decoded['analysis'] ?? '분석 실패';
                        
                        // [핵심] 상태를 먼저 확실하게 할당한 뒤 위젯 상태를 격발
                        ref.read(lectureWidgetSlideProvider.notifier).state = resultText;
                      } else {
                        ref.read(lectureWidgetSlideProvider.notifier).state = 'VLM 서버 에러 발생 (코드: ${response.statusCode})';
                      }
                    } catch (e) {
                      ref.read(lectureWidgetSlideProvider.notifier).state = '화면 캡처가 취소되었거나 에러가 발생했습니다.';
                    } finally {
                      ref.read(vlmLoadingStateProvider.notifier).state = false;
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (slideResult != '슬라이드 분석 결과가 여기에 표시됩니다.') ...[
                  _ResultCard(title: '슬라이드 시각 분석 결과', body: slideResult, accentColor: const Color(0xFF14B8A6)),
                  const SizedBox(height: 12),
                ],
              ],

              // 질문 완료 영역 이미지 클릭 시 대형 원본 뷰어 호출 연동
              if (vlmQuery != null && vlmQuery.isNotEmpty) ...[
                if (cardImages.isNotEmpty) ...[
                  Container(
                    height: 86,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cardImages.length,
                      itemBuilder: (context, idx) {
                        return GestureDetector(
                          onTap: () => _showOriginalImage(context, cardImages[idx]), 
                          child: Container(
                            width: 86,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE4E7EC)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(cardImages[idx], fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                _ResultCard(title: '질문', body: vlmQuery, accentColor: const Color(0xFFFB8C00)),
                const SizedBox(height: 10),
              ] else if (state.query.trim().isNotEmpty) ...[
                _ResultCard(title: '질문', body: state.query.trim(), accentColor: const Color(0xFFFB8C00)),
                const SizedBox(height: 10),
              ],
              
              _ResultCard(
                title: target == QuestionTarget.ai ? 'AI 답변' : '교수님께 전달 상태',
                body: target == QuestionTarget.ai
                    ? (answer == null || answer.isEmpty ? (vlmQuery != null ? slideResult : '질문을 입력하면 답변이 여기에 표시됩니다.') : answer)
                    : (state.query.trim().isNotEmpty ? '성공적으로 전달되었습니다! 교수님의 실시간 피드백을 기다려주세요.' : '교수님께 질문할 내용을 입력하세요.'),
                accentColor: const Color(0xFFFB8C00),
              ),
            ],
          ),
        ),
        
        // 하단 전송 대기열 프리뷰 썸네일 클릭 시 원본 모달 팝업 연동
        if (attachedImages.isNotEmpty)
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(color: Color(0xFFF9FAFB), border: Border(top: BorderSide(color: Color(0xFFE8ECF5)))),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: attachedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showOriginalImage(context, attachedImages[index]), 
                      child: Container(
                        width: 74,
                        height: 74,
                        margin: const EdgeInsets.only(top: 4, right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E7EC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFB8C00), width: 2), 
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(attachedImages[index], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 8,
                      child: InkWell(
                        onTap: () {
                          final newList = List<String>.from(attachedImages)..removeAt(index);
                          ref.read(uploadedImagesProvider.notifier).state = newList;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Color(0xFF667085), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        _InputArea(
          controller: controller,
          hintText: target == QuestionTarget.ai ? 'AI에게 궁금한 내용을 입력하세요.' : '교수님께 전달할 익명 질문을 입력하세요.',
          buttonIcon: Icons.send_rounded,
          onAttachTap: () {
            final html.FileUploadInputElement uploadInput = html.FileUploadInputElement()..accept = 'image/*'..multiple = true;
            uploadInput.click(); 
            uploadInput.onChange.listen((e) {
              final files = uploadInput.files;
              if (files != null) {
                for (var file in files) {
                  final reader = html.FileReader();
                  reader.readAsDataUrl(file); 
                  reader.onLoadEnd.listen((loadEvent) {
                    final currentList = ref.read(uploadedImagesProvider);
                    if (currentList.length < 5) {
                      ref.read(uploadedImagesProvider.notifier).state = [...currentList, reader.result as String];
                    }
                  });
                }
              }
            });
          },
          onSubmit: () async {
            final text = controller.text.trim();
            final currentImages = ref.read(uploadedImagesProvider);
            if (text.isEmpty && currentImages.isEmpty) return;

            if (currentImages.isNotEmpty && target == QuestionTarget.ai) {
              ref.read(vlmSentImagesCardProvider.notifier).state = currentImages;
              ref.read(vlmQueryProvider.notifier).state = text.isNotEmpty ? text : "[시각 자료 분석 요청]";
              ref.read(lectureWidgetSlideProvider.notifier).state = 'VLM 모듈이 다중 이미지를 취합하여 분석하는 중...';
              
              // 입력창 텍스트와 대기열 버퍼를 즉각 초기화하여 반응성 극대화
              controller.clear();
              ref.read(uploadedImagesProvider.notifier).state = [];
              ref.read(vlmLoadingStateProvider.notifier).state = true;

              try {
                const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
                final response = await http.post(
                  Uri.parse('$apiBaseUrl/api/vlm/analyze'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'images': currentImages, 
                    'lecture_id': globalLectureId ?? 'lecture-default-room',
                    'question': text.isNotEmpty ? text : '이 사진들에 대해 상세히 설명해줘.',
                  }),
                );

                if (response.statusCode == 200) {
                  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
                  final resultText = decoded['analysis'] ?? '판독 실패';

                  ref.read(lectureWidgetSlideProvider.notifier).state = resultText;
                }
              } catch (e) {
                ref.read(lectureWidgetSlideProvider.notifier).state = 'VLM 연동 실패 에러: $e';
              } finally {
                ref.read(vlmLoadingStateProvider.notifier).state = false;
              }
              return;
            }

            ref.read(questionModeProvider.notifier).state = QuestionMode.professor;
            await ref.read(questionResponseProvider.notifier).submit(text, target);
            controller.clear();
          },
        ),
      ],
    );
  }
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
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFFFCC80))),
          child: const Icon(Icons.refresh_rounded, size: 17, color: Color(0xFFFB8C00)),
        ),
      ),
    );
  }
}

class _GlossaryTab extends ConsumerWidget {
  final TextEditingController controller;
  const _GlossaryTab({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(glossarySearchProvider);
    final isLoading = ref.watch(glossaryLoadingProvider);

    ref.listen(glossarySearchProvider, (_, next) {
      if (next.results.isNotEmpty) {
        ref.read(glossaryLoadingProvider.notifier).state = false;
      }
    });

    return Column(
      children: [
        Expanded(
          child: _PanelScroll(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      tab: LectureWidgetTab.glossary, 
                      icon: Icons.menu_book_rounded, 
                      title: '용어집 조회', 
                      subtitle: ''
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9A825).withValues(alpha: 0.1), 
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF9A825), size: 20),
                      onPressed: () {
                        ref.invalidate(glossarySearchProvider);
                        ref.read(glossaryLoadingProvider.notifier).state = false;
                        controller.clear();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              // AI 및 DB 검색 엔진 작동 UI 구역
              if (isLoading) ...[
                const SizedBox(height: 80),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFF9A825)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '로컬 AI 전공 사전에서 정의 생성 중...',
                        style: TextStyle(
                          color: Colors.black45, 
                          fontSize: 13, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (state.results.isEmpty) ...[
                const _ResultCard(
                  title: '검색 결과', 
                  body: '용어를 입력하면 설명이 여기에 표시됩니다.', 
                  accentColor: Color(0xFFF9A825)
                )
              ] else ...[
                ...state.results.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultCard(
                    title: item.term, 
                    body: item.definition, 
                    accentColor: const Color(0xFFF9A825)
                  ),
                )),
              ],
            ],
          ),
        ),
        _InputArea(
          controller: controller, 
          hintText: '용어를 입력하세요.', 
          buttonIcon: Icons.search_rounded,
          onSubmit: () {
            final text = controller.text.trim();
            if (text.isEmpty) return;

            ref.read(glossaryLoadingProvider.notifier).state = true;
            ref.read(glossarySearchProvider.notifier).search(text);
            controller.clear();
          },
        ),
      ],
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(lectureWidgetSummaryProvider);
    return _PanelScroll(
      children: [
        const _SectionTitle(tab: LectureWidgetTab.summary, icon: Icons.summarize_rounded, title: '핵심 요약', subtitle: ''),
        const SizedBox(height: 14),
        _ResultCard(title: '요약 결과', body: summary, accentColor: const Color(0xFF43A047)),
        const SizedBox(height: 12),
        const _InfoBox(text: '요약 API 연결은 다음 단계에서 이 탭 내부로 붙이면 됩니다.'),
      ],
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = ref.watch(lectureWidgetOpacityProvider);
    final width = ref.watch(lectureWidgetWidthProvider);
    final fontScale = ref.watch(lectureWidgetFontScaleProvider);

    return _PanelScroll(
      children: [
        const _SectionTitle(tab: LectureWidgetTab.settings, icon: Icons.settings_rounded, title: '위젯 설정', subtitle: ''),
        const SizedBox(height: 18),
        _SettingSlider(title: '패널 투명도', valueText: '${(opacity * 100).round()}%', value: opacity, min: 0.20, max: 1.0, divisions: 16, onChanged: (v) => ref.read(lectureWidgetOpacityProvider.notifier).state = v),
        const SizedBox(height: 18),
        _SettingSlider(
          title: '패널 너비',
          valueText: '${width.round()}px',
          value: width,
          min: 300,
          max: 460,
          divisions: 8,
          onChanged: (value) {
            // 내부 플러터 패널 크기 인프라 상태 반영
            ref.read(lectureWidgetWidthProvider.notifier).state = value;
            
            // 부모 크롬 레이어 창에 +48px 여유 마진을 주어 실시간 프레임 리사이징 단행
            html.window.parent?.postMessage(
              {
                'type': 'llai-resize',
                'width': value.toInt() + 48,
              },
              '*',
            );
          },
        ),
        const SizedBox(height: 18),
        _SettingSlider(title: '글자 크기', valueText: '${(fontScale * 100).round()}%', value: fontScale, min: 0.9, max: 1.2, divisions: 6, onChanged: (v) => ref.read(lectureWidgetFontScaleProvider.notifier).state = v),
        const SizedBox(height: 22),
        _HideWidgetButton(onTap: () => ref.read(lectureWidgetVisibleProvider.notifier).state = false),
      ],
    );
  }
}

class _HideWidgetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HideWidgetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15), onTap: onTap,
      child: Container(
        width: double.infinity, height: 46, alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFB2CCFF))),
        child: const Text('위젯 숨기기', style: TextStyle(color: Color(0xFF2F6BFF), fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String title; final String valueText; final double value; final double min; final double max; final int divisions; final ValueChanged<double> onChanged;
  const _SettingSlider({required this.title, required this.valueText, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE4E7EC))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF344054), fontSize: 13, fontWeight: FontWeight.w800))),
              Text(valueText, style: const TextStyle(color: Color(0xFF2F6BFF), fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
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
              Text(title, style: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.w900)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, height: 1.25, fontWeight: FontWeight.w500)),
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
                  Text(title, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          decoration: BoxDecoration(color: selected ? const Color(0xFFFB8C00) : Colors.transparent, borderRadius: BorderRadius.circular(7)),
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
                  Text('현재 화면 캡처해서 AI 질문', style: TextStyle(color: Color(0xFF0D9488), fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
      ),
    );
  }
}