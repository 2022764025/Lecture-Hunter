import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/web/host_bridge.dart';
import '../../shared/ui.dart';
import '../caption/caption_tab.dart';
import '../notice/notice_tab.dart';
import '../question/question_tab.dart';
import '../settings/settings_tab.dart';
import '../summary/summary_tab.dart';
import 'widget_state.dart';

const double kCollapsedHeight = 53;

/// Lecture-Hunter 위젯 본체 (과제헌터.html 의 .widget)
class LectureWidget extends ConsumerStatefulWidget {
  const LectureWidget({super.key, this.shadow = true});

  /// 단독 실행 화면에서만 그림자를 그린다. 크롬 확장에서는 iframe 자체에 그림자를 준다.
  final bool shadow;

  @override
  ConsumerState<LectureWidget> createState() => _LectureWidgetState();
}

class _LectureWidgetState extends ConsumerState<LectureWidget> {
  final _identityKey = GlobalKey();
  final _rootKey = GlobalKey();
  String? _lastLayout;

  /// 부모 창(크롬 확장)에 위젯 크기와 드래그 손잡이 위치를 알린다
  void _reportLayout(WidgetSettings settings, bool minimized) {
    if (!HostBridge.embedded) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final width = settings.width.toDouble();
      final height = minimized ? kCollapsedHeight : settings.height.toDouble();
      var handle = Rectangle(0, 0, width - 120, kCollapsedHeight); // 접힌 상태: "펼치기 +" 버튼은 비워둔다
      final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
      final identity = _identityKey.currentContext?.findRenderObject() as RenderBox?;
      if (!minimized && root != null && identity != null && identity.hasSize) {
        final offset = identity.localToGlobal(Offset.zero, ancestor: root);
        // 로고·제목 줄 전체에서 오른쪽 최소화 버튼(약 44px)만 뺀다
        handle = Rectangle(0, 0, offset.dx + identity.size.width - 44, offset.dy + identity.size.height + 6);
      }
      final key = '$width/$height/$minimized/${handle.width.round()}/${handle.height.round()}';
      if (key == _lastLayout) return;
      _lastLayout = key;
      HostBridge.layout(width: width, height: height, minimized: minimized, dragHandle: handle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(widgetSettingsProvider);
    final minimized = ref.watch(minimizedProvider);
    final toast = ref.watch(toastProvider);
    _reportLayout(settings, minimized);

    final height = minimized ? kCollapsedHeight : settings.height.toDouble();
    return LayoutBuilder(builder: (context, constraints) {
      // iframe 크기가 아직 안 바뀌었으면 들어갈 만큼만 그린다 (크기 보고는 원래 설정값으로)
      final w = settings.width.toDouble().clamp(0.0, constraints.maxWidth);
      final h = height.clamp(0.0, constraints.maxHeight);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.textSize / 100)),
        child: AnimatedContainer(
          key: _rootKey,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: settings.opacity / 100),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.border),
            boxShadow: widget.shadow
                ? const [BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 10))]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: minimized
                ? _CollapsedBar(onRestore: () => ref.read(minimizedProvider.notifier).state = false)
                : Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(identityKey: _identityKey),
                          const Expanded(child: _Content()),
                        ],
                      ),
                      _Toast(message: toast),
                    ],
                  ),
          ),
        ),
      );
    });
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.identityKey});
  final GlobalKey identityKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(widgetTabProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 0),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: identityKey,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.sageSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(AppIcons.logo, size: 21, color: AppColors.sageDark),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lecture-Hunter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: em(1.15, weight: FontWeight.w700, height: 1.25, letterSpacing: -0.3)),
                    const SizedBox(height: 1),
                    Text('강의가 조금 더 쉬워지는 그날까지',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: em(0.66, color: AppColors.tagline, height: 1.4)),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Tooltip(
                  message: '위젯 최소화',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => ref.read(minimizedProvider.notifier).state = true,
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(
                          child: Text('−',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(fontSize: 23, height: 1, color: AppColors.minimize)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          EqualRow(
            gap: 7,
            children: [
              for (final t in WidgetTab.values)
                ChoiceButton(
                  label: t.label,
                  selected: t == tab,
                  onTap: () => ref.read(widgetTabProvider.notifier).state = t,
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  static const _padding = {
    WidgetTab.caption: EdgeInsets.fromLTRB(15, 24, 15, 18),
    WidgetTab.question: EdgeInsets.fromLTRB(15, 20, 15, 18),
    WidgetTab.notice: EdgeInsets.fromLTRB(15, 15, 15, 18),
    WidgetTab.summary: EdgeInsets.fromLTRB(14, 19, 14, 19),
    WidgetTab.settings: EdgeInsets.fromLTRB(15, 19, 15, 18),
  };

  static const _pages = {
    WidgetTab.caption: CaptionTab(),
    WidgetTab.question: QuestionTab(),
    WidgetTab.notice: NoticeTab(),
    WidgetTab.summary: SummaryTab(),
    WidgetTab.settings: SettingsTab(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(widgetTabProvider);
    // 탭을 옮겨도 각 탭의 입력값·스크롤 위치가 유지되도록 IndexedStack을 쓴다
    return IndexedStack(
      index: tab.index,
      sizing: StackFit.expand,
      children: [
        for (final t in WidgetTab.values) _ScrollPage(padding: _padding[t]!, child: _pages[t]!),
      ],
    );
  }
}

class _ScrollPage extends StatefulWidget {
  const _ScrollPage({required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  State<_ScrollPage> createState() => _ScrollPageState();
}

class _ScrollPageState extends State<_ScrollPage> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.onRestore});
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onRestore,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Text('Lecture-Hunter', style: em(1, weight: FontWeight.w700, color: AppColors.sageDark)),
              const Spacer(),
              Text('펼치기 +', style: em(1, weight: FontWeight.w700, color: AppColors.sageDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final visible = message != null;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 19,
      child: IgnorePointer(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: visible ? Offset.zero : const Offset(0, 0.4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: visible ? 1 : 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: AppColors.toast, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  message ?? '',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
