// lib/models/subtitle_model.dart
// 자막 및 위젯 설정 데이터 모델

class SubtitleSegment {
  final String id;
  final String originalText;   // 원문 (교수 발화)
  final String? translatedText; // 번역문
  final String language;        // 감지된 언어
  final DateTime timestamp;
  final bool hasVisual;         // 슬라이드 연동 여부
  final String? visualSummary;  // 슬라이드 요약

  const SubtitleSegment({
    required this.id,
    required this.originalText,
    this.translatedText,
    required this.language,
    required this.timestamp,
    this.hasVisual = false,
    this.visualSummary,
  });

  // SSE JSON 파싱 ENGINE
  factory SubtitleSegment.fromJson(Map<String, dynamic> json) {
    return SubtitleSegment(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      originalText: json['original_text'] ?? json['original'] ?? '',
      translatedText: json['translated_text'] ?? json['translated'],
      language: json['language'] ?? 'ko',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      hasVisual: json['has_visual'] ?? false,
      visualSummary: json['visual_summary'],
    );
  }

  // 표시할 텍스트 (번역 우선 매핑)
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

// 자막 위젯 세팅 관리 모델 (반응형 너비 기능 대통합)
class SubtitleSettings {
  final double opacity;         // 투명도 (0.0 ~ 1.0)
  final double fontSize;        // 폰트 크기
  final SubtitlePosition position; // 위젯 배치 위치
  final bool showTranslation;   // 번역 표시 여부
  final String targetLanguage;  // 번역 목표 언어
  final double widgetHeight;    // 위젯 높이
  final double panelWidth;      // 실시간 반응형 위젯 가로 너비 기억 장치

  const SubtitleSettings({
    this.opacity = 0.85,
    this.fontSize = 16.0,
    this.position = SubtitlePosition.bottom,
    this.showTranslation = true,
    this.targetLanguage = 'ko',
    this.widgetHeight = 120.0,
    this.panelWidth = 360.0, // 기본 세팅 너비값 360 고정
  });

  SubtitleSettings copyWith({
    double? opacity,
    double? fontSize,
    SubtitlePosition? position,
    bool? showTranslation,
    String? targetLanguage,
    double? widgetHeight,
    double? panelWidth,
  }) {
    return SubtitleSettings(
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
      showTranslation: showTranslation ?? this.showTranslation,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      widgetHeight: widgetHeight ?? this.widgetHeight,
      panelWidth: panelWidth ?? this.panelWidth,
    );
  }

  Map<String, dynamic> toJson() => {
    'opacity': opacity,
    'fontSize': fontSize,
    'position': position.index,
    'showTranslation': showTranslation,
    'targetLanguage': targetLanguage,
    'widgetHeight': widgetHeight,
    'panelWidth': panelWidth, // 로컬 스토리지 저장을 위한 직렬화 추가
  };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    return SubtitleSettings(
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      // [버그 픽스 완료] 기본 바텀 포지션 인덱스 번호를 2(right)에서 3(bottom)으로 올바르게 정렬
      position: SubtitlePosition.values[json['position'] as int? ?? 3],
      showTranslation: json['showTranslation'] as bool? ?? true,
      targetLanguage: json['targetLanguage'] as String? ?? 'ko',
      widgetHeight: (json['widgetHeight'] as num?)?.toDouble() ?? 120.0,
      panelWidth: (json['panelWidth'] as num?)?.toDouble() ?? 360.0,
    );
  }
}

enum SubtitlePosition { top, left, right, bottom }