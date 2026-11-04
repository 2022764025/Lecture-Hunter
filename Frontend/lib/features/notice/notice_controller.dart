import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../session/session_controller.dart';

class NoticeState {
  final List<LectureNotice> items;
  final bool loading;
  final String? error;
  const NoticeState({this.items = const [], this.loading = false, this.error});
}

/// 이 강의 공지 + 전체 공지(lecture_id 없음). Supabase 대시보드에서 넣으면 Realtime으로 바로 보인다.
class NoticeController extends Notifier<NoticeState> {
  Timer? _fallbackTimer;

  @override
  NoticeState build() {
    final lectureId = ref.watch(lectureIdProvider);
    final realtime = ref.watch(realtimeProvider);
    ref.onDispose(() => _fallbackTimer?.cancel());
    if (lectureId == null) return const NoticeState();

    if (realtime != null) {
      final sub = realtime.noticeChanges.listen((change) {
        final items = [...state.items]..removeWhere((n) => n.id == change.id);
        if (change.kind == ChangeKind.upsert) items.add(change.row!);
        state = NoticeState(items: _sorted(items));
      });
      ref.onDispose(sub.cancel);
    }
    ref.listen<AsyncValue<SyncStatus>>(syncStatusProvider, (_, next) {
      final polling = next.valueOrNull == SyncStatus.polling || next.valueOrNull == SyncStatus.error;
      _fallbackTimer?.cancel();
      _fallbackTimer = polling ? Timer.periodic(const Duration(seconds: 30), (_) => load()) : null;
    });
    Future.microtask(load);
    return const NoticeState(loading: true);
  }

  List<LectureNotice> _sorted(List<LectureNotice> items) => items
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

  Future<void> load() async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) return;
    try {
      state = NoticeState(items: _sorted(await ref.read(apiProvider).notices(lectureId)));
    } on ApiException catch (e) {
      state = NoticeState(items: state.items, error: e.message);
    }
  }
}

final noticeProvider = NotifierProvider<NoticeController, NoticeState>(NoticeController.new);
