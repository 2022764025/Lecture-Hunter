import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/web/audio_bridge.dart';
import '../../shared/ui.dart';
import '../caption/caption_controller.dart';
import '../session/session_controller.dart';
import 'lecture_widget.dart';

/// 위젯을 크롬 확장 없이 직접 열었을 때의 화면 (개발·시연용).
/// 과제헌터.html 처럼 어두운 배경 가운데에 위젯을 놓고, 위에 "강의 연결" 패널을 둔다.
/// 유튜브 모드에서는 왼쪽에 영상을 함께 띄운다.
class StagePage extends ConsumerWidget {
  const StagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final videoId = session.source == LectureSource.youtube ? session.youtubeVideoId : null;

    return ColoredBox(
      color: AppColors.stage,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        const widgetColumn = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 420, child: _ConnectPanel()),
            SizedBox(height: 14),
            LectureWidget(),
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: videoId == null
                  ? widgetColumn
                  : wide
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: (constraints.maxWidth - 520).clamp(480.0, 1100.0),
                              child: _YoutubePlayer(videoId: videoId),
                            ),
                            const SizedBox(width: 24),
                            widgetColumn,
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 420, child: _YoutubePlayer(videoId: videoId)),
                            const SizedBox(height: 14),
                            widgetColumn,
                          ],
                        ),
            ),
          ),
        );
      }),
    );
  }
}

final _registeredPlayers = <String>{};

class _YoutubePlayer extends StatelessWidget {
  const _YoutubePlayer({required this.videoId});
  final String videoId;

  @override
  Widget build(BuildContext context) {
    final viewType = 'llai-youtube-$videoId';
    if (_registeredPlayers.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        return web.HTMLIFrameElement()
          ..src = 'https://www.youtube.com/embed/$videoId?autoplay=1&rel=0'
          ..allow = 'autoplay; encrypted-media; picture-in-picture'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(aspectRatio: 16 / 9, child: HtmlElementView(viewType: viewType)),
        ),
        const SizedBox(height: 8),
        Text(
          '자막용 음성은 서버가 유튜브에서 직접 받습니다. 영상을 멈추거나 건너뛰어도 자막은 처음부터 실시간 속도로 이어집니다.',
          style: em(0.78, color: const Color(0xFFB9B6B1), height: 1.5),
        ),
      ],
    );
  }
}

/// 단독 실행에서 강의 음성을 보낼 방법을 고르는 패널
class _ConnectPanel extends ConsumerStatefulWidget {
  const _ConnectPanel();

  @override
  ConsumerState<_ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends ConsumerState<_ConnectPanel> {
  final _url = TextEditingController();
  LectureSource _choice = LectureSource.youtube;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).startStandalone(
            _choice,
            youtubeUrl: _url.text,
            targetLang: ref.read(captionLanguageProvider).code,
          );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final running = session.standaloneAudio &&
        (session.audio == AudioBridgeState.starting ||
            session.audio == AudioBridgeState.connected ||
            session.audio == AudioBridgeState.reconnecting);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('강의 연결', style: em(1, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.lectureId == null ? '크롬 확장 없이 실행 중' : '강의 ID · ${session.lectureId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: em(0.78, color: const Color(0xFF9E9A94)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (session.source == LectureSource.linked)
            Text('주소창의 강의를 보고 있어요. 오디오는 다른 곳(크롬 확장 등)에서 보내는 중입니다.',
                style: em(0.82, color: const Color(0xFFCFCBC5), height: 1.5))
          else if (running)
            Row(
              children: [
                Expanded(
                  child: StatusBadge(
                    label: switch (session.audio) {
                      AudioBridgeState.connected => '${_label(session.source)} 전송 중',
                      AudioBridgeState.reconnecting => '재연결 중 · ${session.audioMessage}',
                      _ => '연결 중…',
                    },
                    color: session.audio == AudioBridgeState.connected ? AppColors.sage : AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: ActionButton(
                    style: ActionStyle.outline,
                    label: '강의 종료',
                    onTap: () => ref.read(sessionProvider.notifier).stopStandalone(),
                  ),
                ),
              ],
            )
          else ...[
            EqualRow(
              gap: 7,
              children: [
                for (final s in const [LectureSource.youtube, LectureSource.mic, LectureSource.tab])
                  ChoiceButton(
                    label: _label(s),
                    selected: _choice == s,
                    height: 36,
                    fontEm: 0.84,
                    onTap: () => setState(() => _choice = s),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            if (_choice == LectureSource.youtube) ...[
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _url,
                  onSubmitted: (_) => _start(),
                  style: em(0.9),
                  decoration: fieldDecoration(hint: 'https://www.youtube.com/watch?v=...'),
                ),
              ),
              const SizedBox(height: 9),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  _choice == LectureSource.mic
                      ? '이 브라우저의 마이크로 강의 음성을 받습니다 (오프라인 강의실).'
                      : '공유할 탭이나 화면을 고르고 "오디오 공유"를 켜 주세요 (온라인 강의).',
                  style: em(0.8, color: const Color(0xFFB9B6B1), height: 1.5),
                ),
              ),
            ActionButton(label: '강의 시작', onTap: _start),
            if (_error != null || session.audio == AudioBridgeState.error) ...[
              const SizedBox(height: 8),
              Text(_error ?? session.audioMessage, style: em(0.8, color: const Color(0xFFE59A94))),
            ],
            if (session.audio == AudioBridgeState.ended) ...[
              const SizedBox(height: 8),
              Text('영상 오디오가 끝났습니다. 요약 탭에서 전체 요약을 볼 수 있어요.', style: em(0.8, color: const Color(0xFFB9B6B1))),
            ],
          ],
          if (!AppConfig.hasSupabase) ...[
            const SizedBox(height: 8),
            Text('SUPABASE_URL / SUPABASE_ANON_KEY 가 없습니다. --dart-define-from-file=env.json 으로 실행하세요.',
                style: em(0.78, color: const Color(0xFFE59A94), height: 1.5)),
          ],
        ],
      ),
    );
  }

  String _label(LectureSource? s) => switch (s) {
        LectureSource.youtube => '유튜브 주소',
        LectureSource.mic => '마이크',
        LectureSource.tab => '탭·화면 오디오',
        _ => '오디오',
      };
}
