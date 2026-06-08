// lib/models/question_model.dart
// 질문·용어집 데이터 모델

class QuestionRequest {
  final String question;
  final String mode; // 'professor' | 'glossary'
  final String? context; // 현재 강의 문맥

  const QuestionRequest({
    required this.question,
    required this.mode,
    this.context,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'mode': mode,
    if (context != null) 'context': context,
  };
}

class QuestionResponse {
  final String answer;
  final String? source;        // 출처 (강의 몇 분)
  final String? relatedSlide;  // 관련 슬라이드 요약
  final List<String> keyPoints;
  final ResponseStatus status;

  const QuestionResponse({
    required this.answer,
    this.source,
    this.relatedSlide,
    this.keyPoints = const [],
    this.status = ResponseStatus.success,
  });

  factory QuestionResponse.fromJson(Map<String, dynamic> json) {
    return QuestionResponse(
      answer: json['answer'] ?? '',
      source: json['source'],
      relatedSlide: json['related_slide'],
      keyPoints: (json['key_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: ResponseStatus.success,
    );
  }

  factory QuestionResponse.error(String message) {
    return QuestionResponse(
      answer: message,
      status: ResponseStatus.error,
    );
  }

  factory QuestionResponse.loading() {
    return const QuestionResponse(
      answer: '',
      status: ResponseStatus.loading,
    );
  }
}

enum ResponseStatus { idle, loading, success, error }

// 용어집 항목
class GlossaryEntry {
  final String term;
  final String definition;
  final String? example;
  final String? source;

  const GlossaryEntry({
    required this.term,
    required this.definition,
    this.example,
    this.source,
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    return GlossaryEntry(
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
      example: json['example'],
      source: json['source'],
    );
  }
}

// SSE 연결 상태
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class SummaryResponse {
  final String lectureId;
  final int minutes;
  final String summary;
  final ResponseStatus status;

  const SummaryResponse({
    required this.lectureId,
    required this.minutes,
    required this.summary,
    this.status = ResponseStatus.success,
  });

  factory SummaryResponse.fromJson(Map<String, dynamic> json) {
    return SummaryResponse(
      lectureId: json['lecture_id']?.toString() ?? '',
      minutes: json['minutes'] is int
          ? json['minutes'] as int
          : int.tryParse(json['minutes']?.toString() ?? '') ?? 0,
      summary: json['summary']?.toString() ?? '',
      status: ResponseStatus.success,
    );
  }

  factory SummaryResponse.error(String message) {
    return SummaryResponse(
      lectureId: '',
      minutes: 0,
      summary: message,
      status: ResponseStatus.error,
    );
  }

  factory SummaryResponse.loading() {
    return const SummaryResponse(
      lectureId: '',
      minutes: 0,
      summary: '',
      status: ResponseStatus.loading,
    );
  }
}


class SlideAnalysisResponse {
  final bool hasVisual;
  final String message;
  final String visualContext;
  final int? anchoredContentId;
  final ResponseStatus status;

  const SlideAnalysisResponse({
    required this.hasVisual,
    required this.message,
    required this.visualContext,
    this.anchoredContentId,
    this.status = ResponseStatus.success,
  });

  factory SlideAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SlideAnalysisResponse(
      hasVisual: json['has_visual'] == true,
      message: json['message']?.toString() ?? '',
      visualContext: json['visual_context']?.toString() ??
          json['summary']?.toString() ??
          '',
      anchoredContentId: json['anchored_content_id'] is int
          ? json['anchored_content_id'] as int
          : int.tryParse(json['anchored_content_id']?.toString() ?? ''),
      status: ResponseStatus.success,
    );
  }

  factory SlideAnalysisResponse.error(String message) {
    return SlideAnalysisResponse(
      hasVisual: false,
      message: message,
      visualContext: '',
      status: ResponseStatus.error,
    );
  }
}
