// lib/widgets/glossary_panel_widget.dart
// [Step 3] 용어집 조회 패널
// 디바운스 검색 + 결과 필터링 + 피드백 버튼

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';
import '../providers/subtitle_provider.dart';

class GlossaryPanelWidget extends ConsumerStatefulWidget {
  final bool embedded; // 질문 패널 내 임베드 여부

  const GlossaryPanelWidget({super.key, this.embedded = false});

  @override
  ConsumerState<GlossaryPanelWidget> createState() =>
      _GlossaryPanelWidgetState();
}

class _GlossaryPanelWidgetState extends ConsumerState<GlossaryPanelWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(glossarySearchProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 검색 입력창
        _GlossarySearchInput(
          controller: _controller,
          onChanged: (term) =>
              ref.read(glossarySearchProvider.notifier).search(term),
          onClear: () {
            _controller.clear();
            ref.read(glossarySearchProvider.notifier).clear();
          },
        ),
        const SizedBox(height: 12),

        // 결과 영역
        _buildResults(searchState),
      ],
    );
  }

  Widget _buildResults(GlossarySearchState state) {
    switch (state.status) {
      case ResponseStatus.idle:
        return _EmptyState(
          icon: Icons.search,
          message: '용어를 입력하면\nAI가 즉시 뜻풀이를 제공합니다',
        );

      case ResponseStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                ),
                SizedBox(height: 8),
                Text(
                  '용어집 검색 중...',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        );

      case ResponseStatus.success:
        if (state.results.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off,
            message: '"${state.query}"에 대한\n결과를 찾지 못했습니다',
            showFeedback: true,
            query: state.query,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: state.results
              .asMap()
              .entries
              .map(
                (entry) => _GlossaryCard(
                  entry: entry.value,
                  index: entry.key,
                ),
              )
              .toList(),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── 검색 입력창 ──────────────────────────────────────────────

class _GlossarySearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _GlossarySearchInput({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: '전공 용어를 검색하세요 (예: 역전파)',
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ─── 용어집 카드 ──────────────────────────────────────────────

class _GlossaryCard extends StatelessWidget {
  final GlossaryEntry entry;
  final int index;

  const _GlossaryCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 용어명
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.term,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 정의
          Text(
            entry.definition,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.6,
            ),
          ),

          // 예시
          if (entry.example != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 12, color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.example!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 출처
          if (entry.source != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.bookmark_border,
                    size: 11, color: Colors.white30),
                const SizedBox(width: 4),
                Text(
                  entry.source!,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.1, end: 0, duration: 250.ms);
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showFeedback;
  final String? query;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.showFeedback = false,
    this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (showFeedback) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // 피드백 전송 (용어 추가 요청)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$query" 용어 추가를 요청했습니다'),
                    backgroundColor: Colors.blueAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 14),
              label: const Text('용어 추가 요청'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
