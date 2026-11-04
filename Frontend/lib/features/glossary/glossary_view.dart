import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/lecture_models.dart';
import '../../shared/ui.dart';
import 'glossary_controller.dart';

/// 용어집 조회 하위 탭: 검색 + 강의 중 자동 추출된 용어 + 추가 설명 요청
class GlossaryView extends ConsumerStatefulWidget {
  const GlossaryView({super.key});

  @override
  ConsumerState<GlossaryView> createState() => _GlossaryViewState();
}

class _GlossaryViewState extends ConsumerState<GlossaryView> {
  final _term = TextEditingController();
  bool _showDetail = false;

  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  void _search() {
    setState(() => _showDetail = false);
    ref.read(termDetailProvider.notifier).clear();
    ref.read(glossarySearchProvider.notifier).search(_term.text);
  }

  void _showEntry(GlossaryEntry entry) {
    _term.text = entry.term;
    setState(() => _showDetail = false);
    ref.read(termDetailProvider.notifier).clear();
    ref.read(glossarySearchProvider.notifier).show(entry);
  }

  void _toggleDetail(String? term) {
    final next = !_showDetail;
    setState(() => _showDetail = next);
    final detail = ref.read(termDetailProvider);
    if (next && term != null && (detail.term != term || detail.status == LoadStatus.error)) {
      ref.read(termDetailProvider.notifier).request(term);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(glossarySearchProvider);
    final terms = ref.watch(lectureTermsProvider);
    final detail = ref.watch(termDetailProvider);
    final selectedTerm = search.status == LoadStatus.done && search.results.isNotEmpty ? search.results.first.term : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('용어집 조회', style: em(1.1, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _term,
                  maxLength: 50,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: em(0.97),
                  decoration: fieldDecoration(hint: '조회할 용어를 입력하세요.'),
                ),
              ),
            ),
            const SizedBox(width: 7),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _search,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(AppIcons.search, size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ..._results(search),
        const SizedBox(height: 10),
        ActionButton(
          style: ActionStyle.outline,
          label: '추가 설명 요청',
          onTap: () => _toggleDetail(selectedTerm),
        ),
        if (_showDetail) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(color: AppColors.sageSoft, borderRadius: BorderRadius.circular(10)),
            child: selectedTerm == null
                ? Text('검색할 용어를 입력하면 관련 설명을 요청할 수 있습니다.', style: em(0.91, height: 1.6))
                : switch (detail.status) {
                    LoadStatus.loading || LoadStatus.idle => Row(children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sage)),
                        const SizedBox(width: 8),
                        Expanded(child: Text("'$selectedTerm'을(를) 강의 내용과 연결해 설명하는 중…", style: em(0.91, color: AppColors.secondary))),
                      ]),
                    LoadStatus.error => InlineNote(detail.text ?? '설명을 받지 못했습니다.', error: true),
                    LoadStatus.done => Text(detail.text ?? '', style: em(0.91, height: 1.6)),
                  },
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Text('강의에서 나온 용어', style: em(0.95, weight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('${terms.length}', style: em(0.86, weight: FontWeight.w700, color: AppColors.sageDark)),
          ],
        ),
        const SizedBox(height: 8),
        if (terms.isEmpty)
          const InlineNote('강의가 진행되면 어려운 전공 용어가 1분마다 자동으로 추가됩니다.')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in terms.take(30)) TagChip(t.term, onTap: () => _showEntry(t))],
          ),
      ],
    );
  }

  List<Widget> _results(GlossarySearchState search) {
    Widget card({required String title, required String description, required String source, String? english}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          radius: 14,
          minHeight: 143,
          padding: const EdgeInsets.fromLTRB(13, 15, 13, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: em(1.0, weight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(description, style: em(0.91, color: AppColors.description, height: 1.65)),
              if (english != null) ...[
                const SizedBox(height: 6),
                Text(english, style: em(0.83, color: AppColors.muted, height: 1.5).copyWith(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 17),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Text(source, style: em(0.83, color: AppColors.muted)),
            ],
          ),
        ),
      );
    }

    switch (search.status) {
      case LoadStatus.idle:
        return [card(title: '용어 설명', description: '조회한 용어의 핵심 설명과 요약이 표시됩니다.', source: '출처 · 관련 정보')];
      case LoadStatus.loading:
        return [
          card(
            title: search.query,
            description: '용어집에서 찾는 중입니다. 강의 용어집에 없으면 AI가 설명을 만듭니다 (5~15초).',
            source: '출처 · 확인 중',
          )
        ];
      case LoadStatus.error:
        return [card(title: '조회 실패', description: search.error ?? '다시 시도해 주세요.', source: '출처 · 강의 용어집')];
      case LoadStatus.done:
        if (search.results.isEmpty) {
          return [
            card(
              title: '조회 결과 없음',
              description: '강의 용어집에서 “${search.query}”에 해당하는 항목을 찾지 못했습니다.',
              source: '출처 · 강의 용어집',
            )
          ];
        }
        return [
          for (final e in search.results.take(5))
            card(
              title: e.term,
              description: e.definition,
              english: e.isAiGenerated ? e.definitionEn : null,
              source: e.isAiGenerated ? '출처 · AI 생성 설명 (강의 용어집에 없는 용어)' : '출처 · 강의 용어집 (강의 중 자동 추출)',
            ),
        ];
    }
  }
}
