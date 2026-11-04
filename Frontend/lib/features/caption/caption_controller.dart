import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../models/caption_language.dart';
import '../../models/lecture_models.dart';
import '../overlay/widget_state.dart';
import '../session/session_controller.dart';

/// 실시간 자막 목록 (Realtime INSERT/UPDATE 반영, 최근 100개)
final captionsProvider = StreamProvider<List<Caption>>((ref) {
  final realtime = ref.watch(realtimeProvider);
  if (realtime == null) return Stream.value(const []);
  return (() async* {
    yield realtime.currentCaptions;
    yield* realtime.captions;
  })();
});

final latestCaptionProvider = Provider<Caption?>((ref) {
  final list = ref.watch(captionsProvider).valueOrNull ?? const [];
  return list.isEmpty ? null : list.last;
});

/// 자막 번역 언어. 바꾸면 백엔드에 알려서 이후 자막부터 그 언어로 번역하게 한다
/// (백엔드는 최근 자막 3개도 새 언어로 다시 번역한다).
class CaptionLanguageController extends Notifier<CaptionLanguage> {
  @override
  CaptionLanguage build() {
    final saved = CaptionLanguage.parse(ref.read(localStoreProvider).captionLanguage());
    final initial = saved ?? CaptionLanguage.parse(AppConfig.defaultTargetLang) ?? CaptionLanguage.ko;
    // 강의가 정해지면(또는 바뀌면) 현재 언어를 서버에 맞춘다. 서버가 재시작되면 설정이 사라지기 때문.
    ref.listen<String?>(lectureIdProvider, (_, next) {
      if (next != null) Future.microtask(() => _push(next, state, silent: true));
    }, fireImmediately: true);
    return initial;
  }

  Future<void> select(CaptionLanguage lang) async {
    if (lang == state) return;
    final previous = state;
    state = lang;
    await ref.read(localStoreProvider).saveCaptionLanguage(lang.code);
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId != null && !await _push(lectureId, lang)) {
      state = previous;
      await ref.read(localStoreProvider).saveCaptionLanguage(previous.code);
    }
  }

  Future<bool> _push(String lectureId, CaptionLanguage lang, {bool silent = false}) async {
    try {
      await ref.read(apiProvider).setTargetLanguage(lectureId, lang);
      return true;
    } catch (e) {
      if (!silent) ref.read(toastProvider.notifier).show('번역 언어를 바꾸지 못했습니다: $e');
      return false;
    }
  }
}

final captionLanguageProvider =
    NotifierProvider<CaptionLanguageController, CaptionLanguage>(CaptionLanguageController.new);
