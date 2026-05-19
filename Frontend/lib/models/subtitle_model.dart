// lib/models/subtitle_model.dart
// 자막 데이터 모델

class SubtitleSegment {
  final String id;
  final String originalText;   // 원문 (교수 발화)
  final String? translatedText; // 번역문
  final String language;        // 감지된 언어
  final DateTime timestamp;
  final bool hasVisual;         // 슬라이드 연동 여부
  final String? visualSummary; // 슬라이드 요약

  const SubtitleSegment({
    required this.id,
    required this.originalText,
    this.translatedText,
    required this.language,
    required this.timestamp,
    this.hasVisual = false,
    this.visualSummary,
  });

  // SSE JSON 파싱
  factory SubtitleSegment.fromJson(Map<String, dynamic> json) {
    return SubtitleSegment(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      originalText: json['original_text'] ?? '',
      translatedText: json['translated_text'],
      language: json['language'] ?? 'ko',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      hasVisual: json['has_visual'] ?? false,
      visualSummary: json['visual_summary'],
    );
  }

  // 표시할 텍스트 (번역 우선)
  String get displayText => translatedText ?? originalText;

  SubtitleSegment copyWith({
    String? id,
    String? originalText,
    String? translatedText,
    String? language,
    DateTime? timestamp,
    bool? hasVisual,
    String? visualSummary,
  }) {
    return SubtitleSegment(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      language: language ?? this.language,
      timestamp: timestamp ?? this.timestamp,
      hasVisual: hasVisual ?? this.hasVisual,
      visualSummary: visualSummary ?? this.visualSummary,
    );
  }
}

// 자막 위젯 설정
class SubtitleSettings {
  final double opacity;         // 투명도 (0.0 ~ 1.0)
  final double fontSize;        // 폰트 크기
  final SubtitlePosition position; // 위치
  final bool showTranslation;   // 번역 표시 여부
  final String targetLanguage;  // 번역 목표 언어
  final double widgetHeight;    // 위젯 높이

  const SubtitleSettings({
    this.opacity = 0.85,
    this.fontSize = 16.0,
    this.position = SubtitlePosition.bottom,
    this.showTranslation = true,
    this.targetLanguage = 'ko',
    this.widgetHeight = 120.0,
  });

  SubtitleSettings copyWith({
    double? opacity,
    double? fontSize,
    SubtitlePosition? position,
    bool? showTranslation,
    String? targetLanguage,
    double? widgetHeight,
  }) {
    return SubtitleSettings(
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
      showTranslation: showTranslation ?? this.showTranslation,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      widgetHeight: widgetHeight ?? this.widgetHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'opacity': opacity,
    'fontSize': fontSize,
    'position': position.index,
    'showTranslation': showTranslation,
    'targetLanguage': targetLanguage,
    'widgetHeight': widgetHeight,
  };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    return SubtitleSettings(
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      position: SubtitlePosition.values[json['position'] as int? ?? 2],
      showTranslation: json['showTranslation'] as bool? ?? true,
      targetLanguage: json['targetLanguage'] as String? ?? 'ko',
      widgetHeight: (json['widgetHeight'] as num?)?.toDouble() ?? 120.0,
    );
  }
}

enum SubtitlePosition { top, left, right, bottom }
