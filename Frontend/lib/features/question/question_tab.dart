import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/ui.dart';
import '../glossary/glossary_view.dart';
import '../overlay/widget_state.dart';
import 'ask_view.dart';

/// 질문 탭: 익명 질문 / 용어집 조회 (디자인의 .subnav)
/// 하위 화면은 Offstage로 유지해서 입력 중이던 글자가 탭을 옮겨도 사라지지 않는다.
/// 질문 입력창과 용어 검색창은 각자 다른 컨트롤러를 쓴다 (예전에는 하나를 같이 써서 글자가 섞였다).
class QuestionTab extends ConsumerWidget {
  const QuestionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(questionSubTabProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EqualRow(
          gap: 10,
          children: [
            for (final (i, label) in const [(0, '익명 질문'), (1, '용어집 조회')])
              ChoiceButton(
                label: label,
                selected: sub == i,
                height: 44,
                fontEm: 1,
                color: AppColors.subtab,
                onTap: () => ref.read(questionSubTabProvider.notifier).state = i,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Offstage(offstage: sub != 0, child: TickerMode(enabled: sub == 0, child: const AskView())),
        Offstage(offstage: sub != 1, child: TickerMode(enabled: sub == 1, child: const GlossaryView())),
      ],
    );
  }
}
