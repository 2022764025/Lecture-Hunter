// lib/features/caption/presentation/controllers/caption_controller.dart
// Riverpod 전역 상태 관리 - 순정 복구 완료 버전

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subtitle_model.dart';
import '../../../assistant/presentation/controllers/question_model.dart';
import '../../../../services/sse_service.dart';
import '../../../../services/audio_stream_service.dart';
import '../../../../services/api_service.dart';
import '../../../../services/settings_service.dart';

final sseServiceProvider = Provider<SseService>((ref) {
  final service = SseService();
  ref.onDispose(service.dispose);
  return service;
});

final audioStreamServiceProvider = Provider<AudioStreamService>((ref) {
  final service = AudioStreamService();
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

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final sseService = ref.watch(sseServiceProvider);
  return sseService.statusStream;
});

final subtitleStreamProvider = StreamProvider<SubtitleSegment>((ref) {
  final sseService = ref.watch(sseServiceProvider);
  
  sseService.subtitleStream.listen((segment) {
    print('[리버팟 파이프라인] DB 스트림에서 새 자막 감지 -> 히스토리 갱신 가동!');
    ref.read(subtitleHistoryProvider.notifier).add(segment);
  });
  
  return sseService.subtitleStream;
});

final subtitleHistoryProvider =
    StateNotifierProvider<SubtitleHistoryNotifier, List<SubtitleSegment>>((ref) {
  return SubtitleHistoryNotifier();
});

class SubtitleHistoryNotifier extends StateNotifier<List<SubtitleSegment>> {
  static const int _maxHistory = 50;

  SubtitleHistoryNotifier() : super([]);

  void add(SubtitleSegment segment) {
    final isDuplicate = state.any((s) => s.id == segment.id || s.originalText == segment.originalText);
    if (isDuplicate) return;

    final updated = [...state, segment];
    if (updated.length > _maxHistory) {
      state = updated.sublist(updated.length - _maxHistory);
    } else {
      state = updated;
    }
  }

  void clear() => state = [];
}

final currentSubtitleProvider = Provider<SubtitleSegment?>((ref) {
  final history = ref.watch(subtitleHistoryProvider);
  return history.isEmpty ? null : history.last;
});

final subtitleVisibleProvider = StateProvider<bool>((ref) => true);
final questionPanelVisibleProvider = StateProvider<bool>((ref) => false);
final questionModeProvider = StateProvider<QuestionMode>((ref) => QuestionMode.professor);

enum QuestionMode { professor, glossary }

// 익명 질문 대상 분기 (AI vs 교수님) 설정
enum QuestionTarget { ai, professor }

final questionTargetProvider = StateProvider<QuestionTarget>((ref) => QuestionTarget.ai);

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

  // 기존 QuestionMode 대신 새로 정의한 QuestionTarget을 인자로 받아 백엔드 분기를 명확하게 처리
  Future<void> submit(String question, QuestionTarget target) async {
    if (question.trim().isEmpty) return;

    state = QuestionResponseState(
      status: ResponseStatus.loading,
      query: question,
    );

    // 토글된 타겟 상태에 따라 백엔드 API 명세에 'ai' 또는 'professor' 문자열 매핑
    final request = QuestionRequest(
      question: question,
      mode: target == QuestionTarget.ai ? 'ai' : 'professor',
    );

    final response = await _apiService.askQuestion(request);

    state = QuestionResponseState(
      status: response.status,
      response: response,
      query: question,
    );
  }

  void reset() => state = const QuestionResponseState();

  Future<void> resetQuestionSession() async {
    await _apiService.resetQuestionHistory();
    state = const QuestionResponseState(); 
  }
}

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

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _apiService.searchGlossary(term);

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

final mockModeProvider = StateProvider<bool>((ref) => false);