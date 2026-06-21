class SubtitleSegment {
  final String id;
  final String originalText;
  final String? translatedText;
  final String language;
  final DateTime timestamp;
  final bool hasVisual;
  final String? visualSummary;

  const SubtitleSegment({
    required this.id,
    required this.originalText,
    this.translatedText,
    required this.language,
    required this.timestamp,
    this.hasVisual = false,
    this.visualSummary,
  });

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

class SubtitleSettings {
  final double opacity;
  final double fontSize;
  final SubtitlePosition position;
  final bool showTranslation;
  final String targetLanguage;
  final double widgetHeight;
  final double panelWidth;

  const SubtitleSettings({
    this.opacity = 0.85,
    this.fontSize = 16.0,
    this.position = SubtitlePosition.bottom,
    this.showTranslation = true,
    this.targetLanguage = 'ko',
    this.widgetHeight = 120.0,
    this.panelWidth = 360.0,
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
    'panelWidth': panelWidth,
  };

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    return SubtitleSettings(
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.85,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      position: SubtitlePosition.values[json['position'] as int? ?? 3],
      showTranslation: json['showTranslation'] as bool? ?? true,
      targetLanguage: json['targetLanguage'] as String? ?? 'ko',
      widgetHeight: (json['widgetHeight'] as num?)?.toDouble() ?? 120.0,
      panelWidth: (json['panelWidth'] as num?)?.toDouble() ?? 360.0,
    );
  }
}

enum SubtitlePosition { top, left, right, bottom }