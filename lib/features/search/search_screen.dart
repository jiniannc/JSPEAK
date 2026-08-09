import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_providers.dart';
import '../../app/providers.dart';
import '../../app/search_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../core/widgets/active5_app_bar.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/sentence.dart';
import '../dictionary/widgets/dictionary_glass_search_result_card.dart';

/// 고도화된 검색 화면 (하이라이트 · 최근 검색 · 추천 태그).
/// StatefulShell 내부 라우트로 하단 탭이 유지된다.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(searchProvider).query;
    _controller = TextEditingController(text: initialQuery);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(searchProvider.notifier).setQuery(value);
  }

  void _submit(String value) {
    ref.read(searchProvider.notifier).submitSearch(value);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final results = ref.watch(searchResultsProvider);
    final language = ref.watch(selectedLanguageProvider);
    final palette = LanguagePalette.forLanguage(language);
    final metrics = Active5Layout.of(context);
    final contentAsync = ref.watch(contentProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: palette.toColorScheme(),
        extensions: [palette],
      ),
      child: DeviceScaffold(
        appBar: active5AppBar(
          context: context,
          leading: Active5IconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '뒤로',
            onPressed: () => context.go('/dictionary'),
          ),
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '문장·발음·한국어 검색…',
              border: InputBorder.none,
              hintStyle: TextStyle(color: palette.tabUnselected),
            ),
            onChanged: _onQueryChanged,
            onSubmitted: _submit,
          ),
          actions: [
            if (search.query.isNotEmpty)
              Active5IconButton(
                icon: Icons.clear_rounded,
                tooltip: '지우기',
                onPressed: () {
                  _controller.clear();
                  _onQueryChanged('');
                },
              ),
          ],
        ),
        body: contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (_) {
            final hasQuery = search.query.trim().isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LanguageFilterRow(
                  selected: search.languageFilter,
                  palette: palette,
                  onSelected: ref.read(searchProvider.notifier).setLanguageFilter,
                ),
                if (!hasQuery) ...[
                  _SuggestedTagsSection(
                    tags: kSuggestedSearchTags,
                    palette: palette,
                    padding: metrics.pagePadding,
                    onTagTap: (tag) {
                      _controller.text = tag;
                      _submit(tag);
                    },
                  ),
                  if (!search.historyLoading && search.recentQueries.isNotEmpty)
                    _RecentSearchesSection(
                      queries: search.recentQueries,
                      palette: palette,
                      padding: metrics.pagePadding,
                      onTap: (q) {
                        _controller.text = q;
                        _submit(q);
                      },
                      onRemove: ref.read(searchProvider.notifier).removeRecent,
                      onClear: ref.read(searchProvider.notifier).clearRecent,
                    ),
                ],
                Expanded(
                  child: hasQuery
                      ? _SearchResultsList(
                          results: results,
                          query: search.query,
                          padding: metrics.pagePadding,
                        )
                      : _SearchIdleHint(palette: palette),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanguageFilterRow extends StatelessWidget {
  final String selected;
  final LanguagePalette palette;
  final ValueChanged<String> onSelected;

  const _LanguageFilterRow({
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final entry in {'All': '전체', ...languageLabels}.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                selectedColor: palette.tabSelected.withValues(alpha: 0.2),
                checkmarkColor: palette.accent,
                labelStyle: TextStyle(
                  color: selected == entry.key
                      ? palette.accent
                      : palette.tabUnselected,
                  fontWeight: selected == entry.key
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected == entry.key
                      ? palette.accent
                      : palette.tabUnselected.withValues(alpha: 0.4),
                ),
                onSelected: (_) => onSelected(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestedTagsSection extends StatelessWidget {
  final List<String> tags;
  final LanguagePalette palette;
  final EdgeInsets padding;
  final ValueChanged<String> onTagTap;

  const _SuggestedTagsSection({
    required this.tags,
    required this.palette,
    required this.padding,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding.copyWith(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자주 찾는 태그',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                ActionChip(
                  avatar: Icon(
                    Icons.local_offer_outlined,
                    size: 16,
                    color: palette.primary,
                  ),
                  label: Text(tag),
                  backgroundColor: palette.chipBackground,
                  side: BorderSide(color: palette.accent.withValues(alpha: 0.2)),
                  onPressed: () => onTagTap(tag),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSearchesSection extends StatelessWidget {
  final List<String> queries;
  final LanguagePalette palette;
  final EdgeInsets padding;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const _RecentSearchesSection({
    required this.queries,
    required this.palette,
    required this.padding,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding.copyWith(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '최근 검색어',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClear,
                child: Text('전체 삭제', style: TextStyle(color: palette.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...queries.map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded, color: palette.primary),
              title: Text(q),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: '삭제',
                onPressed: () => onRemove(q),
              ),
              onTap: () => onTap(q),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchIdleHint extends StatelessWidget {
  final LanguagePalette palette;

  const _SearchIdleHint({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: palette.tabUnselected),
          const SizedBox(height: 12),
          Text(
            '검색어를 입력하거나 태그를 선택하세요.',
            style: TextStyle(color: palette.tabUnselected),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final List<Sentence> results;
  final String query;
  final EdgeInsets padding;

  const _SearchResultsList({
    required this.results,
    required this.query,
    required this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    final palette = context.languagePalette;
    final accent = palette?.accent ?? Theme.of(context).colorScheme.primary;

    return ListView.builder(
      padding: padding.copyWith(top: 4),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final sentence = results[index];

        return DictionaryGlassSearchResultCard(
          sentence: sentence,
          query: query,
          accent: accent,
        );
      },
    );
  }
}
