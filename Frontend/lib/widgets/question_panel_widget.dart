// lib/widgets/question_panel_widget.dart
// [Step 2] 질문 입력 패널 - 슬라이드 인/아웃 애니메이션 포함
// 모드 스위치: "교수에게 질문" / "용어집 조회"

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subtitle_provider.dart';
import '../models/question_model.dart';
import 'glossary_panel_widget.dart';

class QuestionPanelWidget extends ConsumerStatefulWidget {
  const QuestionPanelWidget({super.key});

  @override
  ConsumerState<QuestionPanelWidget> createState() =>
      _QuestionPanelWidgetState();
}

class _QuestionPanelWidgetState extends ConsumerState<QuestionPanelWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(questionPanelVisibleProvider);
    final mode = ref.watch(questionModeProvider);
    final responseState = ref.watch(questionResponseProvider);

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(1.0, 0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: _PanelContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 패널 헤더
              _PanelHeader(
                onClose: () {
                  ref.read(questionPanelVisibleProvider.notifier).state = false;
                  ref.read(questionResponseProvider.notifier).reset();
                  _controller.clear();
                },
              ),
              // 모드 토글 (교수 질문 / 용어집)
              _ModeToggle(
                mode: mode,
                onChanged: (m) {
                  ref.read(questionModeProvider.notifier).state = m;
                  ref.read(questionResponseProvider.notifier).reset();
                  ref.read(glossarySearchProvider.notifier).clear();
                  _controller.clear();
                },
              ),
              const SizedBox(height: 12),

              // 모드별 콘텐츠
              if (mode == QuestionMode.professor) ...[
                _QuestionInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmit: () => _submit(mode),
                  hintText: '강의 내용에 대해 질문하세요...',
                ),
                const SizedBox(height: 10),
                _SubmitButton(
                  isLoading: responseState.status == ResponseStatus.loading,
                  onTap: () => _submit(mode),
                ),
                if (responseState.status != ResponseStatus.idle)
                  _ResponseCard(state: responseState),
              ] else ...[
                // 용어집 모드 - GlossaryPanel 임베드
                const GlossaryPanelWidget(embedded: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit(QuestionMode mode) {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(questionResponseProvider.notifier).submit(question, mode);
  }
}

// ─── 패널 컨테이너 ────────────────────────────────────────────

class _PanelContainer extends StatelessWidget {
  final Widget child;
  const _PanelContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(-4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ─── 패널 헤더 ────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent, size: 18),
        const SizedBox(width: 8),
        const Text(
          '강의 도우미',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white38, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

// ─── 모드 토글 ────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final QuestionMode mode;
  final ValueChanged<QuestionMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Tab(
            label: '교수에게 질문',
            icon: Icons.school_outlined,
            selected: mode == QuestionMode.professor,
            onTap: () => onChanged(QuestionMode.professor),
          ),
          _Tab(
            label: '용어집 조회',
            icon: Icons.menu_book_outlined,
            selected: mode == QuestionMode.glossary,
            onTap: () => onChanged(QuestionMode.glossary),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 질문 입력창 ──────────────────────────────────────────────

class _QuestionInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final String hintText;

  const _QuestionInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: 3,
      minLines: 2,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

// ─── 전송 버튼 ────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, size: 16),
                SizedBox(width: 6),
                Text('질문 전송', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }
}

// ─── 응답 카드 ────────────────────────────────────────────────

class _ResponseCard extends StatelessWidget {
  final QuestionResponseState state;

  const _ResponseCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: _buildContent(),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildContent() {
    switch (state.status) {
      case ResponseStatus.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'AI가 강의 내용 검색 중...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        );

      case ResponseStatus.error:
        return Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.response?.answer ?? '오류 발생',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],
        );

      case ResponseStatus.success:
        final response = state.response!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 답변 텍스트
            Text(
              response.answer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            // 출처
            if (response.source != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.bookmark_outline,
                      size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    response.source!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            // 관련 슬라이드
            if (response.relatedSlide != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.slideshow,
                      size: 12, color: Colors.purpleAccent),
                  const SizedBox(width: 4),
                  Text(
                    response.relatedSlide!,
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            // 키포인트
            if (response.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: response.keyPoints
                    .map(
                      (kp) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          kp,
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
