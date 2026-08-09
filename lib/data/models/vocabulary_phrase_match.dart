import '../../data/models/vocabulary_entry.dart';

/// 문장에서 매칭된 복합어/단어 구간.
class VocabularyPhraseMatch {
  final int startIndex;
  final int endIndex;
  final VocabularyEntry entry;

  const VocabularyPhraseMatch({
    required this.startIndex,
    required this.endIndex,
    required this.entry,
  });

  bool contains(int index) => index >= startIndex && index <= endIndex;

  int get length => endIndex - startIndex + 1;
}
