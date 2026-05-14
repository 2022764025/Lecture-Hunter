// lib/providers/subtitle_provider.dart
// Riverpod 전역 상태 관리

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subtitle_model.dart';
import '../models/question_model.dart';
import '../services/sse_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

// ─── Service Providers ────────────────────────────────────────

final sseServiceProvider = Provider<SseService>((ref) {
  final service = SseService();
  ref.onDispose(service.dispose);
  return service;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.dispose);
  return service;
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

// ─── 자막 설정 Provider ───────────────────────────────────────

final subtitleSettingsProvider =
    StateNotifierProvider<SubtitleSettingsNotifier, SubtitleSettings>((ref) {
  return SubtitleSettingsNotifier(ref.read(settingsServiceProvider));
});

class SubtitleSettingsNotifier extends StateNotifier<SubtitleSettings> {
  final SettingsService _settingsService;

  SubtitleSettingsNotifier(this._settingsService)
      : super(const SubtitleSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _settingsService.load();
  }

  Future<void> update(SubtitleSettings settings) async {
    state = settings;
    await _settingsService.save(settings);
  }

  Future<void> reset() async {
    state = const SubtitleSettings();
    await _settingsService.reset();
  }
}

// ─── SSE 연결 상태 Provider ───────────────────────────────────

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final sseService = ref.watch(sseServiceProvider);
  return sseService.statusStream;
});

// ─── 자막 스트림 Provider ─────────────────────────────────────

final subtitleStreamProvider = StreamProvider<SubtitleSegment>((ref) {
  final sseService = ref.watch(sseServiceProvider);
  return sseService.subtitleStream;
});

// ─── 자막 히스토리 Provider ───────────────────────────────────
// 최근 N개의 자막 세그먼트를 유지

final subtitleHistoryProvider =
    StateNotifierProvider<SubtitleHistoryNotifier, List<SubtitleSegment>>((ref) {
  return SubtitleHistoryNotifier();
});

class SubtitleHistoryNotifier extends StateNotifier<List<SubtitleSegment>> {
  static const int _maxHistory = 50;

  SubtitleHistoryNotifier() : super([]);

  void add(SubtitleSegment segment) {
    // 중복 제거 후 최신 항목 유지
    final updated = [...state, segment];
    if (updated.length > _maxHistory) {
      state = updated.sublist(updated.length - _maxHistory);
    } else {
      state = updated;
    }
  }

  void clear() => state = [];
}

// ─── 현재 자막 (최신 1개) Provider ───────────────────────────

final currentSubtitleProvider = Provider<SubtitleSegment?>((ref) {
  final history = ref.watch(subtitleHistoryProvider);
  return history.isEmpty ? null : history.last;
});

// ─── 자막 패널 표시 여부 ─────────────────────────────────────

final subtitleVisibleProvider = StateProvider<bool>((ref) => true);

// ─── 질문/용어집 패널 표시 여부 ──────────────────────────────

final questionPanelVisibleProvider = StateProvider<bool>((ref) => false);

// ─── 현재 질문 모드 ──────────────────────────────────────────

final questionModeProvider = StateProvider<QuestionMode>((ref) => QuestionMode.professor);

enum QuestionMode { professor, glossary }

// ─── 질문 응답 상태 Provider ─────────────────────────────────

final questionResponseProvider =
    StateNotifierProvider<QuestionResponseNotifier, QuestionResponseState>((ref) {
  return QuestionResponseNotifier(ref.read(apiServiceProvider));
});

class QuestionResponseState {
  final ResponseStatus status;
  final QuestionResponse? response;
  final String query;

  const QuestionResponseState({
    this.status = ResponseStatus.idle,
    this.response,
    this.query = '',
  });
}

class QuestionResponseNotifier extends StateNotifier<QuestionResponseState> {
  final ApiService _apiService;

  QuestionResponseNotifier(this._apiService)
      : super(const QuestionResponseState());

  Future<void> submit(String question, QuestionMode mode) async {
    if (question.trim().isEmpty) return;

    state = QuestionResponseState(
      status: ResponseStatus.loading,
      query: question,
    );

    final request = QuestionRequest(
      question: question,
      mode: mode == QuestionMode.professor ? 'professor' : 'glossary',
    );

    // Mock 모드 사용 (실제 서버 연결 시 askQuestion으로 교체)
    final response = await _apiService.mockAskQuestion(request);

    state = QuestionResponseState(
      status: response.status,
      response: response,
      query: question,
    );
  }

  void reset() => state = const QuestionResponseState();
}

// ─── 용어집 검색 Provider ─────────────────────────────────────

final glossarySearchProvider =
    StateNotifierProvider<GlossarySearchNotifier, GlossarySearchState>((ref) {
  return GlossarySearchNotifier(ref.read(apiServiceProvider));
});

class GlossarySearchState {
  final ResponseStatus status;
  final List<GlossaryEntry> results;
  final String query;

  const GlossarySearchState({
    this.status = ResponseStatus.idle,
    this.results = const [],
    this.query = '',
  });
}

class GlossarySearchNotifier extends StateNotifier<GlossarySearchState> {
  final ApiService _apiService;
  Timer? _debounceTimer;

  GlossarySearchNotifier(this._apiService)
      : super(const GlossarySearchState());

  void search(String term) {
    _debounceTimer?.cancel();
    if (term.trim().isEmpty) {
      state = const GlossarySearchState();
      return;
    }

    state = GlossarySearchState(
      status: ResponseStatus.loading,
      query: term,
    );

    // 300ms 디바운스
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _apiService.mockSearchGlossary(term);
      state = GlossarySearchState(
        status: ResponseStatus.success,
        results: results,
        query: term,
      );
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const GlossarySearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ─── Mock 모드 Provider ───────────────────────────────────────

final mockModeProvider = StateProvider<bool>((ref) => true);
