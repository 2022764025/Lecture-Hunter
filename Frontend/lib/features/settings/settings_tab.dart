import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../overlay/widget_state.dart';

/// 설정 탭: 불투명도 · 너비 · 높이 · 전체 글자 크기 (슬라이더 + 숫자 직접 입력). 값은 브라우저에 저장된다.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  static const _items = [
    ('opacity', '불투명도', '%'),
    ('width', '너비', 'px'),
    ('height', '높이', 'px'),
    ('textSize', '전체 글자 크기', '%'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(widgetSettingsProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          for (final (i, (key, label, unit)) in _items.indexed) ...[
            if (i > 0) ...[
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
            ],
            _SettingItem(
              settingKey: key,
              label: label,
              unit: unit,
              value: settings.get(key),
              range: WidgetSettings.ranges[key]!,
              last: i == _items.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingItem extends ConsumerStatefulWidget {
  const _SettingItem({
    required this.settingKey,
    required this.label,
    required this.unit,
    required this.value,
    required this.range,
    required this.last,
  });

  final String settingKey;
  final String label;
  final String unit;
  final int value;
  final ({int min, int max}) range;
  final bool last;

  @override
  ConsumerState<_SettingItem> createState() => _SettingItemState();
}

class _SettingItemState extends ConsumerState<_SettingItem> {
  late final TextEditingController _number = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_number.text, clampText: true);
    });
  }

  @override
  void didUpdateWidget(covariant _SettingItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _number.text != '${widget.value}') _number.text = '${widget.value}';
  }

  @override
  void dispose() {
    _number.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String text, {bool clampText = false}) {
    final v = int.tryParse(text);
    if (v == null) {
      if (clampText) _number.text = '${widget.value}';
      return;
    }
    ref.read(widgetSettingsProvider.notifier).set(widget.settingKey, v);
    if (clampText) _number.text = '${v.clamp(widget.range.min, widget.range.max)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.range;
    return Padding(
      padding: EdgeInsets.only(top: 3, bottom: widget.last ? 11 : 15),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label, style: em(0.98, weight: FontWeight.w700))),
              SizedBox(
                width: 46,
                child: TextField(
                  controller: _number,
                  focusNode: _focus,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  onChanged: (t) => _commit(t),
                  onSubmitted: (t) => _commit(t, clampText: true),
                  style: em(1, weight: FontWeight.w800, color: AppColors.sageDark),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                    border: InputBorder.none,
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.sage),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    filled: _focus.hasFocus,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              Text(widget.unit, style: em(1, weight: FontWeight.w800, color: AppColors.sageDark)),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.sage,
              inactiveTrackColor: AppColors.track,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const _RingThumb(),
              trackShape: const RoundedRectSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              // 디자인처럼 트랙이 카드 안쪽 끝까지 닿게 한다 (손잡이 반지름만큼만 여백)
              padding: const EdgeInsets.symmetric(horizontal: 7.5),
              value: widget.value.clamp(r.min, r.max).toDouble(),
              min: r.min.toDouble(),
              max: r.max.toDouble(),
              onChanged: (v) => ref.read(widgetSettingsProvider.notifier).set(widget.settingKey, v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 디자인의 흰 원 + 초록 테두리 슬라이더 손잡이
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(15, 15);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      6.75,
      Paint()
        ..color = AppColors.sage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
