// lib/features/caption/presentation/widgets/caption_overlay.dart
import 'dart:html' as html; // 웹 환경 크롬 확장 프로그램 양방향 JS 통신 엔진 가동

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/subtitle_model.dart';
import '../../../assistant/presentation/controllers/question_model.dart';
import '../controllers/caption_controller.dart';
import '../../../overlay/presentation/controllers/overlay_controller.dart'; 

class CaptionOverlay extends ConsumerWidget {
  const CaptionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(subtitleVisibleProvider);
    final settings = ref.watch(subtitleSettingsProvider);
    final currentSubtitle = ref.watch(currentSubtitleProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);

    // 자막 실시간 스트림 데이터 수신 → 요약용 히스토리 스택 버퍼 누적 추가
    ref.listen(subtitleStreamProvider, (_, next) {
      next.whenData((segment) {
        ref.read(subtitleHistoryProvider.notifier).add(segment);
      });
    });

    if (!visible) return const SizedBox.shrink();

    return _buildPositioned(
      settings: settings,
      child: _SubtitleBox(
        subtitle: currentSubtitle,
        settings: settings,
        connectionStatus: connectionStatus.value ?? ConnectionStatus.disconnected,
      ),
    );
  }

  // 사용자가 설정한 포지션(상/하/좌/우)에 맞춰 스크린 위에 오버레이 좌표 배치
  Widget _buildPositioned({
    required SubtitleSettings settings,
    required Widget child,
  }) {
    switch (settings.position) {
      case SubtitlePosition.top:
        return Positioned(top: 0, left: 0, right: 0, child: child);
      case SubtitlePosition.bottom:
        return Positioned(bottom: 0, left: 0, right: 0, child: child);
      case SubtitlePosition.left:
        return Positioned(
          top: 80,
          bottom: 80,
          left: 0,
          width: 260,
          child: child,
        );
      case SubtitlePosition.right:
        return Positioned(
          top: 80,
          bottom: 80,
          right: 0,
          width: 260,
          child: child,
        );
    }
  }
}

class _SubtitleBox extends ConsumerWidget {
  final SubtitleSegment? subtitle;
  final SubtitleSettings settings;
  final ConnectionStatus connectionStatus;

  const _SubtitleBox({
    this.subtitle,
    required this.settings,
    required this.connectionStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Opacity(
      opacity: settings.opacity,
      child: Container(
        constraints: BoxConstraints(minHeight: settings.widgetHeight),
        decoration: BoxDecoration(
          // 세미콜론(;) 버그를 올바른 쉼표 구조 명세로 전면 교정 완료
          color: isDark ? Colors.black87 : Colors.white, 
          borderRadius: _borderRadius(settings.position),
          border: Border.all(
            color: _statusColor(connectionStatus).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 상단 컨트롤 헤더 바 부품
            _HeaderBar(
              status: connectionStatus,
              settings: settings,
              ref: ref,
            ),
            // 2. 하단 실시간 자막/번역 내용 렌더러 부품
            _SubtitleContent(
              subtitle: subtitle,
              settings: settings,
            ),
          ],
        ),
      ),
    );
  }

  BorderRadius _borderRadius(SubtitlePosition pos) {
    switch (pos) {
      case SubtitlePosition.top:
        return const BorderRadius.vertical(bottom: Radius.circular(12));
      case SubtitlePosition.bottom:
        return const BorderRadius.vertical(top: Radius.circular(12));
      default:
        return BorderRadius.circular(12);
    }
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.greenAccent;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orangeAccent;
      case ConnectionStatus.error:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}

class _HeaderBar extends StatelessWidget {
  final ConnectionStatus status;
  final SubtitleSettings settings;
  final WidgetRef ref;

  const _HeaderBar({
    required this.status,
    required this.settings,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          _StatusDot(status: status),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final nextLanguage = settings.targetLanguage == 'ko' ? 'en' : 'ko';
              ref
                .read(subtitleSettingsProvider.notifier)
                .update(settings.copyWith(targetLanguage: nextLanguage));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                settings.targetLanguage.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.lightBlueAccent : Colors.blue[800],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Spacer(),
          // 익명 질문 단축 패널 활성화 트리거
          IconButton(
            onPressed: () {
              ref.read(questionPanelVisibleProvider.notifier).state = true;
            },
            icon: Icon(Icons.help_outline, color: isDark ? Colors.white60 : Colors.black54, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '질문하기',
          ),
          const SizedBox(width: 8),
          // 다크/라이트 실시간 UI 반전 스위치
          IconButton(
            onPressed: () {
              final currentTheme = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.yellow : Colors.black87,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '테마 변경',
          ),
          const SizedBox(width: 8),
          // 하단 바텀시트 전용 대화상자 격발
          IconButton(
            onPressed: () => _showSettingsSheet(context, ref, isDark),
            icon: Icon(Icons.tune, color: isDark ? Colors.white60 : Colors.black54, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '자막 설정',
          ),
          const SizedBox(width: 8),
          // 위젯 완전 폐쇄 버튼
          IconButton(
            onPressed: () {
              ref.read(subtitleVisibleProvider.notifier).state = false;
              // [웹 보안 해제 브릿지 연동] JS 메시지를 던져 background.js 대몬이 오프스크린과 위젯 iframe을 안전하게 파괴하도록 명령
              html.window.parent?.postMessage({'type': 'llai-close'}, '*');
            },
            icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black54, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'LIVE';
      case ConnectionStatus.connecting:
        return '연결 중...';
      case ConnectionStatus.reconnecting:
        return '재연결 중...';
      case ConnectionStatus.error:
        return '연결 오류';
      default:
        return '오프라인';
    }
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubtitleSettingsSheet(ref: ref),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected => Colors.greenAccent,
      ConnectionStatus.connecting || ConnectionStatus.reconnecting => Colors.orangeAccent,
      ConnectionStatus.error => Colors.redAccent,
      _ => Colors.grey,
    };

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: status == ConnectionStatus.connected ? [BoxShadow(color: color, blurRadius: 4)] : null,
      ),
    )
        .animate(
          onPlay: (c) => c.repeat(reverse: true),
        )
        .fade(
          duration: 1200.ms,
          begin: 1.0,
          end: status == ConnectionStatus.connected ? 0.5 : 1.0,
        );
  }
}

class _SubtitleContent extends ConsumerWidget {
  final SubtitleSegment? subtitle;
  final SubtitleSettings settings;

  const _SubtitleContent({
    this.subtitle,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (subtitle == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Text(
          '강의를 기다리는 중...',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: settings.fontSize - 2,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 원문 오디오 스피치 자막 출력
          Text(
            subtitle!.originalText,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: settings.fontSize,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          )
              .animate(key: ValueKey(subtitle!.id))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.1, end: 0, duration: 300.ms),

          // 번역 스트림 디스플레이 파트
          if (settings.showTranslation &&
              subtitle!.translatedText != null &&
              subtitle!.translatedText != subtitle!.originalText) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!.translatedText!,
              style: TextStyle(
                color: isDark 
                    ? Colors.lightBlueAccent.withValues(alpha: 0.85) 
                    : Colors.blue[700]!.withValues(alpha: 0.85),
                fontSize: settings.fontSize - 2,
                height: 1.4,
              ),
            ).animate(key: ValueKey('${subtitle!.id}_tr')).fadeIn(duration: 400.ms),
          ],

          // 실시간 강의 슬라이드 화면 감지 연동 상태 뱃지 구역
          if (subtitle!.hasVisual && subtitle!.visualSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.slideshow, color: Colors.purpleAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    subtitle!.visualSummary!,
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SubtitleSettingsSheet extends ConsumerWidget {
  final WidgetRef ref;
  const SubtitleSettingsSheet({super.key, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(subtitleSettingsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '자막 설정',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 투명도 슬라이더 파트
            _SettingRow(
              label: '패널 투명도',
              isDark: isDark,
              child: Slider(
                value: settings.opacity,
                min: 0.0, // [기능 해제 완료] 유저가 자막 레이어를 완전히 숨길 수 있게 0% 최소 한계축 수정
                max: 1.0,
                divisions: 20,
                label: '${(settings.opacity * 100).round()}%',
                activeColor: Colors.blueAccent,
                onChanged: (v) => ref
                    .read(subtitleSettingsProvider.notifier)
                    .update(settings.copyWith(opacity: v)),
              ),
            ),

            _SettingRow(
              label: '패널 너비',
              isDark: isDark,
              child: Slider(
                value: settings.panelWidth,
                min: 280.0,
                max: 600.0,
                divisions: 32,
                label: '${settings.panelWidth.round()}px',
                activeColor: Colors.blueAccent,
                onChanged: (v) {
                  ref.read(subtitleSettingsProvider.notifier).update(settings.copyWith(panelWidth: v));
                  
                  // 브라우저 네이티브 프레임 너비를 동적 드래그 확장하도록 확장 프로그램에 가로축 픽셀 데이터 즉시 전송
                  html.window.parent?.postMessage(
                    {
                      'type': 'llai-resize',
                      'width': v.toInt(),
                    },
                    '*',
                  );
                },
              ),
            ),

            // 글자 크기 슬라이더 파트
            _SettingRow(
              label: '글자 크기',
              isDark: isDark,
              child: Slider(
                value: settings.fontSize,
                min: 12.0,
                max: 24.0,
                divisions: 12,
                label: '${settings.fontSize.round()}px',
                activeColor: Colors.blueAccent,
                onChanged: (v) => ref
                    .read(subtitleSettingsProvider.notifier)
                    .update(settings.copyWith(fontSize: v)),
              ),
            ),

            // 화면 사방 배치 위치 세그먼트 파트
            _SettingRow(
              label: '위치',
              isDark: isDark,
              child: SegmentedButton<SubtitlePosition>(
                segments: const [
                  ButtonSegment(value: SubtitlePosition.top, label: Text('상단')),
                  ButtonSegment(value: SubtitlePosition.bottom, label: Text('하단')),
                  ButtonSegment(value: SubtitlePosition.left, label: Text('좌측')),
                  ButtonSegment(value: SubtitlePosition.right, label: Text('우측')),
                ],
                selected: {settings.position},
                onSelectionChanged: (v) => ref
                    .read(subtitleSettingsProvider.notifier)
                    .update(settings.copyWith(position: v.first)),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ),
            ),

            // 실시간 자막 번역 디스플레이 유무 토글
            SwitchListTile(
              title: Text('번역 표시', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text('원문 아래 번역문 표시', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
              value: settings.showTranslation,
              activeThumbColor: Colors.blueAccent,
              onChanged: (v) => ref
                  .read(subtitleSettingsProvider.notifier)
                  .update(settings.copyWith(showTranslation: v)),
            ),

            // 공장 설정 값 공장 초기화 엔진
            TextButton.icon(
              onPressed: () => ref.read(subtitleSettingsProvider.notifier).reset(),
              icon: Icon(Icons.restart_alt, color: isDark ? Colors.white38 : Colors.black38, size: 16),
              label: Text('기본값으로 초기화', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isDark;

  const _SettingRow({required this.label, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
          ),
          child,
        ],
      ),
    );
  }
}