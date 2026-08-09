import 'cjk_stt_segments.dart';
import 'pronunciation_text_tokenizer.dart';
import 'scenario_answer_compare.dart';
import 'word_compare.dart';

enum WordAlignmentKind { match, substitution, insertion, deletion }

class WordAlignmentOp {
  final WordAlignmentKind kind;
  final String? targetWord;
  final String? spokenWord;

  const WordAlignmentOp({
    required this.kind,
    this.targetWord,
    this.spokenWord,
  });
}

class WordTokenAlignment {
  final List<WordAlignmentOp> ops;

  const WordTokenAlignment(this.ops);

  int get matchedTargetCount =>
      ops.where((op) => op.kind == WordAlignmentKind.match).length;

  int accuracyPercent(int targetWordCount) {
    if (targetWordCount <= 0) return 0;
    return ((matchedTargetCount / targetWordCount) * 100).round().clamp(0, 100);
  }
}

class _IndexPair {
  final int targetIndex;
  final int spokenIndex;

  const _IndexPair(this.targetIndex, this.spokenIndex);
}

/// Target·Spoken 단어 시퀀스를 LCS + 구간 Levenshtein으로 정렬한다.
class WordTokenAligner {
  WordTokenAligner._();

  static WordTokenAlignment align({
    required List<String> targetWords,
    required List<String> spokenWords,
    String language = 'English',
  }) {
    if (targetWords.isEmpty && spokenWords.isEmpty) {
      return const WordTokenAlignment([]);
    }

    final lcsPairs = _lcsMatchPairs(targetWords, spokenWords, language);
    final ops = <WordAlignmentOp>[];
    var targetCursor = 0;
    var spokenCursor = 0;

    for (final pair in lcsPairs) {
      ops.addAll(
        _alignGap(
          targetWords: targetWords,
          spokenWords: spokenWords,
          targetStart: targetCursor,
          targetEnd: pair.targetIndex,
          spokenStart: spokenCursor,
          spokenEnd: pair.spokenIndex,
          language: language,
        ),
      );
      ops.add(
        WordAlignmentOp(
          kind: WordAlignmentKind.match,
          targetWord: targetWords[pair.targetIndex],
          spokenWord: spokenWords[pair.spokenIndex],
        ),
      );
      targetCursor = pair.targetIndex + 1;
      spokenCursor = pair.spokenIndex + 1;
    }

    ops.addAll(
      _alignGap(
        targetWords: targetWords,
        spokenWords: spokenWords,
        targetStart: targetCursor,
        targetEnd: targetWords.length,
        spokenStart: spokenCursor,
        spokenEnd: spokenWords.length,
        language: language,
      ),
    );

    return WordTokenAlignment(ops);
  }

  static WordTokenAlignment alignText({
    required String targetText,
    required String spokenText,
    String language = 'English',
  }) {
    final targetHasSlash =
        PronunciationTextTokenizer.hasSlashSegments(targetText);
    final spokenPrepared = PronunciationTextTokenizer.prepareSpokenForCompare(
      spokenText,
      language,
    );
    final spokenHasSlash =
        PronunciationTextTokenizer.hasSlashSegments(spokenPrepared);

    if (targetHasSlash && spokenHasSlash) {
      return _alignSlashSegmentsOneToOne(
        targetText: targetText,
        spokenText: spokenPrepared,
        language: language,
      );
    }

    if (targetHasSlash) {
      final targetWords = PronunciationTextTokenizer.splitSlashSegments(
        targetText,
      ).expand(
        (segment) => PronunciationTextTokenizer.tokenizeSegment(
          segment,
          language: language,
        ),
      );
      final spokenWords = PronunciationTextTokenizer.tokenizeForCompare(
        spokenText,
        language: language,
        isSpoken: true,
      );
      return align(
        targetWords: targetWords.toList(),
        spokenWords: spokenWords,
        language: language,
      );
    }

    return align(
      targetWords: PronunciationTextTokenizer.tokenizeForCompare(
        targetText,
        language: language,
        isSpoken: false,
      ),
      spokenWords: PronunciationTextTokenizer.tokenizeForCompare(
        spokenText,
        language: language,
        isSpoken: true,
      ),
      language: language,
    );
  }

  static WordTokenAlignment _alignSlashSegmentsOneToOne({
    required String targetText,
    required String spokenText,
    required String language,
  }) {
    final targetSegments =
        PronunciationTextTokenizer.splitSlashSegments(targetText);
    final spokenSegments =
        PronunciationTextTokenizer.splitSlashSegments(spokenText);
    final maxLen = targetSegments.length > spokenSegments.length
        ? targetSegments.length
        : spokenSegments.length;
    final ops = <WordAlignmentOp>[];

    for (var i = 0; i < maxLen; i++) {
      if (i >= targetSegments.length) {
        final spokenWords = PronunciationTextTokenizer.tokenizeSegment(
          spokenSegments[i],
          language: language,
        );
        ops.addAll([
          for (final spoken in spokenWords)
            WordAlignmentOp(
              kind: WordAlignmentKind.insertion,
              spokenWord: spoken,
            ),
        ]);
        continue;
      }
      if (i >= spokenSegments.length) {
        final targetWords = PronunciationTextTokenizer.tokenizeSegment(
          targetSegments[i],
          language: language,
        );
        ops.addAll([
          for (final target in targetWords)
            WordAlignmentOp(
              kind: WordAlignmentKind.deletion,
              targetWord: target,
            ),
        ]);
        continue;
      }

      ops.addAll(
        align(
          targetWords: PronunciationTextTokenizer.tokenizeSegment(
            targetSegments[i],
            language: language,
          ),
          spokenWords: PronunciationTextTokenizer.tokenizeSegment(
            spokenSegments[i],
            language: language,
          ),
          language: language,
        ).ops,
      );
    }

    return WordTokenAlignment(ops);
  }

  static int accuracyPercent({
    required String targetText,
    required String spokenText,
    String language = 'English',
  }) {
    final targetWords = PronunciationTextTokenizer.tokenizeForCompare(
      targetText,
      language: language,
      isSpoken: false,
    );
    if (targetWords.isEmpty) {
      return PronunciationTextTokenizer.tokenizeForCompare(
        spokenText,
        language: language,
        isSpoken: true,
      ).isEmpty
          ? 100
          : 0;
    }
    final spokenWords = PronunciationTextTokenizer.tokenizeForCompare(
      spokenText,
      language: language,
      isSpoken: true,
    );
    if (spokenWords.isEmpty) return 0;
    return align(
      targetWords: targetWords,
      spokenWords: spokenWords,
      language: language,
    ).accuracyPercent(targetWords.length);
  }

  static bool _tokensEquivalent(String a, String b, String language) {
    if (CjkSttSegments.isTargetLanguage(language)) {
      if (ScenarioAnswerCompare.charsEquivalentForCompare(a, b, language)) {
        return true;
      }
      final na = ScenarioAnswerCompare.normalize(a, language: language);
      final nb = ScenarioAnswerCompare.normalize(b, language: language);
      if (na.isEmpty || nb.isEmpty) return na == nb;
      if (na == nb) return true;
      // 구두점·어미 차이만 있는 구문 (確認しております。 vs 確認しております)
      if (na.contains(nb) || nb.contains(na)) {
        final shorter = na.length < nb.length ? na.length : nb.length;
        final longer = na.length > nb.length ? na.length : nb.length;
        return shorter / longer >= 0.88;
      }
      return false;
    }
    return WordCompare.normalize(a) == WordCompare.normalize(b);
  }

  static List<_IndexPair> _lcsMatchPairs(
    List<String> targetWords,
    List<String> spokenWords,
    String language,
  ) {
    final n = targetWords.length;
    final m = spokenWords.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (_tokensEquivalent(
          targetWords[i - 1],
          spokenWords[j - 1],
          language,
        )) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1]
              ? dp[i - 1][j]
              : dp[i][j - 1];
        }
      }
    }

    final pairs = <_IndexPair>[];
    var i = n;
    var j = m;
    while (i > 0 && j > 0) {
      if (_tokensEquivalent(
        targetWords[i - 1],
        spokenWords[j - 1],
        language,
      )) {
        pairs.add(_IndexPair(i - 1, j - 1));
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return pairs.reversed.toList();
  }

  static List<WordAlignmentOp> _alignGap({
    required List<String> targetWords,
    required List<String> spokenWords,
    required int targetStart,
    required int targetEnd,
    required int spokenStart,
    required int spokenEnd,
    String language = 'English',
  }) {
    final targetSlice = targetWords.sublist(targetStart, targetEnd);
    final spokenSlice = spokenWords.sublist(spokenStart, spokenEnd);
    if (targetSlice.isEmpty && spokenSlice.isEmpty) {
      return const [];
    }
    if (targetSlice.length == 1 &&
        spokenSlice.length == 1 &&
        !_tokensEquivalent(targetSlice.first, spokenSlice.first, language)) {
      return [
        WordAlignmentOp(
          kind: WordAlignmentKind.substitution,
          targetWord: targetSlice.first,
          spokenWord: spokenSlice.first,
        ),
      ];
    }

    return _levenshteinAlign(
      targetSlice,
      spokenSlice,
      language: language,
      substitutionCost: 2,
    );
  }

  static List<WordAlignmentOp> _levenshteinAlign(
    List<String> targetWords,
    List<String> spokenWords, {
    String language = 'English',
    int substitutionCost = 1,
  }) {
    final n = targetWords.length;
    final m = spokenWords.length;

    if (n == 0) {
      return [
        for (final spoken in spokenWords)
          WordAlignmentOp(
            kind: WordAlignmentKind.insertion,
            spokenWord: spoken,
          ),
      ];
    }
    if (m == 0) {
      return [
        for (final target in targetWords)
          WordAlignmentOp(
            kind: WordAlignmentKind.deletion,
            targetWord: target,
          ),
      ];
    }

    final cost = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    final dir = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 1; i <= n; i++) {
      cost[i][0] = i;
      dir[i][0] = 1;
    }
    for (var j = 1; j <= m; j++) {
      cost[0][j] = j;
      dir[0][j] = 2;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final isMatch = _tokensEquivalent(
          targetWords[i - 1],
          spokenWords[j - 1],
          language,
        );
        final diag =
            cost[i - 1][j - 1] + (isMatch ? 0 : substitutionCost);
        final up = cost[i - 1][j] + 1;
        final left = cost[i][j - 1] + 1;
        final minCost = [diag, up, left].reduce((a, b) => a < b ? a : b);

        // 동점일 때 삭제 → 추가 → 치환 순으로 diff 가독성 우선.
        if (up == minCost) {
          cost[i][j] = up;
          dir[i][j] = 1;
        } else if (left == minCost) {
          cost[i][j] = left;
          dir[i][j] = 2;
        } else {
          cost[i][j] = diag;
          dir[i][j] = 0;
        }
      }
    }

    final ops = <WordAlignmentOp>[];
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && dir[i][j] == 0) {
        final target = targetWords[i - 1];
        final spoken = spokenWords[j - 1];
        final isMatch =
            _tokensEquivalent(target, spoken, language);
        ops.add(
          WordAlignmentOp(
            kind: isMatch
                ? WordAlignmentKind.match
                : WordAlignmentKind.substitution,
            targetWord: target,
            spokenWord: spoken,
          ),
        );
        i--;
        j--;
      } else if (i > 0 && (j == 0 || dir[i][j] == 1)) {
        ops.add(
          WordAlignmentOp(
            kind: WordAlignmentKind.deletion,
            targetWord: targetWords[i - 1],
          ),
        );
        i--;
      } else {
        ops.add(
          WordAlignmentOp(
            kind: WordAlignmentKind.insertion,
            spokenWord: spokenWords[j - 1],
          ),
        );
        j--;
      }
    }

    return ops.reversed.toList();
  }
}
