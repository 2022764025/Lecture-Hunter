/// 빌드 시 --dart-define 또는 --dart-define-from-file=env.json 으로 주입하는 설정값.
///
/// 실행 예:
///   flutter run -d chrome --web-port=9998 --dart-define-from-file=env.json
class AppConfig {
  AppConfig._();

  /// 백엔드 REST API 주소
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// 백엔드 오디오 WebSocket 주소 (단독 실행 모드의 마이크·탭 공유·유튜브 수집용)
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://127.0.0.1:8000',
  );

  /// Supabase 프로젝트 URL / 브라우저용 publishable(anon) 키. service_role 키는 절대 넣지 않는다.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 주소창에 lecture_id가 없을 때 쓸 강의 ID. 비워두면 단독 실행 화면에서 강의를 새로 시작한다.
  static const String defaultLectureId = String.fromEnvironment('LECTURE_ID');

  /// 자막 번역 기본 언어 (ko / en / zh / ja)
  static const String defaultTargetLang = String.fromEnvironment(
    'TARGET_LANG',
    defaultValue: 'ko',
  );

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
