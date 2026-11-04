// Lecture-Hunter 프론트엔드 진입점
//
// 실행: flutter run -d chrome --web-port=9998 --dart-define-from-file=env.json
// 크롬 확장은 유튜브 위에 확장 페이지(frame.html)를 띄우고, 그 안에서
// http://127.0.0.1:9998/?lecture_id=<강의ID> 를 iframe으로 연다 (Extension/README 참고).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/web/host_bridge.dart';
import 'features/overlay/overlay_page.dart';
import 'features/session/session_controller.dart';
import 'services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      // 위젯은 로그인 없이 익명으로 쓴다
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false, detectSessionInUri: false),
    );
  }
  // 크롬 확장(부모 창) 메시지는 llai-ready 를 보내기 전부터 듣고 있어야 한다
  HostBridge.init();
  final store = await LocalStore.open();

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const LectureHunterApp(),
    ),
  );
}

class LectureHunterApp extends StatelessWidget {
  const LectureHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecture-Hunter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const OverlayPage(),
    );
  }
}
