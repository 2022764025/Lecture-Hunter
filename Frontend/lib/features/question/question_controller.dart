import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../caption/caption_controller.dart';
import '../session/session_controller.dart';

/// 질문을 누구에게 보낼지.
/// professor: 교수님께 익명 질문 (DB 저장, 질문 목록에 실시간 표시)
/// ai: AI에게 질문 (강의 자막 기반 RAG 답변, 화면 캡처를 첨부하면 VLM 화면 질문)
enum AskTarget { professor, ai }

final askTargetProvider = StateProvider<AskTarget>((ref) => AskTarget.professor);

// ─── 익명 질문 게시판 ─────────────────────────────────────────

class QuestionBoardState {
  final List<LectureQuestion> items; // 최신순
  final bool loading;
  final String? error;

  const QuestionBoardState({this.items = const [], this.loading = false, this.error});

  QuestionBoardState copyWith({List<LectureQuestion>? items, bool? loading, String? error, bool clearError = false}) =>
      QuestionBoardState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class QuestionBoardController extends Notifier<QuestionBoardState> {
  Timer? _fallbackTimer;

  @override
  QuestionBoardState build() {
    final lectureId = ref.watch(lectureIdProvider);
    final realtime = ref.watch(realtimeProvider);
    ref.onDispose(() => _fallbackTimer?.cancel());
    if (lectureId == null) return const QuestionBoardState();

    if (realtime != null) {
      final sub = realtime.questionChanges.listen(_apply);
      ref.onDispose(sub.cancel);
    }
    // Realtime이 끊긴 동안에는 15초마다 목록을 다시 읽는다
    ref.listen<AsyncValue<SyncStatus>>(syncStatusProvider, (_, next) {
      final polling = next.valueOrNull == SyncStatus.polling || next.valueOrNull == SyncStatus.error;
      _fallbackTimer?.cancel();
      _fallbackTimer = polling ? Timer.periodic(const Duration(seconds: 15), (_) => load()) : null;
    });
    Future.microtask(load);
    return const QuestionBoardState(loading: true);
  }

  Future<void> load() async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) return;
    try {
      final items = await ref.read(apiProvider).questions(lectureId);
      state = state.copyWith(items: items, loading: false, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  void _apply(RowChange<LectureQuestion> change) {
    final items = [...state.items]..removeWhere((q) => q.id == change.id);
    if (change.kind == ChangeKind.upsert) items.add(change.row!);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(items: items);
  }

  /// 질문 저장. 성공하면 Realtime 이벤트를 기다리지 않고 바로 목록에 넣는다.
  Future<void> submit(String content, {required bool aiRefined}) async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) throw const ApiException('강의에 연결된 뒤 질문할 수 있습니다.');
    final question = await ref.read(apiProvider).createQuestion(
          lectureId: lectureId,
          content: content,
          clientId: ref.read(clientIdProvider),
          isAiRefined: aiRefined,
        );
    _apply(RowChange.upsert(question, question.id));
  }
}

final questionBoardProvider =
    NotifierProvider<QuestionBoardController, QuestionBoardState>(QuestionBoardController.new);

// ─── AI 질문 ──────────────────────────────────────────────────

enum AiQaStatus { idle, loading, done, error }

class AiQaState {
  final AiQaStatus status;
  final String question;
  final bool withImage;
  final AiAnswer? answer;
  final String? error;

  const AiQaState({this.status = AiQaStatus.idle, this.question = '', this.withImage = false, this.answer, this.error});
}

class AiQaController extends Notifier<AiQaState> {
  @override
  AiQaState build() {
    ref.watch(lectureIdProvider); // 강의가 바뀌면 초기화
    return const AiQaState();
  }

  /// imageDataUrl이 있으면 화면 캡처 질문(VLM), 없으면 강의 자막 기반 질문(RAG)
  Future<void> ask(String question, {String? imageDataUrl}) async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) {
      state = const AiQaState(status: AiQaStatus.error, error: '강의에 연결된 뒤 질문할 수 있습니다.');
      return;
    }
    final text = question.trim().isEmpty && imageDataUrl != null ? '이 화면의 내용을 설명해 주세요.' : question.trim();
    state = AiQaState(status: AiQaStatus.loading, question: text, withImage: imageDataUrl != null);
    final api = ref.read(apiProvider);
    final lang = ref.read(captionLanguageProvider);
    try {
      final answer = imageDataUrl != null
          ? await api.askAboutScreen(lectureId: lectureId, imageDataUrl: imageDataUrl, lang: lang, question: text)
          : await api.askAi(lectureId: lectureId, question: text, lang: lang, clientId: ref.read(clientIdProvider));
      state = AiQaState(status: AiQaStatus.done, question: text, withImage: imageDataUrl != null, answer: answer);
    } on ApiException catch (e) {
      state = AiQaState(status: AiQaStatus.error, question: text, withImage: imageDataUrl != null, error: e.message);
    }
  }

  /// "새 대화": 화면을 비우고 서버의 대화 기록(이 브라우저 것만)도 지운다
  Future<void> reset() async {
    state = const AiQaState();
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) return;
    try {
      await ref.read(apiProvider).resetAi(lectureId: lectureId, clientId: ref.read(clientIdProvider));
    } catch (_) {}
  }
}

final aiQaProvider = NotifierProvider<AiQaController, AiQaState>(AiQaController.new);
