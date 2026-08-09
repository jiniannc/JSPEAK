import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/search_history_datasource.dart';
import '../data/models/sentence.dart';
import 'providers.dart';

final searchHistoryDataSourceProvider = Provider<SearchHistoryDataSource>(
  (ref) => SearchHistoryDataSource(),
);

/// 추천·자주 찾는 검색어.
const kSuggestedSearchTags = [
  'boarding pass',
  'seat',
  'meal',
  'tax free',
  'emergency',
  'window seat',
  'baggage',
  'immigration',
];

class SearchState {
  final String query;
  final String languageFilter;
  final List<String> recentQueries;
  final bool historyLoading;

  const SearchState({
    this.query = '',
    this.languageFilter = 'All',
    this.recentQueries = const [],
    this.historyLoading = true,
  });

  SearchState copyWith({
    String? query,
    String? languageFilter,
    List<String>? recentQueries,
    bool? historyLoading,
  }) {
    return SearchState(
      query: query ?? this.query,
      languageFilter: languageFilter ?? this.languageFilter,
      recentQueries: recentQueries ?? this.recentQueries,
      historyLoading: historyLoading ?? this.historyLoading,
    );
  }
}

class SearchController extends Notifier<SearchState> {
  SearchHistoryDataSource get _history =>
      ref.read(searchHistoryDataSourceProvider);

  @override
  SearchState build() {
    _loadHistory();
    return const SearchState();
  }

  Future<void> _loadHistory() async {
    final recent = await _history.load();
    state = state.copyWith(recentQueries: recent, historyLoading: false);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setLanguageFilter(String filter) {
    state = state.copyWith(languageFilter: filter);
  }

  Future<void> submitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(query: trimmed);
    final recent = await _history.add(trimmed);
    state = state.copyWith(recentQueries: recent);
  }

  Future<void> removeRecent(String query) async {
    final recent = await _history.remove(query);
    state = state.copyWith(recentQueries: recent);
  }

  Future<void> clearRecent() async {
    await _history.clear();
    state = state.copyWith(recentQueries: []);
  }

  void applyTag(String tag) {
    submitSearch(tag);
  }
}

final searchProvider = NotifierProvider<SearchController, SearchState>(
  SearchController.new,
);

/// 검색 결과 (하이라이트용 원본 문장 목록).
final searchResultsProvider = Provider<List<Sentence>>((ref) {
  final search = ref.watch(searchProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null || search.query.trim().isEmpty) return <Sentence>[];

  return content.bundle.search(
    search.query,
    language: search.languageFilter,
  );
});
