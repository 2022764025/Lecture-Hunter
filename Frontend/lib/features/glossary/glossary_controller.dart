import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../caption/caption_controller.dart';
import '../session/session_controller.dart';

enum LoadStatus { idle, loading, done, error }

// ─── 용어 검색 ────────────────────────────────────────────────

class GlossarySearchState {
  final LoadStatus status;
  final String query;
  final List<GlossaryEntry> results;
  final String? error;

  const GlossarySearchState({this.status = LoadStatus.idle, this.query = '', this.results = const [], this.error});
}

class GlossarySearchController extends Notifier<GlossarySearchState> {
  int _seq = 0;

  @override
  GlossarySearchState build() {
    ref.watch(lectureIdProvider);
    return const GlossarySearchState();
  }

  Future<void> search(String term) async {
    final query = term.trim();
    final lectureId = ref.read(lectureIdProvider);
    if (query.isEmpty) {
      state = const GlossarySearchState(status: LoadStatus.error, error: '조회할 용어를 입력하세요.');
      return;
    }
    if (lectureId == null) {
      state = GlossarySearchState(status: LoadStatus.error, query: query, error: '강의에 연결된 뒤 조회할 수 있습니다.');
      return;
    }
    final seq = ++_seq; // 늦게 도착한 이전 검색 결과가 덮어쓰지 않게
    state = GlossarySearchState(status: LoadStatus.loading, query: query);
    try {
      final results = await ref.read(apiProvider).glossary(lectureId, keyword: query);
      if (seq != _seq) return;
      state = GlossarySearchState(status: LoadStatus.done, query: query, results: results);
    } on ApiException catch (e) {
      if (seq != _seq) return;
      state = GlossarySearchState(status: LoadStatus.error, query: query, error: e.message);
    }
  }

  void show(GlossaryEntry entry) {
    _seq++;
    state = GlossarySearchState(status: LoadStatus.done, query: entry.term, results: [entry]);
  }
}

final glossarySearchProvider =
    NotifierProvider<GlossarySearchController, GlossarySearchState>(GlossarySearchController.new);

// ─── 강의 중 자동 추출된 용어 (Realtime으로 추가) ─────────────────

class LectureTermsController extends Notifier<List<GlossaryEntry>> {
  @override
  List<GlossaryEntry> build() {
    final lectureId = ref.watch(lectureIdProvider);
    final realtime = ref.watch(realtimeProvider);
    if (lectureId == null) return const [];
    if (realtime != null) {
      final sub = realtime.glossaryInserts.listen((entry) {
        if (state.any((e) => e.term == entry.term)) return;
        state = [entry, ...state];
      });
      ref.onDispose(sub.cancel);
    }
    Future.microtask(() async {
      try {
        state = await ref.read(apiProvider).glossary(lectureId);
      } catch (_) {}
    });
    return const [];
  }
}

final lectureTermsProvider = NotifierProvider<LectureTermsController, List<GlossaryEntry>>(LectureTermsController.new);

// ─── 추가 설명 요청 (강의 맥락 기반 AI 설명) ─────────────────────

class TermDetailState {
  final String term;
  final LoadStatus status;
  final String? text;
  const TermDetailState({this.term = '', this.status = LoadStatus.idle, this.text});
}

class TermDetailController extends Notifier<TermDetailState> {
  @override
  TermDetailState build() {
    ref.watch(lectureIdProvider);
    return const TermDetailState();
  }

  void clear() => state = const TermDetailState();

  Future<void> request(String term) async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null || term.trim().isEmpty) return;
    state = TermDetailState(term: term, status: LoadStatus.loading);
    try {
      final answer = await ref.read(apiProvider).askAi(
            lectureId: lectureId,
            question: "'$term'이(가) 이번 강의에서 어떤 의미로 쓰였는지, 쉬운 예시와 함께 자세히 설명해 줘.",
            lang: ref.read(captionLanguageProvider),
            // 용어 설명은 질문 탭 AI 대화 기록과 섞이지 않게 따로 둔다
            clientId: '${ref.read(clientIdProvider)}:glossary',
          );
      if (state.term == term) state = TermDetailState(term: term, status: LoadStatus.done, text: answer.answer);
    } on ApiException catch (e) {
      if (state.term == term) state = TermDetailState(term: term, status: LoadStatus.error, text: e.message);
    }
  }
}

final termDetailProvider = NotifierProvider<TermDetailController, TermDetailState>(TermDetailController.new);
