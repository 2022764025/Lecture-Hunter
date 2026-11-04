import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../session/session_controller.dart';
import 'summary_controller.dart';

/// 요약 탭. 시간은 강의 시작(첫 자막)부터 흐른 "시:분"이다.
/// - 프리셋을 누르면 강의 경과 시간을 기준으로 시작·종료 시간을 채운다 (디자인과 같은 동작)
/// - 전체 구간 → 전체 요약, 최근 10/30분 → 최근 N분 요약, 직접 선택 → 입력한 구간 요약
class SummaryTab extends ConsumerStatefulWidget {
  const SummaryTab({super.key});

  @override
  ConsumerState<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<SummaryTab> {
  final _startH = TextEditingController(text: '00');
  final _startM = TextEditingController(text: '00');
  final _endH = TextEditingController(text: '00');
  final _endM = TextEditingController(text: '00');
  SummaryPreset _preset = SummaryPreset.custom;
  String? _inputError;

  @override
  void dispose() {
    for (final c in [_startH, _startM, _endH, _endM]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 강의 경과 시간(분). 화면 표시는 내림, 프리셋의 종료 시간은 마지막 자막까지 들어가도록 올림.
  int _elapsedMinutes({bool roundUp = false}) {
    final status = ref.read(lectureStatusProvider);
    if (status == null) return 0;
    final minutes = status.elapsed.inSeconds / 60;
    return roundUp ? minutes.ceil() : minutes.floor();
  }

  void _setTimes(int start, int end) {
    String two(int v) => v.toString().padLeft(2, '0');
    _startH.text = two(start ~/ 60);
    _startM.text = two(start % 60);
    _endH.text = two(end ~/ 60);
    _endM.text = two(end % 60);
  }

  void _choose(SummaryPreset preset) {
    final e = _elapsedMinutes(roundUp: true);
    setState(() {
      _preset = preset;
      _inputError = null;
      switch (preset) {
        case SummaryPreset.full:
          _setTimes(0, e);
        case SummaryPreset.recent10:
          _setTimes((e - 10).clamp(0, e), e);
        case SummaryPreset.recent30:
          _setTimes((e - 30).clamp(0, e), e);
        case SummaryPreset.custom:
          break;
      }
    });
  }

  void _onEdited() {
    if (_preset != SummaryPreset.custom || _inputError != null) {
      setState(() {
        _preset = SummaryPreset.custom;
        _inputError = null;
      });
    }
  }

  void _submit() {
    if (_preset != SummaryPreset.custom) {
      final start = _minutes(_startH, _startM) ?? 0;
      final end = _minutes(_endH, _endM) ?? 0;
      ref.read(summaryProvider.notifier).run(_preset, start, end);
      return;
    }
    final start = _minutes(_startH, _startM);
    final end = _minutes(_endH, _endM);
    if (start == null || end == null) {
      setState(() => _inputError = '시·분 값을 올바르게 입력해 주세요. (분은 0~59)');
      return;
    }
    if (end <= start) {
      setState(() => _inputError = '종료 시간은 시작 시간보다 늦어야 합니다.');
      return;
    }
    setState(() => _inputError = null);
    _setTimes(start, end);
    ref.read(summaryProvider.notifier).run(SummaryPreset.custom, start, end);
  }

  int? _minutes(TextEditingController h, TextEditingController m) {
    final hour = int.tryParse(h.text.trim());
    final minute = int.tryParse(m.text.trim());
    if (hour == null || minute == null || hour < 0 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(summaryProvider);
    ref.watch(lectureStatusProvider); // 강의 경과 시간 갱신
    final filled = state.result != null && !(state.result!.empty);
    final error = _inputError ?? state.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          color: Colors.transparent,
          border: AppColors.border,
          padding: const EdgeInsets.fromLTRB(13, 15, 13, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('요약할 시간 설정', style: em(1.05, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('강의 경과 ${formatHm(_elapsedMinutes())}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: em(0.82, color: AppColors.muted)),
                  ),
                  Text('시 : 분', style: em(0.82, color: AppColors.unitHint)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _TimeGroup(label: '시작 시간', hour: _startH, minute: _startM, onEdited: _onEdited)),
                  const SizedBox(width: 27),
                  Expanded(child: _TimeGroup(label: '종료 시간', hour: _endH, minute: _endM, onEdited: _onEdited)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        EqualRow(
          gap: 8,
          children: [
            for (final p in SummaryPreset.values)
              ChoiceButton(
                label: p.label,
                selected: _preset == p,
                height: 43,
                fontEm: 0.86,
                color: AppColors.subtab,
                selectedWeight: FontWeight.w700,
                onTap: () => _choose(p),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ActionButton(
          style: ActionStyle.primary,
          label: state.loading ? '요약 중…' : '요약하기',
          loading: state.loading,
          onTap: state.loading ? null : _submit,
        ),
        const SizedBox(height: 11),
        Panel(
          color: Colors.transparent,
          border: AppColors.border,
          minHeight: 145,
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('AI 요약 결과', style: em(1.03, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              if (state.loading)
                Text('${state.rangeLabel ?? ''} 자막을 요약하는 중입니다. (10~30초)', style: em(0.86, color: AppColors.subtab, height: 1.7))
              else if (state.result == null)
                Text('선택한 구간의 핵심 내용이 여기에 표시됩니다.', style: em(0.86, color: AppColors.subtab, height: 1.7))
              else ...[
                if (state.rangeLabel != null)
                  Text(state.rangeLabel!, style: em(0.86, weight: FontWeight.w700, color: AppColors.summaryText, height: 1.7)),
                Text(
                  state.result!.summary,
                  style: em(0.86, color: filled ? AppColors.summaryText : AppColors.subtab, height: 1.7),
                ),
                if (state.result!.keyPoints.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final k in state.result!.keyPoints) TagChip(k)]),
                ],
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error, style: em(0.8, color: AppColors.error)),
        ],
      ],
    );
  }
}

class _TimeGroup extends StatelessWidget {
  const _TimeGroup({required this.label, required this.hour, required this.minute, required this.onEdited});
  final String label;
  final TextEditingController hour;
  final TextEditingController minute;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: em(0.88, color: AppColors.muted)),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: _TimeField(controller: hour, maxValue: 99, onEdited: onEdited)),
            SizedBox(
              width: 22,
              child: Text(':', textAlign: TextAlign.center, style: em(1.3, weight: FontWeight.w700)),
            ),
            Expanded(child: _TimeField(controller: minute, maxValue: 59, onEdited: onEdited)),
          ],
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.controller, required this.maxValue, required this.onEdited});
  final TextEditingController controller;
  final int maxValue;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Focus(
        onFocusChange: (focused) {
          // 디자인처럼 입력을 마치면 두 자리로 맞춘다 (예: 5 → 05)
          if (focused) return;
          final v = int.tryParse(controller.text.trim());
          if (v != null && v >= 0 && v <= maxValue) controller.text = v.toString().padLeft(2, '0');
        },
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
          onChanged: (_) => onEdited(),
          style: em(1.15, color: AppColors.timeInput),
          decoration: fieldDecoration(hint: '', padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2)),
        ),
      ),
    );
  }
}
