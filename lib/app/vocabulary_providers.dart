import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/vocabulary_span_builder.dart';
import '../core/utils/word_compare.dart';
import '../data/models/vocabulary_entry.dart';
import 'providers.dart';

/// Words 시트 데이터(content bundle) 기반 단어 인덱스.
final vocabularyProvider = Provider<VocabularyIndex?>((ref) {
  final content = ref.watch(contentProvider).value;
  if (content == null || content.bundle.words.isEmpty) return null;
  return VocabularyIndex.fromEntries(content.bundle.words);
});

/// 문장 내 단어 탭 시 사전 조회.
VocabularyEntry? lookupWordInSentence({
  required VocabularyIndex? index,
  required String sentence,
  required int wordIndex,
}) {
  if (index == null || index.isEmpty) return null;
  final words = WordCompare.splitWords(sentence);
  return VocabularySpanBuilder.lookupAt(index, words, wordIndex);
}
