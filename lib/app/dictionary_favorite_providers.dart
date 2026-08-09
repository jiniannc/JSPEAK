import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/dictionary_favorites_local_datasource.dart';
import '../data/datasources/local/favorite_sentences_local_datasource.dart';
import '../data/models/sentence.dart';
import '../data/models/vocabulary_entry.dart';
import '../features/shell/floating_island_nav_bar.dart';
import 'favorite_providers.dart';
import 'dictionary_providers.dart';
import 'providers.dart';

final dictionaryFavoritesLocalDataSourceProvider =
    Provider<DictionaryFavoritesLocalDataSource>(
  (ref) => DictionaryFavoritesLocalDataSource(),
);

/// 즐겨찾기 칩 표시용 항목.
sealed class DictionaryFavoriteItem {
  String get chipLabel;
  String get favoriteKey;
}

class DictionaryFavoriteWordItem extends DictionaryFavoriteItem {
  final VocabularyEntry entry;

  DictionaryFavoriteWordItem(this.entry);

  @override
  String get chipLabel => entry.term;

  @override
  String get favoriteKey => entry.storageFavoriteKey;
}

class DictionaryFavoriteSentenceItem extends DictionaryFavoriteItem {
  final Sentence sentence;

  DictionaryFavoriteSentenceItem(this.sentence);

  @override
  String get chipLabel =>
      sentence.korean.trim().isNotEmpty ? sentence.korean : sentence.sentence;

  @override
  String get favoriteKey => sentence.storageFavoriteKey;
}

extension VocabularyEntryFavorite on VocabularyEntry {
  String get storageFavoriteKey =>
      'w:$language|${term.trim().toLowerCase()}';
}

extension SentenceFavorite on Sentence {
  String get storageFavoriteKey => 's:$id';
}

class DictionaryFavoritesState {
  final List<String> orderedKeys;
  final bool loading;

  const DictionaryFavoritesState({
    this.orderedKeys = const [],
    this.loading = true,
  });

  Set<String> get keySet => orderedKeys.toSet();

  bool contains(String key) => keySet.contains(key);

  DictionaryFavoritesState copyWith({
    List<String>? orderedKeys,
    bool? loading,
  }) {
    return DictionaryFavoritesState(
      orderedKeys: orderedKeys ?? this.orderedKeys,
      loading: loading ?? this.loading,
    );
  }
}

class DictionaryFavoritesController extends AsyncNotifier<DictionaryFavoritesState> {
  DictionaryFavoritesLocalDataSource get _local =>
      ref.read(dictionaryFavoritesLocalDataSourceProvider);

  FavoriteSentencesLocalDataSource get _legacySentences =>
      ref.read(favoriteSentencesLocalDataSourceProvider);

  @override
  Future<DictionaryFavoritesState> build() async {
    final keys = await _local.load();
    return DictionaryFavoritesState(orderedKeys: keys, loading: false);
  }

  DictionaryFavoritesState get _resolved =>
      state.value ?? const DictionaryFavoritesState();

  Future<bool> toggleWord(VocabularyEntry entry) async {
    final key = entry.storageFavoriteKey;
    final wasFavorite = _resolved.contains(key);
    final keys = await _local.toggle(key);
    state = AsyncData(
      DictionaryFavoritesState(orderedKeys: keys, loading: false),
    );
    return !wasFavorite;
  }

  Future<bool> toggleSentence(Sentence sentence) async {
    final key = sentence.storageFavoriteKey;
    final wasFavorite = _resolved.contains(key);
    final keys = await _local.toggle(key);
    await _legacySentences.toggle(sentence.id);
    state = AsyncData(
      DictionaryFavoritesState(orderedKeys: keys, loading: false),
    );
    return !wasFavorite;
  }
}

final dictionaryFavoritesProvider =
    AsyncNotifierProvider<DictionaryFavoritesController, DictionaryFavoritesState>(
  DictionaryFavoritesController.new,
);

/// 로딩 중에는 빈 상태로 폴백 — UI `watch` 전용.
final dictionaryFavoritesResolvedProvider =
    Provider<DictionaryFavoritesState>((ref) {
  return ref.watch(dictionaryFavoritesProvider).value ??
      const DictionaryFavoritesState();
});

/// 현재 사전 언어 기준 즐겨찾기 (단어+문장, 최대 [limit]).
final dictionaryFavoritesForLanguageProvider =
    Provider.family<List<DictionaryFavoriteItem>, int>((ref, limit) {
  final fav = ref.watch(dictionaryFavoritesResolvedProvider);
  final language = ref.watch(selectedLanguageProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null || fav.orderedKeys.isEmpty) return const [];

  final sentencesById = {
    for (final s in content.bundle.sentences)
      if (s.language == language) s.storageFavoriteKey: s,
  };

  final wordsByKey = {
    for (final w in content.bundle.words)
      if (w.language == language && w.term.trim().isNotEmpty)
        w.storageFavoriteKey: w,
  };

  final out = <DictionaryFavoriteItem>[];
  for (final key in fav.orderedKeys) {
    if (key.startsWith('s:')) {
      final s = sentencesById[key];
      if (s != null) out.add(DictionaryFavoriteSentenceItem(s));
    } else if (key.startsWith('w:')) {
      final w = wordsByKey[key];
      if (w != null) out.add(DictionaryFavoriteWordItem(w));
    }
    if (out.length >= limit) break;
  }
  return out;
});

/// 현재 사전 언어 기준 즐겨찾기 전체 (보관함 모달용).
final dictionaryFavoritesAllForLanguageProvider =
    Provider<List<DictionaryFavoriteItem>>((ref) {
  return ref.watch(dictionaryFavoritesForLanguageProvider(10000));
});

void showDictionaryFavoriteSnackBar(
  BuildContext context, {
  required bool added,
}) {
  if (!context.mounted) return;
  final bottom = FloatingIslandNavBar.reservedHeight(context) + 8;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xE6142233),
      duration: const Duration(milliseconds: 1800),
      content: Row(
        children: [
          Icon(
            added ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: added ? const Color(0xFFFFC107) : Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            added ? '즐겨찾기에 저장되었습니다' : '즐겨찾기에서 해제되었습니다',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
