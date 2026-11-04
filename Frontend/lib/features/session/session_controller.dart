import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/web/audio_bridge.dart';
import '../../core/web/host_bridge.dart';
import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../../services/local_store.dart';
import '../../services/realtime_service.dart';

// ─── 공용 서비스 ───────────────────────────────────────────────

/// main.dart에서 override 한다 (SharedPreferences는 비동기로 열어야 해서)
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('localStoreProvider'));

final apiProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(api.dispose);
  return api;
});

final clientIdProvider = Provider<String>((ref) => ref.watch(localStoreProvider).clientId());

final audioBridgeProvider = Provider<AudioBridge>((ref) {
  final bridge = AudioBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

// ─── 강의 세션 ────────────────────────────────────────────────

/// 강의 음성이 어디서 오는지
enum LectureSource {
  /// 크롬 확장이 탭 오디오를 보낸다 (iframe 안에서 실행)
  extension,

  /// 주소창의 lecture_id로 이미 진행 중인 강의를 본다 (오디오는 다른 곳에서 보냄)
  linked,

  /// 단독 실행: 서버가 유튜브 오디오를 직접 받음 (트랙 B)
  youtube,

  /// 단독 실행: 이 브라우저의 마이크 (트랙 A)
  mic,

  /// 단독 실행: 화면/탭 공유의 오디오 (트랙 A, 시스템 오디오)
  tab,
}

class SessionState {
  final String? lectureId;
  final LectureSource? source;
  final String? youtubeVideoId;
  final AudioBridgeState audio;
  final String audioMessage;

  const SessionState({
    this.lectureId,
    this.source,
    this.youtubeVideoId,
    this.audio = AudioBridgeState.idle,
    this.audioMessage = '',
  });

  bool get standaloneAudio => source == LectureSource.youtube || source == LectureSource.mic || source == LectureSource.tab;

  /// 오디오 전송 상태를 알 수 있는지 (단독 실행이거나, 크롬 확장이 상태를 보내 준 경우)
  bool get audioKnown => standaloneAudio || (source == LectureSource.extension && audio != AudioBridgeState.idle);

  SessionState copyWith({
    String? lectureId,
    LectureSource? source,
    String? youtubeVideoId,
    AudioBridgeState? audio,
    String? audioMessage,
  }) =>
      SessionState(
        lectureId: lectureId ?? this.lectureId,
        source: source ?? this.source,
        youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
        audio: audio ?? this.audio,
        audioMessage: audioMessage ?? this.audioMessage,
      );
}

final _lectureIdPattern = RegExp(r'^[\w\-.:]{1,128}$');
final _youtubeIdPattern = RegExp(r'(?:v=|youtu\.be/|/embed/|/shorts/|/live/)([A-Za-z0-9_-]{11})');

String? parseYoutubeId(String value) {
  final text = value.trim();
  final match = _youtubeIdPattern.firstMatch(text);
  if (match != null) return match.group(1);
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(text) ? text : null;
}

class SessionController extends Notifier<SessionState> {
  StreamSubscription<AudioBridgeEvent>? _audioSub;
  StreamSubscription<({String state, String message})>? _hostAudioSub;

  @override
  SessionState build() {
    ref.onDispose(() {
      _audioSub?.cancel();
      _hostAudioSub?.cancel();
      _hostAudioSub = null;
    });
    final params = Uri.base.queryParameters;
    final fromUrl = (params['lecture_id'] ?? params['room'] ?? '').trim();
    final id = fromUrl.isNotEmpty ? fromUrl : AppConfig.defaultLectureId;
    if (id.isEmpty || !_lectureIdPattern.hasMatch(id)) return const SessionState();

    if (HostBridge.embedded) {
      // 크롬 확장(offscreen 문서)이 보내는 탭 오디오 전송 상태
      _hostAudioSub ??= HostBridge.audioStatus.listen((s) {
        final audio = switch (s.state) {
          'connecting' => AudioBridgeState.starting,
          'connected' => AudioBridgeState.connected,
          'reconnecting' => AudioBridgeState.reconnecting,
          'error' => AudioBridgeState.error,
          'stopped' => AudioBridgeState.ended,
          _ => null,
        };
        if (audio != null) state = state.copyWith(audio: audio, audioMessage: s.message);
      });
    }
    return SessionState(
      lectureId: id,
      source: HostBridge.embedded ? LectureSource.extension : LectureSource.linked,
    );
  }

  String _newLectureId(String prefix) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$prefix-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// 단독 실행 화면에서 강의 시작 (마이크 / 탭 오디오 / 유튜브)
  Future<void> startStandalone(LectureSource source, {String? youtubeUrl, required String targetLang}) async {
    await stopStandalone(saveSummary: false);

    String? videoId;
    if (source == LectureSource.youtube) {
      videoId = parseYoutubeId(youtubeUrl ?? '');
      if (videoId == null) throw const ApiException('유튜브 영상 주소를 확인해 주세요.');
    }
    final lectureId = _newLectureId(switch (source) {
      LectureSource.youtube => 'yt-$videoId',
      LectureSource.mic => 'mic',
      _ => 'tab',
    });

    final query = {
      'target_lang': targetLang,
      if (videoId != null) 'youtube': 'https://www.youtube.com/watch?v=$videoId',
    };
    final wsUrl = Uri.parse('${AppConfig.wsBaseUrl}/ws/audio/$lectureId').replace(queryParameters: query).toString();

    final bridge = ref.read(audioBridgeProvider);
    _audioSub ??= bridge.events.listen((event) {
      state = state.copyWith(audio: event.state, audioMessage: event.message);
    });
    state = SessionState(lectureId: lectureId, source: source, youtubeVideoId: videoId, audio: AudioBridgeState.starting);
    try {
      await bridge.start(mode: source.name, wsUrl: wsUrl);
    } catch (e) {
      state = const SessionState().copyWith(audio: AudioBridgeState.error, audioMessage: e.toString().replaceFirst('Error: ', ''));
      rethrow;
    }
  }

  /// 단독 실행 강의 종료. 전체 요약을 만들어 저장한다 (lecture_summaries 'full').
  Future<void> stopStandalone({bool saveSummary = true}) async {
    if (!state.standaloneAudio) return;
    final lectureId = state.lectureId;
    ref.read(audioBridgeProvider).stop();
    state = state.copyWith(audio: AudioBridgeState.idle, audioMessage: '');
    if (saveSummary && lectureId != null) {
      unawaited(ref.read(apiProvider).endLecture(lectureId).catchError((_) {}));
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final lectureIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.lectureId)));

/// 강의가 정해지면 Realtime 구독을 시작하고, 강의가 바뀌거나 앱이 끝나면 정리한다
final realtimeProvider = Provider<LectureRealtime?>((ref) {
  final lectureId = ref.watch(lectureIdProvider);
  if (lectureId == null || !AppConfig.hasSupabase) return null;
  final realtime = LectureRealtime(lectureId);
  unawaited(realtime.start());
  ref.onDispose(realtime.dispose);
  return realtime;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final realtime = ref.watch(realtimeProvider);
  if (realtime == null) return Stream.value(AppConfig.hasSupabase ? SyncStatus.idle : SyncStatus.error);
  return (() async* {
    yield realtime.currentStatus;
    yield* realtime.status;
  })();
});

/// 강의 경과 시간·오디오 수신 여부 (10초마다 갱신)
class LectureStatusController extends Notifier<LectureStatus?> {
  Timer? _timer;

  @override
  LectureStatus? build() {
    final lectureId = ref.watch(lectureIdProvider);
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (lectureId == null) return null;
    Future.microtask(() => refresh());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    return null;
  }

  Future<void> refresh() async {
    final lectureId = ref.read(lectureIdProvider);
    if (lectureId == null) return;
    try {
      state = await ref.read(apiProvider).lectureStatus(lectureId);
    } catch (_) {
      // 서버가 잠깐 안 될 때는 마지막 값을 유지
    }
  }
}

final lectureStatusProvider = NotifierProvider<LectureStatusController, LectureStatus?>(LectureStatusController.new);
