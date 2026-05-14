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
