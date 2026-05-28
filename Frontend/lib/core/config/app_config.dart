class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8000',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String defaultLectureId = String.fromEnvironment(
    'LECTURE_ID',
    defaultValue: 'demo-lecture',
  );

  static const String defaultTargetLang = String.fromEnvironment(
    'TARGET_LANG',
    defaultValue: 'Korean',
  );
}
