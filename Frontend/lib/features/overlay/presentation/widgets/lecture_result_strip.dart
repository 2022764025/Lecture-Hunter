// lib/features/overlay/presentation/widgets/lecture_result_strip.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../caption/presentation/controllers/caption_controller.dart';

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
      return const Color(0xFFE53935); // 자막: 빨강
    case LectureWidgetTab.question:
      return const Color(0xFFFB8C00); // 질문: 주황
    case LectureWidgetTab.glossary:
      return const Color(0xFFF9A825); // 용어집: 노랑
    case LectureWidgetTab.summary:
      return const Color(0xFF43A047); // 요약: 초록
    case LectureWidgetTab.settings:
      return const Color(0xFF2F6BFF); // 설정: 파랑
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

class LectureFloatingWidget extends ConsumerStatefulWidget {
  const LectureFloatingWidget({super.key});

  @override
  ConsumerState<LectureFloatingWidget> createState() =>
      _LectureFloatingWidgetState();
}

class _LectureFloatingWidgetState extends ConsumerState<LectureFloatingWidget> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _glossaryController = TextEditingController();

  @override
  void dispose() {
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

  const _WidgetHeader({
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
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
    );
  }
}

class _TabBar extends ConsumerWidget {
  final LectureWidgetTab tab;

  const _TabBar({
    required this.tab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE8ECF5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '자막',
            selected: tab == LectureWidgetTab.caption,
            onTap: () {
              ref.read(lectureWidgetTabProvider.notifier).state =
                  LectureWidgetTab.caption;
            },
          ),
          _TabButton(
            label: '질문',
            selected: tab == LectureWidgetTab.question,
            onTap: () {
              ref.read(lectureWidgetTabProvider.notifier).state =
                  LectureWidgetTab.question;
            },
          ),
          _TabButton(
            label: '용어집',
            selected: tab == LectureWidgetTab.glossary,
            onTap: () {
              ref.read(lectureWidgetTabProvider.notifier).state =
                  LectureWidgetTab.glossary;
            },
          ),
          _TabButton(
            label: '요약',
            selected: tab == LectureWidgetTab.summary,
            onTap: () {
              ref.read(lectureWidgetTabProvider.notifier).state =
                  LectureWidgetTab.summary;
            },
          ),
          _TabButton(
            label: '설정',
            selected: tab == LectureWidgetTab.settings,
            onTap: () {
              ref.read(lectureWidgetTabProvider.notifier).state =
                  LectureWidgetTab.settings;
            },
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
        const _SectionTitle(
          tab: LectureWidgetTab.caption,
          icon: Icons.closed_caption_rounded,
          title: '실시간 자막',
          subtitle: '',
        ),
        const SizedBox(height: 14),
        _ResultCard(
          title: '현재 자막',
          body: currentText == null || currentText.isEmpty
              ? '자막 대기 중입니다.'
              : currentText,
          accentColor: const Color(0xFFE53935),
        ),
        if (originalText != null &&
            originalText.isNotEmpty &&
            originalText != currentText) ...[
          const SizedBox(height: 10),
          _ResultCard(
            title: '원문',
            body: originalText,
            accentColor: const Color(0xFF98A2B3),
          ),
        ],
      ],
    );
  }
}

class _QuestionTab extends ConsumerWidget {
  final TextEditingController controller;

  const _QuestionTab({
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionResponseProvider);
    final answer = state.response?.answer.trim();
    final target = ref.watch(questionTargetProvider);

    return Column(
      children: [
        Expanded(
          child: _PanelScroll(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      tab: LectureWidgetTab.question,
                      icon: Icons.help_outline_rounded,
                      title: '익명 질문',
                      subtitle: '',
                    ),
                  ),
                  _SmallResetButton(
                    onTap: () {
                      controller.clear();
                      ref.invalidate(questionResponseProvider);
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

              if (state.query.trim().isNotEmpty)
                _ResultCard(
                  title: '질문',
                  body: state.query.trim(),
                  accentColor: const Color(0xFFFB8C00),
                ),
              if (state.query.trim().isNotEmpty) const SizedBox(height: 10),
              
              _ResultCard(
                title: target == QuestionTarget.ai ? 'AI 답변' : '교수님께 전달 상태',
                body: target == QuestionTarget.ai
                    ? (answer == null || answer.isEmpty
                        ? '질문을 입력하면 답변이 여기에 표시됩니다.' 
                        : answer)
                    : (() {
                        // [컴파일 에러 해결] switch-case 상수의 strict한 제약을 우회하기 위해 if-else 문자열 매핑망으로 전환
                        final statusStr = state.status.toString();
                        if (statusStr.contains('loading')) {
                          return '교수님께 익명 질문을 전송하는 중입니다...';
                        } else if (statusStr.contains('success')) {
                          return '성공적으로 전달되었습니다! 교수님의 실시간 답변이나 수업 중 피드백을 기다려주세요.';
                        } else if (statusStr.contains('error')) {
                          return '전송 실패: 백엔드 서버 상태를 확인해 주세요.';
                        } else {
                          return '교수님께 익명으로 질문할 내용을 아래에 입력하세요.';
                        }
                      }()),
                accentColor: const Color(0xFFFB8C00),
              ),
            ],
          ),
        ),
        _InputArea(
          controller: controller,
          hintText: target == QuestionTarget.ai
              ? 'AI에게 궁금한 내용을 입력하세요.'
              : '교수님께 전달할 익명 질문을 입력하세요.',
          buttonIcon: Icons.send_rounded,
          onSubmit: () async {
            final text = controller.text.trim();
            if (text.isEmpty) {
              return;
            }

            ref.read(questionModeProvider.notifier).state =
                QuestionMode.professor;

            await ref.read(questionResponseProvider.notifier).submit(
                  text,
                  target,
                );

            controller.clear();
          },
        ),
      ],
    );
  }
}

class _SmallResetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SmallResetButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '질문 초기화',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFCC80),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 17,
            color: Color(0xFFFB8C00),
          ),
        ),
      ),
    );
  }
}

class _GlossaryTab extends ConsumerWidget {
  final TextEditingController controller;

  const _GlossaryTab({
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(glossarySearchProvider);

    return Column(
      children: [
        Expanded(
          child: _PanelScroll(
            children: [
              const _SectionTitle(
                tab: LectureWidgetTab.glossary,
                icon: Icons.menu_book_rounded,
                title: '용어집 조회',
                subtitle: '',
              ),
              const SizedBox(height: 14),
              if (state.results.isEmpty)
                const _ResultCard(
                  title: '검색 결과',
                  body: '용어를 입력하면 설명이 여기에 표시됩니다.',
                  accentColor: Color(0xFFF9A825),
                )
              else
                ...state.results.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ResultCard(
                      title: item.term,
                      body: item.definition,
                      accentColor: const Color(0xFFF9A825),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _InputArea(
          controller: controller,
          hintText: '용어를 입력하세요.',
          buttonIcon: Icons.search_rounded,
          onSubmit: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              return;
            }

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
        const _SectionTitle(
          tab: LectureWidgetTab.summary,
          icon: Icons.summarize_rounded,
          title: '핵심 요약',
          subtitle: '',
        ),
        const SizedBox(height: 14),
        _ResultCard(
          title: '요약 결과',
          body: summary,
          accentColor: const Color(0xFF43A047),
        ),
        const SizedBox(height: 12),
        const _InfoBox(
          text: '요약 API 연결은 다음 단계에서 이 탭 내부로 붙이면 됩니다.',
        ),
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
        const _SectionTitle(
          tab: LectureWidgetTab.settings,
          icon: Icons.settings_rounded,
          title: '위젯 설정',
          subtitle: '',
        ),
        const SizedBox(height: 18),
        _SettingSlider(
          title: '패널 투명도',
          valueText: '${(opacity * 100).round()}%',
          value: opacity,
          min: 0.20,
          max: 1.0,
          divisions: 16,
          onChanged: (value) {
            ref.read(lectureWidgetOpacityProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 18),
        _SettingSlider(
          title: '패널 너비',
          valueText: '${width.round()}px',
          value: width,
          min: 300,
          max: 460,
          divisions: 8,
          onChanged: (value) {
            ref.read(lectureWidgetWidthProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 18),
        _SettingSlider(
          title: '글자 크기',
          valueText: '${(fontScale * 100).round()}%',
          value: fontScale,
          min: 0.9,
          max: 1.2,
          divisions: 6,
          onChanged: (value) {
            ref.read(lectureWidgetFontScaleProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 22),
        _HideWidgetButton(
          onTap: () {
            ref.read(lectureWidgetVisibleProvider.notifier).state = false;
          },
        ),
      ],
    );
  }
}

class _HideWidgetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HideWidgetButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFB2CCFF),
            width: 1,
          ),
        ),
        child: const Text(
          '위젯 숨기기',
          style: TextStyle(
            color: Color(0xFF2F6BFF),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: Color(0xFF2F6BFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PanelScroll extends StatelessWidget {
  final List<Widget> children;

  const _PanelScroll({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: children,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final LectureWidgetTab tab;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.tab,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _tabAccentColor(tab);
    final softColor = _tabSoftColor(tab);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String body;
  final Color accentColor;

  const _ResultCard({
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    body,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Color(0xFF344054),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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

  const _InfoBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFEDF89),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF93370D),
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData buttonIcon;
  final VoidCallback onSubmit;

  const _InputArea({
    required this.controller,
    required this.hintText,
    required this.buttonIcon,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8ECF5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: Color(0xFFE4E7EC),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: Color(0xFFE4E7EC),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(
                      color: Color(0xFF2F6BFF),
                    ),
                  ),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onSubmit,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2F6BFF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                buttonIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTargetToggle extends StatelessWidget {
  final QuestionTarget target;
  final ValueChanged<QuestionTarget> onChanged;

  const _QuestionTargetToggle({
    required this.target,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          _TargetTabButton(
            label: 'AI에게 질문',
            selected: target == QuestionTarget.ai,
            onTap: () => onChanged(QuestionTarget.ai),
          ),
          _TargetTabButton(
            label: '교수님께 익명 질문',
            selected: target == QuestionTarget.professor,
            onTap: () => onChanged(QuestionTarget.professor),
          ),
        ],
      ),
    );
  }
}

class _TargetTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFB8C00) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF667085),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}