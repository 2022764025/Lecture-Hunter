import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../caption/caption_controller.dart';
import '../session/session_controller.dart';

/// 디자인의 프리셋 버튼
enum SummaryPreset { full, recent10, recent30, custom }

extension SummaryPresetLabel on SummaryPreset {
  String get label => const ['전체 구간', '최근 10분', '최근 30분', '직접 선택'][index];
}

class SummaryState {
  final bool loading;
  final SummaryResult? result;
  final String? rangeLabel;
  final String? error;
  const SummaryState({this.loading = false, this.result, this.rangeLabel, this.error});
}

String formatHm(int totalMinutes) {
  final m = totalMinutes < 0 ? 0 : totalMinutes;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

class SummaryController extends Notifier<SummaryState> {
  @override
  SummaryState build() {
    ref.watch(lectureIdProvider);
    return const SummaryState();
  }

  /// startMin/endMin은 강의 시작(첫 자막) 기준 분.
  /// 전체 구간 → 전체 요약, 최근 N분 → 최근 N분 요약, 직접 선택 → 구간 요약 API를 쓴다.
  Future<void> run(SummaryPreset preset, int startMin, int endMin) async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) {
      state = const SummaryState(error: '강의에 연결된 뒤 요약할 수 있습니다.');
      return;
    }
    final label = preset == SummaryPreset.full ? '전체 구간' : '${formatHm(startMin)} ~ ${formatHm(endMin)} 구간';
    state = SummaryState(loading: true, rangeLabel: label);
    final api = ref.read(apiProvider);
    final lang = ref.read(captionLanguageProvider);
    try {
      final result = switch (preset) {
        SummaryPreset.full => await api.summaryFull(lectureId, lang),
        SummaryPreset.recent10 => await api.summaryRecent(lectureId, 10, lang),
        SummaryPreset.recent30 => await api.summaryRecent(lectureId, 30, lang),
        SummaryPreset.custom => await api.summaryRange(lectureId, startMin, endMin, lang),
      };
      state = SummaryState(result: result, rangeLabel: label);
    } on ApiException catch (e) {
      state = SummaryState(error: e.message, rangeLabel: label);
    }
  }
}

final summaryProvider = NotifierProvider<SummaryController, SummaryState>(SummaryController.new);
