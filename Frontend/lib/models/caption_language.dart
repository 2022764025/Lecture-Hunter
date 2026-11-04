/// 자막 번역 언어 (디자인과 같이 EN / KR / CN 세 가지).
/// 백엔드 PUT /lecture/settings 의 target_lang 과 lecture_contents.target_lang 에 대응한다.
/// 예전에 JP를 골라 저장해 둔 브라우저는 parse가 null을 돌려 기본 언어(KR)로 돌아간다.
enum CaptionLanguage {
  en(
    code: 'en',
    backendName: 'English',
    flag: '🇺🇸',
    label: 'EN',
    originalHeading: 'Original',
    translationHeading: 'English Captions',
    translationPlaceholder: 'The translated captions will appear here.',
  ),
  ko(
    code: 'ko',
    backendName: 'Korean',
    flag: '🇰🇷',
    label: 'KR',
    originalHeading: '원문',
    translationHeading: '한국어 자막',
    translationPlaceholder: '번역된 한국어 자막이 여기에 표시됩니다.',
  ),
  zh(
    code: 'zh',
    backendName: 'Chinese',
    flag: '🇨🇳',
    label: 'CN',
    originalHeading: '原文',
    translationHeading: '中文字幕',
    translationPlaceholder: '翻译后的中文字幕将显示在这里。',
  );

  const CaptionLanguage({
    required this.code,
    required this.backendName,
    required this.flag,
    required this.label,
    required this.originalHeading,
    required this.translationHeading,
    required this.translationPlaceholder,
  });

  final String code;
  final String backendName;
  final String flag;
  final String label;
  final String originalHeading;
  final String translationHeading;
  final String translationPlaceholder;

  static const _aliases = {
    'ko': 'ko', 'kr': 'ko', 'korean': 'ko', '한국어': 'ko',
    'en': 'en', 'english': 'en', '영어': 'en',
    'zh': 'zh', 'cn': 'zh', 'chinese': 'zh', '중국어': 'zh',
  };

  /// 'ko', 'Korean', 'KR' 등 어떤 표기든 받아서 언어를 돌려준다. 모르면 null.
  static CaptionLanguage? parse(String? value) {
    final code = _aliases[(value ?? '').trim().toLowerCase()];
    if (code == null) return null;
    return CaptionLanguage.values.firstWhere((l) => l.code == code);
  }

  bool matches(String? value) => parse(value) == this;
}
