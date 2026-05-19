// lib/widgets/connection_bar_widget.dart
// 자막 숨겼을 때 보이는 미니 복원 버튼

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';
import '../providers/subtitle_provider.dart';

class ConnectionBarWidget extends ConsumerWidget {
  const ConnectionBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleVisible = ref.watch(subtitleVisibleProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final status = connectionStatus.value ?? ConnectionStatus.disconnected;

    // 자막이 보이는 중이면 복원버튼 숨김
    if (subtitleVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => ref.read(subtitleVisibleProvider.notifier).state = true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _statusColor(status).withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pulsingDot(status),
              const SizedBox(width: 6),
              const Text(
                'LiveLectureAI',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_less, color: Colors.white38, size: 14),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _pulsingDot(ConnectionStatus status) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: _statusColor(status),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(duration: 1000.ms, begin: 1.0, end: 0.3);
  }

  Color _statusColor(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.connected => Colors.greenAccent,
      ConnectionStatus.connecting || ConnectionStatus.reconnecting =>
        Colors.orangeAccent,
      _ => Colors.grey,
    };
  }
}
