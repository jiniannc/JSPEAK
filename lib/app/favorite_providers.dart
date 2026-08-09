import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/favorite_sentences_local_datasource.dart';
import '../data/models/sentence.dart';
import 'dictionary_providers.dart';
import 'providers.dart';

final favoriteSentencesLocalDataSourceProvider =
    Provider<FavoriteSentencesLocalDataSource>(
  (ref) => FavoriteSentencesLocalDataSource(),
);

class FavoriteSentencesState {
  final List<String> orderedIds;
  final bool loading;

  const FavoriteSentencesState({
    this.orderedIds = const [],
    this.loading = true,
  });

  Set<String> get idSet => orderedIds.toSet();

  bool contains(String id) => idSet.contains(id);

  FavoriteSentencesState copyWith({
    List<String>? orderedIds,
    bool? loading,
  }) {
    return FavoriteSentencesState(
      orderedIds: orderedIds ?? this.orderedIds,
      loading: loading ?? this.loading,
    );
  }
}

class FavoriteSentencesController extends Notifier<FavoriteSentencesState> {
  FavoriteSentencesLocalDataSource get _local =>
      ref.read(favoriteSentencesLocalDataSourceProvider);

  @override
  FavoriteSentencesState build() {
    Future.microtask(_load);
    return const FavoriteSentencesState();
  }

  Future<void> _load() async {
    final ids = await _local.load();
    state = FavoriteSentencesState(orderedIds: ids, loading: false);
  }

  Future<void> toggle(String sentenceId) async {
    final ids = await _local.toggle(sentenceId);
    state = FavoriteSentencesState(orderedIds: ids, loading: false);
  }
}

final favoriteSentencesProvider =
    NotifierProvider<FavoriteSentencesController, FavoriteSentencesState>(
  FavoriteSentencesController.new,
);

/// 현재 사전 언어 기준 즐겨찾기 문장 (최대 [limit]).
final favoriteSentencesForLanguageProvider =
    Provider.family<List<Sentence>, int>((ref, limit) {
  final fav = ref.watch(favoriteSentencesProvider);
  final language = ref.watch(selectedLanguageProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null || fav.orderedIds.isEmpty) return const [];

  final byId = {
    for (final s in content.bundle.sentences)
      if (s.language == language) s.id: s,
  };

  final out = <Sentence>[];
  for (final id in fav.orderedIds) {
    final s = byId[id];
    if (s != null) {
      out.add(s);
      if (out.length >= limit) break;
    }
  }
  return out;
});
