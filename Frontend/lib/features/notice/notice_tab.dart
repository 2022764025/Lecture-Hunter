import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/web/host_bridge.dart';
import '../../models/lecture_models.dart';
import '../../shared/ui.dart';
import 'notice_controller.dart';

/// 공지 탭. 디자인의 세 묶음(중요 공지 / 교재 및 참고 자료 / 과제 안내)에 category를 대응시킨다.
///   important → 중요 공지(초록 박스), material → 교재 및 참고 자료, assignment → 과제 안내, general → 일반 공지
class NoticeTab extends ConsumerWidget {
  const NoticeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final byCategory = <NoticeCategory, List<LectureNotice>>{};
    for (final n in state.items) {
      byCategory.putIfAbsent(n.category, () => []).add(n);
    }
    final important = byCategory[NoticeCategory.important] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 중요 공지
        Panel(
          color: AppColors.sageSoft,
          minHeight: 80,
          padding: const EdgeInsets.fromLTRB(13, 15, 13, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTitle(icon: AppIcons.pin, title: '중요 공지'),
              const SizedBox(height: 9),
              if (state.loading && state.items.isEmpty)
                Text('공지를 불러오는 중…', style: em(0.86, color: AppColors.noticeText, height: 1.55))
              else if (state.error != null && state.items.isEmpty)
                InlineNote(state.error!, error: true)
              else if (important.isEmpty)
                Text(
                  state.items.isEmpty ? '아직 등록된 공지가 없습니다. 교수님이 공지를 올리면 여기에 바로 표시됩니다.' : '등록된 중요 공지가 없습니다.',
                  style: em(0.86, color: AppColors.noticeText, height: 1.55),
                )
              else
                for (final (i, n) in important.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  // 제목을 박스 제목과 같은 '중요 공지'로 넣으면 겹치므로 내용만 보여준다 (디자인 모양)
                  if (n.title.trim() != '중요 공지' || n.displayContent == null) ...[
                    _ItemTitle(notice: n, color: AppColors.sageDark),
                    if (n.displayContent != null) const SizedBox(height: 3),
                  ],
                  if (n.displayContent != null)
                    Text(n.displayContent!, style: em(0.86, color: AppColors.noticeText, height: 1.55)),
                ],
            ],
          ),
        ),
        const SizedBox(height: 13),
        for (final (category, icon, title) in const [
          (NoticeCategory.material, AppIcons.book, '교재 및 참고 자료'),
          (NoticeCategory.assignment, AppIcons.clipboard, '과제 안내'),
          (NoticeCategory.general, AppIcons.campaign, '일반 공지'),
        ])
          if (byCategory[category]?.isNotEmpty ?? false) ...[
            _NoticeBox(icon: icon, title: title, items: byCategory[category]!),
            const SizedBox(height: 13),
          ],
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.icon, required this.title, required this.items});
  final IconData icon;
  final String title;
  final List<LectureNotice> items;

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: Colors.white,
      border: AppColors.border,
      padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTitle(icon: icon, title: title),
          const SizedBox(height: 11),
          for (final (i, n) in items.indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
            ],
            _ItemTitle(notice: n),
            if (n.displayContent != null) ...[
              const SizedBox(height: 4),
              Text(n.displayContent!, style: em(0.82, color: AppColors.muted, height: 1.45)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ItemTitle extends StatelessWidget {
  const _ItemTitle({required this.notice, this.color = AppColors.ink});
  final LectureNotice notice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final link = notice.link;
    return Row(
      children: [
        if (notice.isPinned) ...[
          Icon(AppIcons.pin, size: 13, color: color),
          const SizedBox(width: 3),
        ],
        Expanded(child: Text(notice.title, style: em(0.92, weight: FontWeight.w700, color: color, height: 1.3))),
        if (link != null)
          Tooltip(
            message: '링크 열기',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => HostBridge.openUrl(link),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(AppIcons.external, size: 16, color: AppColors.secondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
