import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_favorite_providers.dart';
import 'dictionary_providers.dart';
import 'providers.dart';
import 'sentence_progress_providers.dart';

/// 현재 언어 기준 사전 즐겨찾기(단어+문장) 개수.
final dictionaryFavoriteCountProvider = Provider<int>((ref) {
  final fav = ref.watch(dictionaryFavoritesResolvedProvider);
  final language = ref.watch(selectedLanguageProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null || fav.orderedKeys.isEmpty) return 0;

  final sentenceKeys = {
    for (final s in content.bundle.sentences)
      if (s.language == language) s.storageFavoriteKey,
  };
  final wordKeys = {
    for (final w in content.bundle.words)
      if (w.language == language && w.term.trim().isNotEmpty)
        w.storageFavoriteKey,
  };

  var count = 0;
  for (final key in fav.orderedKeys) {
    if (sentenceKeys.contains(key) || wordKeys.contains(key)) {
      count++;
    }
  }
  return count;
});

/// 시도했지만 아직 마스터하지 못한 문장 수 (복습 필요).
final reviewNeededSentenceCountProvider = Provider<int>((ref) {
  final stats = ref.watch(sentenceProgressProvider).stats;
  var count = 0;
  for (final progress in stats.bySentenceId.values) {
    if (progress.isAttempted && !progress.isMastered) {
      count++;
    }
  }
  return count;
});
