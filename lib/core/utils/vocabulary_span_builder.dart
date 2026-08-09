import '../../data/models/vocabulary_entry.dart';
import '../../data/models/vocabulary_phrase_match.dart';
import 'word_compare.dart';
import 'word_match.dart';

/// 시트 단어를 문장에 매칭해 [TextSpan]으로 변환하는 공통 로직.
class VocabularySpanBuilder {
  VocabularySpanBuilder._();

  static const _maxPhraseWords = 6;

  /// 긴 구문 우선·겹침 없이 문장에서 사전 항목을 찾는다.
  static List<VocabularyPhraseMatch> findPhraseMatches(
    String sentence,
    List<VocabularyEntry> entries,
  ) {
    final words = WordCompare.splitWords(sentence);
    if (words.isEmpty || entries.isEmpty) return [];

    final sorted = [...entries]
      ..sort((a, b) {
        final aLen = WordCompare.splitWords(a.term).length;
        final bLen = WordCompare.splitWords(b.term).length;
        return bLen.compareTo(aLen);
      });

    final matches = <VocabularyPhraseMatch>[];
    final occupied = <int>{};

    for (final entry in sorted) {
      final termWords = WordCompare.splitWords(entry.term);
      final len = termWords.length;
      if (len == 0 || len > _maxPhraseWords) continue;

      for (var start = 0; start <= words.length - len; start++) {
        final range = List.generate(len, (i) => start + i);
        if (range.any(occupied.contains)) continue;

        var ok = true;
        for (var j = 0; j < len; j++) {
          if (!WordMatch.flexibleMatch(words[start + j], termWords[j])) {
            ok = false;
            break;
          }
        }

        if (ok) {
          matches.add(
            VocabularyPhraseMatch(
              startIndex: start,
              endIndex: start + len - 1,
              entry: entry,
            ),
          );
          occupied.addAll(range);
        }
      }
    }

    matches.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return matches;
  }

  static Map<int, VocabularyPhraseMatch> indexMap(
    List<VocabularyPhraseMatch> matches,
  ) {
    final map = <int, VocabularyPhraseMatch>{};
    for (final match in matches) {
      for (var i = match.startIndex; i <= match.endIndex; i++) {
        map[i] = match;
      }
    }
    return map;
  }

  /// [tapIndex]가 속한 구간의 시작 인덱스 (팝업 위치 계산용).
  static int phraseStartIndex(
    List<VocabularyPhraseMatch> matches,
    int tapIndex,
  ) {
    for (final match in matches) {
      if (match.contains(tapIndex)) return match.startIndex;
    }
    return tapIndex;
  }

  /// [tappedIndex]가 속한 사전 항목 (유연 매칭).
  static VocabularyEntry? lookupAt(
    VocabularyIndex index,
    List<String> words,
    int tappedIndex,
  ) {
    if (tappedIndex < 0 || tappedIndex >= words.length) return null;

    final sentence = words.join(' ');
    for (final match in findPhraseMatches(sentence, index.entries)) {
      if (match.contains(tappedIndex)) return match.entry;
    }
    return null;
  }
}
