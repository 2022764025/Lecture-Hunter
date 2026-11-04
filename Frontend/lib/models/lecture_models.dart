// 백엔드(App) REST 응답과 Supabase 테이블 행을 담는 모델

DateTime _parseTime(Object? value) =>
    (value is String ? DateTime.tryParse(value) : null)?.toLocal() ?? DateTime.now();

int _parseInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// lecture_contents 한 행 = 자막 한 줄. 원문이 먼저 INSERT 되고 번역은 나중에 UPDATE 된다.
class Caption {
  final int id;
  final String original;
  final String? translated;
  final String? sourceLang;
  final String? targetLang;
  final DateTime createdAt;
  final bool hasVisual;
  final String? visualSummary;

  const Caption({
    required this.id,
    required this.original,
    required this.createdAt,
    this.translated,
    this.sourceLang,
    this.targetLang,
    this.hasVisual = false,
    this.visualSummary,
  });

  factory Caption.fromRow(Map<String, dynamic> row) => Caption(
        id: _parseInt(row['id']),
        original: (row['original_text'] ?? '').toString().trim(),
        translated: _nonEmpty(row['translated_text']),
        sourceLang: _nonEmpty(row['source_lang']),
        targetLang: _nonEmpty(row['target_lang']),
        createdAt: _parseTime(row['created_at']),
        hasVisual: row['has_visual'] == true,
        visualSummary: _nonEmpty(row['visual_summary']),
      );
}

/// lecture_questions 한 행 (익명 질문)
class LectureQuestion {
  final int id;
  final String content;
  final String? clientId;
  final bool isAiRefined;
  final bool isResolved;
  final String? answer;
  final DateTime createdAt;

  const LectureQuestion({
    required this.id,
    required this.content,
    required this.createdAt,
    this.clientId,
    this.isAiRefined = false,
    this.isResolved = false,
    this.answer,
  });

  factory LectureQuestion.fromRow(Map<String, dynamic> row) => LectureQuestion(
        id: _parseInt(row['id']),
        content: (row['content'] ?? '').toString(),
        clientId: _nonEmpty(row['client_id']),
        isAiRefined: row['is_ai_refined'] == true,
        isResolved: row['is_resolved'] == true,
        answer: _nonEmpty(row['answer']),
        createdAt: _parseTime(row['created_at']),
      );
}

enum NoticeCategory { important, material, assignment, general }

/// lecture_notices 한 행. lectureId가 없으면 모든 강의에 보이는 전체 공지.
class LectureNotice {
  final int id;
  final String? lectureId;
  final NoticeCategory category;
  final String title;
  final String? content;
  final bool isPinned;
  final DateTime createdAt;

  const LectureNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.createdAt,
    this.lectureId,
    this.content,
    this.isPinned = false,
  });

  factory LectureNotice.fromRow(Map<String, dynamic> row) => LectureNotice(
        id: _parseInt(row['id']),
        lectureId: _nonEmpty(row['lecture_id']),
        category: NoticeCategory.values.firstWhere(
          (c) => c.name == row['category'],
          orElse: () => NoticeCategory.general,
        ),
        title: (row['title'] ?? '').toString(),
        content: _nonEmpty(row['content']),
        isPinned: row['is_pinned'] == true,
        createdAt: _parseTime(row['created_at']),
      );

  static final _urlPattern = RegExp(r'https?://[^\s)]+');

  /// 내용에 들어 있는 첫 번째 링크 (외부 링크 버튼용)
  String? get link => _urlPattern.firstMatch(content ?? '')?.group(0);

  /// 화면에 보일 내용. 링크 주소는 글자로 늘어놓지 않고 제목 옆 링크 버튼으로만 보여준다.
  String? get displayContent {
    final text = (content ?? '')
        .replaceAll(RegExp(r'\(?https?://[^\s)]+\)?'), '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
    return text.isEmpty ? null : text;
  }
}

/// 용어집 항목. source: 'lecture'(강의 중 자동 추출) / 'ai'(DB에 없어 즉석 생성)
class GlossaryEntry {
  final String term;
  final String definition;
  final String? definitionEn;
  final String source;
  final DateTime createdAt;

  const GlossaryEntry({
    required this.term,
    required this.definition,
    required this.createdAt,
    this.definitionEn,
    this.source = 'lecture',
  });

  bool get isAiGenerated => source == 'ai';

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) => GlossaryEntry(
        term: (json['term'] ?? '').toString(),
        definition: (json['definition'] ?? '').toString(),
        definitionEn: _nonEmpty(json['definition_en']),
        source: (json['source'] ?? 'lecture').toString(),
        createdAt: _parseTime(json['created_at']),
      );
}

class AnswerSource {
  final int id;
  final String text;
  final double similarity;
  const AnswerSource({required this.id, required this.text, required this.similarity});

  factory AnswerSource.fromJson(Map<String, dynamic> json) => AnswerSource(
        id: _parseInt(json['id']),
        text: (json['text'] ?? '').toString(),
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
      );
}

/// AI 답변 (RAG 질문 또는 화면 캡처 질문)
class AiAnswer {
  final String answer;
  final List<AnswerSource> sources;
  const AiAnswer({required this.answer, this.sources = const []});

  factory AiAnswer.fromJson(Map<String, dynamic> json) => AiAnswer(
        answer: (json['answer'] ?? json['analysis'] ?? '').toString().trim(),
        sources: (json['sources'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AnswerSource.fromJson)
            .toList(),
      );
}

class SummaryResult {
  final String summary;
  final List<String> keyPoints;
  final int captionCount;
  final bool empty;

  const SummaryResult({
    required this.summary,
    this.keyPoints = const [],
    this.captionCount = 0,
    this.empty = false,
  });

  factory SummaryResult.fromJson(Map<String, dynamic> json) => SummaryResult(
        summary: (json['summary'] ?? '').toString().trim(),
        keyPoints: (json['key_points'] as List? ?? []).map((e) => e.toString()).toList(),
        captionCount: _parseInt(json['caption_count']),
        empty: json['empty'] == true,
      );
}

/// GET /lecture/status
class LectureStatus {
  final DateTime? startedAt;
  final int captionCount;
  final bool streaming;
  final String? targetLang;
  final double elapsedSec;
  final DateTime fetchedAt;

  const LectureStatus({
    required this.fetchedAt,
    this.startedAt,
    this.captionCount = 0,
    this.streaming = false,
    this.targetLang,
    this.elapsedSec = 0,
  });

  factory LectureStatus.fromJson(Map<String, dynamic> json) => LectureStatus(
        startedAt: json['started_at'] == null ? null : _parseTime(json['started_at']),
        captionCount: _parseInt(json['caption_count']),
        streaming: json['streaming'] == true,
        targetLang: _nonEmpty(json['target_lang']),
        elapsedSec: (json['elapsed_sec'] as num?)?.toDouble() ?? 0,
        fetchedAt: DateTime.now(),
      );

  /// 오디오가 들어오는 중이면 마지막 조회 이후 흐른 시간까지 더한 강의 경과 시간
  Duration get elapsed {
    final extra = streaming ? DateTime.now().difference(fetchedAt) : Duration.zero;
    return Duration(milliseconds: (elapsedSec * 1000).round()) + extra;
  }
}

class RefineResult {
  final String refined;
  final bool changed;
  const RefineResult({required this.refined, required this.changed});
}
