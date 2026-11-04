import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/web/audio_bridge.dart';
import '../../models/caption_language.dart';
import '../../models/lecture_models.dart';
import '../../services/realtime_service.dart';
import '../../shared/ui.dart';
import '../session/session_controller.dart';
import 'caption_controller.dart';

/// 자막 탭: 실시간 자막 + 언어 선택 + 원문 / 번역
class CaptionTab extends ConsumerStatefulWidget {
  const CaptionTab({super.key});

  @override
  ConsumerState<CaptionTab> createState() => _CaptionTabState();
}

class _CaptionTabState extends ConsumerState<CaptionTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // "번역 중…" → "번역 실패" 같은 시간 기반 표시를 갱신
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(captionLanguageProvider);
    final caption = ref.watch(latestCaptionProvider);
    final (statusLabel, statusColor) = _status(caption);

    final (translation, translationPending) = _translationText(caption, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('실시간 자막',
                  style: em(1.25, weight: FontWeight.w700, height: 1.4, letterSpacing: -0.35)),
            ),
            StatusBadge(label: statusLabel, color: statusColor),
          ],
        ),
        if (_audioNote() case final note?) ...[
          const SizedBox(height: 8),
          InlineNote(note, error: ref.watch(sessionProvider).audio == AudioBridgeState.error),
        ],
        const SizedBox(height: 15),
        EqualRow(
          gap: 8,
          children: [
            for (final l in CaptionLanguage.values)
              ChoiceButton(
                label: l.label,
                leading: l.flag,
                selected: l == lang,
                height: 48,
                fontEm: 1,
                selectedWeight: FontWeight.w700,
                onTap: () => ref.read(captionLanguageProvider.notifier).select(l),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Panel(
          minHeight: 134,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.originalHeading, style: em(1.04, weight: FontWeight.w700, color: AppColors.secondary)),
              const SizedBox(height: 7),
              Text(
                caption?.original ?? '강의 원문 자막이 여기에 표시됩니다.',
                style: em(0.94, color: AppColors.originalText, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          color: Colors.transparent,
          border: AppColors.sage,
          minHeight: 175,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTitle(icon: AppIcons.translate, title: lang.translationHeading, fontEm: 1.1),
              const SizedBox(height: 13),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  translation,
                  key: ValueKey('${caption?.id}-$translation'),
                  style: em(
                    1.13,
                    weight: FontWeight.w600,
                    height: 1.65,
                    color: translationPending ? AppColors.muted : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption?.visualSummary != null) ...[
          const SizedBox(height: 12),
          Panel(
            color: AppColors.sageSoft,
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTitle(icon: AppIcons.image, title: '슬라이드 분석', fontEm: 0.92),
                const SizedBox(height: 6),
                Text(caption!.visualSummary!, style: em(0.86, color: AppColors.noticeText, height: 1.55)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  (String, bool) _translationText(Caption? caption, CaptionLanguage lang) {
    if (caption == null) return (lang.translationPlaceholder, true);
    if (lang.matches(caption.sourceLang)) return (caption.original, false); // 같은 언어는 번역하지 않음
    if (caption.translated != null && lang.matches(caption.targetLang)) return (caption.translated!, false);
    final age = DateTime.now().difference(caption.createdAt);
    return (age.inSeconds < 40 ? '번역 중…' : '이 자막은 번역하지 못했습니다.', true);
  }

  (String, Color) _status(Caption? latest) {
    if (!AppConfig.hasSupabase) return ('Supabase 설정 없음', AppColors.error);
    final session = ref.watch(sessionProvider);
    if (session.lectureId == null) return ('강의 연결 전', AppColors.muted);

    final sync = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.connecting;
    switch (sync) {
      case SyncStatus.connecting:
      case SyncStatus.idle:
        return ('연결 중', AppColors.warning);
      case SyncStatus.polling:
        return ('재연결 중', AppColors.warning);
      case SyncStatus.error:
        return ('연결 오류', AppColors.error);
      case SyncStatus.live:
        break;
    }

    // 단독 실행(마이크·탭·유튜브)이거나 크롬 확장이 탭 오디오 상태를 알려 준 경우
    if (session.audioKnown) {
      switch (session.audio) {
        case AudioBridgeState.starting:
          return ('오디오 연결 중', AppColors.warning);
        case AudioBridgeState.reconnecting:
          return ('오디오 재연결 중', AppColors.warning);
        case AudioBridgeState.error:
          return ('오디오 오류', AppColors.error);
        case AudioBridgeState.idle:
        case AudioBridgeState.ended:
          return ('강의 종료됨', AppColors.muted);
        case AudioBridgeState.connected:
          break;
      }
    }

    final fresh = latest != null && DateTime.now().difference(latest.createdAt).inSeconds < 60;
    if (fresh) return ('자막 수신 중', AppColors.sageDark);
    final streaming = ref.watch(lectureStatusProvider)?.streaming ?? false;
    return streaming || session.audioKnown ? ('음성 대기 중', AppColors.sageDark) : ('오디오 연결 대기', AppColors.muted);
  }

  /// 오디오가 끊겼거나 오류일 때 이유 (예: "백엔드 서버(127.0.0.1:8000)에 다시 연결하는 중 · 4초 후")
  String? _audioNote() {
    final session = ref.watch(sessionProvider);
    if (!session.audioKnown || session.audioMessage.isEmpty) return null;
    return session.audio == AudioBridgeState.reconnecting || session.audio == AudioBridgeState.error
        ? session.audioMessage
        : null;
  }
}
