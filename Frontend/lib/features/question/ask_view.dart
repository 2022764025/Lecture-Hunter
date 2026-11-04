import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/web/host_bridge.dart';
import '../../core/web/screen_capture.dart';
import '../../models/lecture_models.dart';
import '../../services/api_service.dart';
import '../../shared/ui.dart';
import '../overlay/widget_state.dart';
import '../session/session_controller.dart';
import 'question_controller.dart';

/// 익명 질문 하위 탭.
/// - 교수님께: 질문을 DB에 저장하고 강의 질문 목록에 실시간으로 보여준다. "AI로 다듬기"로 정리해서 보낼 수 있다.
/// - AI에게: 강의 자막을 근거로 답한다. 화면 캡처를 첨부하면 화면 내용을 보고 답한다(VLM).
class AskView extends ConsumerStatefulWidget {
  const AskView({super.key});

  @override
  ConsumerState<AskView> createState() => _AskViewState();
}

class _AskViewState extends ConsumerState<AskView> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _attachment;       // data URL
  String? _attachmentName;
  bool _sending = false;
  bool _refining = false;
  bool _success = false;
  String? _refinedFrom;      // AI가 다듬기 전 원문 (되돌리기용)
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toast(String message) => ref.read(toastProvider.notifier).show(message);

  Future<void> _capture() async {
    // 크롬 확장 안이면 확장이 위젯을 잠깐 숨기고 지금 보이는 탭 화면을 찍는다 (공유 창 없이 한 번에)
    if (HostBridge.canCaptureTab) {
      try {
        final dataUrl = await HostBridge.captureTab();
        if (!mounted) return;
        setState(() {
          _attachment = dataUrl;
          _attachmentName = '현재 화면';
        });
        _toast('지금 보이는 화면을 첨부했습니다.');
        return;
      } catch (_) {
        // 아래의 화면 공유 → 이미지 파일 순서로 넘어간다
      }
    }
    try {
      final dataUrl = await captureScreen();
      setState(() {
        _attachment = dataUrl;
        _attachmentName = '화면 캡처';
      });
      _toast('캡처를 첨부했습니다.');
    } on CaptureCancelled {
      _toast('화면 공유가 취소되었습니다.');
    } catch (_) {
      // 화면 캡처를 못 쓰는 환경이면 이미지 파일을 고르게 한다 (디자인과 같은 동작)
      final picked = await pickImageFile();
      if (picked == null || !mounted) return;
      setState(() {
        _attachment = picked.dataUrl;
        _attachmentName = picked.name;
      });
      _toast('이미지를 첨부했습니다.');
    }
  }

  Future<void> _refine() async {
    final text = _text.text.trim();
    final lectureId = ref.read(lectureIdProvider);
    if (text.isEmpty) return _toast('다듬을 질문을 먼저 입력해 주세요.');
    if (lectureId == null) return _toast('강의에 연결된 뒤 사용할 수 있습니다.');
    setState(() => _refining = true);
    try {
      final result = await ref.read(apiProvider).refineQuestion(lectureId, text);
      if (!mounted) return;
      if (result.changed) {
        setState(() {
          _refinedFrom = text;
          _text.text = result.refined;
        });
        _toast('AI가 질문을 다듬었습니다. 확인 후 전송하세요.');
      } else {
        _toast('질문을 그대로 보내도 좋아요.');
      }
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  Future<void> _submit() async {
    final target = ref.read(askTargetProvider);
    final text = _text.text.trim();
    final hasImage = target == AskTarget.ai && _attachment != null;
    if (text.isEmpty && !hasImage) {
      return _toast(target == AskTarget.ai ? '질문을 입력하거나 화면을 첨부해 주세요.' : '질문을 입력해 주세요.');
    }

    if (target == AskTarget.ai) {
      final image = hasImage ? _attachment : null;
      setState(() {
        _attachment = null;
        _attachmentName = null;
        _text.clear();
      });
      _focus.unfocus();
      await ref.read(aiQaProvider.notifier).ask(text, imageDataUrl: image);
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(questionBoardProvider.notifier).submit(text, aiRefined: _refinedFrom != null);
      if (!mounted) return;
      setState(() {
        _text.clear();
        _refinedFrom = null;
        _success = true;
      });
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(milliseconds: 2300), () {
        if (mounted) setState(() => _success = false);
      });
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(askTargetProvider);
    final ai = ref.watch(aiQaProvider);
    final aiBusy = ai.status == AiQaStatus.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EqualRow(
          gap: 8,
          children: [
            ChoiceButton(
              label: '교수님께 익명 질문',
              selected: target == AskTarget.professor,
              height: 36,
              fontEm: 0.86,
              color: AppColors.subtab,
              onTap: () => ref.read(askTargetProvider.notifier).state = AskTarget.professor,
            ),
            ChoiceButton(
              label: 'AI에게 질문',
              selected: target == AskTarget.ai,
              height: 36,
              fontEm: 0.86,
              color: AppColors.subtab,
              onTap: () => ref.read(askTargetProvider.notifier).state = AskTarget.ai,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: TextField(
            controller: _text,
            focusNode: _focus,
            expands: true,
            maxLines: null,
            maxLength: 1000,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (_) {
              if (_success) setState(() => _success = false);
            },
            style: em(0.97, height: 1.6),
            decoration: fieldDecoration(
              hint: target == AskTarget.ai ? 'AI에게 궁금한 내용을 입력하세요.' : '궁금한 내용을 입력하세요.',
              fill: AppColors.cream,
              radius: 15,
              bordered: false,
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
            ),
          ),
        ),
        if (_refinedFrom != null && target == AskTarget.professor)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(AppIcons.sparkle, size: 13, color: AppColors.sageDark),
                const SizedBox(width: 4),
                Expanded(child: Text('AI가 다듬은 질문입니다.', style: em(0.79, color: AppColors.sageDark))),
                GestureDetector(
                  onTap: () => setState(() {
                    _text.text = _refinedFrom!;
                    _refinedFrom = null;
                  }),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text('원래대로', style: em(0.79, weight: FontWeight.w600, color: AppColors.secondary)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (target == AskTarget.ai)
          ActionButton(
            style: ActionStyle.outline,
            icon: AppIcons.image,
            label: _attachment != null ? '화면 캡처 첨부됨' : '화면 캡처',
            onTap: aiBusy ? null : _capture,
          )
        else
          ActionButton(
            style: ActionStyle.outline,
            icon: AppIcons.sparkle,
            label: 'AI로 질문 다듬기',
            loading: _refining,
            onTap: _refining || _sending ? null : _refine,
          ),
        const SizedBox(height: 9),
        ActionButton(
          icon: _success ? AppIcons.check : AppIcons.send,
          label: _success ? '질문이 전송되었습니다.' : '질문 전송',
          loading: _sending || aiBusy,
          onTap: _sending || aiBusy ? null : _submit,
        ),
        if (_attachmentName != null && target == AskTarget.ai)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('첨부: $_attachmentName', style: em(0.79, color: AppColors.sageDark)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() {
                    _attachment = null;
                    _attachmentName = null;
                  }),
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(Icons.close_rounded, size: 14, color: AppColors.secondary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (target == AskTarget.ai) const _AiAnswerSection() else const _QuestionBoard(),
      ],
    );
  }
}

// ─── AI 답변 ──────────────────────────────────────────────────

class _AiAnswerSection extends ConsumerWidget {
  const _AiAnswerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiQaProvider);
    if (state.status == AiQaStatus.idle) {
      return const InlineNote('강의 자막을 근거로 AI가 답해요. 화면 캡처를 첨부하면 슬라이드·수식·코드 화면을 보고 답합니다.');
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(state.withImage ? '질문 · 화면 첨부' : '질문', style: em(0.83, weight: FontWeight.w700, color: AppColors.muted)),
              const Spacer(),
              if (state.status != AiQaStatus.loading)
                GestureDetector(
                  onTap: () => ref.read(aiQaProvider.notifier).reset(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text('새 대화', style: em(0.79, weight: FontWeight.w600, color: AppColors.sageDark)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(state.question, style: em(0.91, color: AppColors.ink, height: 1.55)),
          const Divider(height: 22, color: AppColors.border),
          Text('AI 답변', style: em(0.83, weight: FontWeight.w700, color: AppColors.sageDark)),
          const SizedBox(height: 6),
          switch (state.status) {
            AiQaStatus.loading => Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.withImage ? '화면을 분석하는 중… (1~2분 걸릴 수 있어요)' : 'AI가 강의 내용을 찾는 중…',
                      style: em(0.86, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            AiQaStatus.error => InlineNote(state.error ?? '답변을 받지 못했습니다.', error: true),
            _ => Text(state.answer?.answer ?? '', style: em(0.91, color: AppColors.summaryText, height: 1.65)),
          },
          if (state.status == AiQaStatus.done && (state.answer?.sources.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Text('근거 자막', style: em(0.79, weight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(height: 4),
            for (final s in state.answer!.sources.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('· ${s.text}', maxLines: 2, overflow: TextOverflow.ellipsis, style: em(0.79, color: AppColors.muted, height: 1.45)),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── 강의 질문 목록 ───────────────────────────────────────────

class _QuestionBoard extends ConsumerWidget {
  const _QuestionBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(questionBoardProvider);
    final me = ref.watch(clientIdProvider);
    final mine = board.items.where((q) => q.clientId == me).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('강의 질문', style: em(1.0, weight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('${board.items.length}', style: em(0.86, weight: FontWeight.w700, color: AppColors.sageDark)),
            const Spacer(),
            if (mine > 0) Text('내 질문 $mine개', style: em(0.79, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 10),
        if (board.loading && board.items.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage)))
        else if (board.error != null && board.items.isEmpty)
          InlineNote(board.error!, error: true)
        else if (board.items.isEmpty)
          const InlineNote('아직 등록된 질문이 없어요. 수업 중 궁금한 점을 익명으로 남겨 보세요.')
        else
          for (final q in board.items) _QuestionCard(question: q, mine: q.clientId == me),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.mine});
  final LectureQuestion question;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        color: mine ? AppColors.sageSoft : AppColors.cream,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        radius: 13,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.content, style: em(0.91, height: 1.55)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(relativeTime(question.createdAt), style: em(0.76, color: AppColors.muted)),
                if (mine) Text('내 질문', style: em(0.76, weight: FontWeight.w700, color: AppColors.sageDark)),
                if (question.isAiRefined) Text('AI 정리', style: em(0.76, color: AppColors.muted)),
                if (question.isResolved)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(AppIcons.check, size: 12, color: AppColors.sageDark),
                    const SizedBox(width: 3),
                    Text('답변 완료', style: em(0.76, weight: FontWeight.w700, color: AppColors.sageDark)),
                  ]),
              ],
            ),
            if (question.answer != null) ...[
              const SizedBox(height: 8),
              Text('교수님 답변 · ${question.answer}', style: em(0.86, color: AppColors.noticeText, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
