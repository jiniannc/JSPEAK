import 'answer_blank_hints.dart';
import 'cjk_stt_segments.dart';
import 'japanese_number_normalizer.dart';
import 'japanese_reading_fold.dart';
import 'japanese_stt_fix_map.dart';
import 'english_pronunciation_tokens.dart';
import 'word_compare.dart';

/// 시나리오 STT 답안 정오 판별·유사도·글자 정렬.
class ScenarioAnswerCompare {
  ScenarioAnswerCompare._();

  static final RegExp _punctuation =
      RegExp(r'[.,!?;:"()\[\]]');
  static final RegExp _cjkPunctuation =
      RegExp(r'[。、？！…]');

  /// 일본어 한자↔히라가나 등가 표현 (긴 구문 우선 적용).
  static const List<(String from, String to)> _jpReadingVariants = [
    ('致します', 'いたします'),
    ('致し', 'いたし'),
    ('致す', 'いたす'),
    ('御座います', 'ございます'),
    ('下さい', 'ください'),
    ('頂き', 'いただき'),
    ('頂く', 'いただく'),
    ('有り難う', 'ありがとう'),
    ('有難う', 'ありがとう'),
    ('御願い', 'お願い'),
    ('致', 'いた'),
  ];

  /// 비교용 정규화.
  static String normalize(String text, {String? language}) {
    var result = _toHalfWidth(text.trim().toLowerCase());
    result = result.replaceAll(_punctuation, '');
    result = result.replaceAll(_cjkPunctuation, '');
    if (language == 'Japanese') {
      result = _applyJapaneseReadingVariants(result);
    }
    if (language == 'Japanese' || language == 'Chinese') {
      result = result.replaceAll(RegExp(r'\s+'), '');
    }
    return result;
  }

  static String _toHalfWidth(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      if (code >= 0xFF01 && code <= 0xFF5E) {
        buffer.writeCharCode(code - 0xFEE0);
      } else if (code == 0x3000) {
        buffer.write(' ');
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  static String _applyJapaneseReadingVariants(String text) {
    var result = text;
    for (final pair in _jpReadingVariants) {
      result = result.replaceAll(pair.$1, pair.$2);
    }
    return result;
  }

  /// STT spoken 전처리 — 일본어는 [JapaneseSttFixMap] 보정 후 비교.
  static String preprocessSpoken(String spoken, {required String language}) {
    if (language != 'Japanese') return spoken;
    return JapaneseSttFixMap.apply(spoken);
  }

  static String _spokenForCompare(
    String spoken,
    String language, {
    String? correct,
  }) {
    var preprocessed = preprocessSpoken(spoken, language: language);
    if (language == 'Japanese') {
      preprocessed = JapaneseNumberNormalizer.expandDigitsInText(preprocessed);
    }
    final extracted = CjkSttSegments.extractTargetScript(
      preprocessed,
      language,
      referenceText: correct,
    );
    if (language == 'Japanese' &&
        correct != null &&
        correct.trim().isNotEmpty) {
      final targetExpanded = JapaneseNumberNormalizer.expandDigitsInText(correct);
      final targetScript = CjkSttSegments.extractTargetScript(
        targetExpanded,
        language,
        referenceText: correct,
      );
      return JapaneseReadingFold.fold(extracted, targetScript);
    }
    return extracted;
  }

  static bool _charsEquivalent(String a, String b, String? language) {
    final na = normalize(a, language: language);
    final nb = normalize(b, language: language);
    if (na.isEmpty || nb.isEmpty) return na == nb;
    return na == nb;
  }

  /// [AnswerBlankHints] 등 외부에서 글자 동치 비교 시 사용.
  static bool charsEquivalentForCompare(String a, String b, String language) =>
      _charsEquivalent(a, b, language);

  /// STT/타이핑 결과가 정답과 일치하는지 판별.
  static bool isCorrect({
    required String spoken,
    required String correct,
    required String language,
    String blankFrame = '',
    bool keyWordsOnly = false,
  }) {
    if (keyWordsOnly && blankFrame.trim().isNotEmpty) {
      return _keyWordsMatch(
        spoken: spoken,
        correct: correct,
        blankFrame: blankFrame,
        language: language,
      );
    }

    final adjustedSpoken = _spokenForCompare(spoken, language, correct: correct);
    final normSpoken = normalize(adjustedSpoken, language: language);
    final normCorrect = normalize(correct, language: language);
    if (normSpoken.isEmpty || normCorrect.isEmpty) return false;
    if (normSpoken == normCorrect) return true;

    if (language == 'English') {
      return _englishWordMatch(spoken, correct);
    }
    return _cjkFuzzyMatch(normSpoken, normCorrect);
  }

  /// 정답 대비 일치율 (0~100). 앞부분 오인식이 있어도 뒤쪽 일치분은 누적 반영.
  static int similarityPercent({
    required String spoken,
    required String correct,
    required String language,
  }) {
    if (spoken.trim().isEmpty || correct.trim().isEmpty) return 0;

    if (language == 'English') {
      final flags = _englishWordFlags(correct, spoken);
      if (flags.isEmpty) return 0;
      final matched = flags.where((f) => f).length;
      return ((matched / flags.length) * 100).round();
    }

    final flags = wordMatchFlags(
      correct: correct,
      spoken: spoken,
      language: language,
    );
    final chars = correct.split('');
    var total = 0;
    var matched = 0;
    for (var i = 0; i < chars.length; i++) {
      if (normalize(chars[i], language: language).isEmpty) continue;
      total++;
      if (i < flags.length && flags[i]) matched++;
    }
    return total == 0 ? 0 : ((matched / total) * 100).round();
  }

  /// 0.0~1.0 유사도 (레벤슈타인 기반).
  static double similarityRatio({
    required String spoken,
    required String correct,
    required String language,
  }) {
    final normSpoken = normalize(
      _spokenForCompare(spoken, language, correct: correct),
      language: language,
    );
    final normCorrect = normalize(correct, language: language);
    if (normSpoken.isEmpty || normCorrect.isEmpty) return 0;
    if (normSpoken == normCorrect) return 1;
    final distance = _levenshtein(normSpoken, normCorrect);
    final maxLen = normSpoken.length > normCorrect.length
        ? normSpoken.length
        : normCorrect.length;
    return 1 - distance / maxLen;
  }

  /// 글자 리스트 포함 관계 매칭 — [AnswerBlankHints] 등 부분 매칭용.
  static CjkLetterAlignment alignLetterLists({
    required List<String> spokenLetters,
    required List<String> correctLetters,
    required String language,
  }) {
    final spokenTokens = [
      for (var i = 0; i < spokenLetters.length; i++)
        _CharToken(index: i, char: spokenLetters[i]),
    ];
    final correctTokens = [
      for (var i = 0; i < correctLetters.length; i++)
        _CharToken(index: i, char: correctLetters[i]),
    ];

    final core = language == 'English'
        ? _alignTokens(spokenTokens, correctTokens, language)
        : _inclusionMatchTokens(spokenTokens, correctTokens, language);

    return CjkLetterAlignment(
      spokenMatched: core.spokenMatched,
      correctMatched: core.correctMatched,
      similarity: correctTokens.isEmpty
          ? 0
          : core.correctMatched.where((m) => m).length / correctTokens.length,
    );
  }

  static bool _keyWordsMatch({
    required String spoken,
    required String correct,
    required String blankFrame,
    required String language,
  }) {
    final key = AnswerBlankHints.extractKeyAnswer(
      correct: correct,
      blankFrame: blankFrame,
      language: language,
    );
    if (key.isEmpty) {
      return isCorrect(
        spoken: spoken,
        correct: correct,
        language: language,
      );
    }
    final adjustedSpoken = _spokenForCompare(spoken, language, correct: correct);
    final spokenLetters = AnswerBlankHints.matchLetters(
      adjustedSpoken,
      language: language,
    ).join();
    final keyLetters = AnswerBlankHints.matchLetters(
      key,
      language: language,
    ).join();
    if (spokenLetters.isEmpty || keyLetters.isEmpty) return false;
    if (spokenLetters == keyLetters) return true;

    if (isCorrect(spoken: spoken, correct: correct, language: language)) {
      return true;
    }

    if (language == 'English') {
      final keyWords = <String>[];
      final flags = AnswerBlankHints.keyLetterFlags(
        correct: correct,
        blankFrame: blankFrame,
        language: language,
      );
      final words = WordCompare.splitWords(correct);
      var li = 0;
      for (final w in words) {
        final letters =
            w.replaceAll(RegExp(r'[.,!?;:"()\[\]…]'), '').split('');
        var isKey = false;
        for (final _ in letters.where((c) => c.isNotEmpty)) {
          if (li < flags.length && flags[li]) isKey = true;
          li++;
        }
        if (isKey) keyWords.add(WordCompare.normalize(w));
      }
      final spokenWords =
          WordCompare.splitWords(spoken).map(WordCompare.normalize).toList();
      if (keyWords.isEmpty) return false;
      var si = 0;
      for (final kw in keyWords) {
        var found = false;
        while (si < spokenWords.length) {
          if (spokenWords[si] == kw) {
            found = true;
            si++;
            break;
          }
          si++;
        }
        if (!found) return false;
      }
      return true;
    }

    final keyNorm = normalize(key, language: language);
    final spokenNorm = normalize(adjustedSpoken, language: language);
    return spokenNorm.contains(keyNorm) ||
        (keyNorm.contains(spokenNorm) &&
            spokenNorm.length >= (keyNorm.length * 0.85).floor()) ||
        similarityPercent(
              spoken: spoken,
              correct: key,
              language: language,
            ) >=
            82;
  }

  static bool _englishWordMatch(String spoken, String correct) {
    final spokenWords = WordCompare.splitWords(spoken);
    final correctWords = WordCompare.splitWords(correct);
    if (correctWords.isEmpty) return false;
    if (spokenWords.length < correctWords.length) {
      return _sequenceMatches(spokenWords, correctWords) &&
          spokenWords.length >= (correctWords.length * 0.75).ceil();
    }
    return _sequenceMatches(spokenWords, correctWords);
  }

  static bool _sequenceMatches(
    List<String> spokenWords,
    List<String> correctWords,
  ) {
    var si = 0;
    for (var ci = 0; ci < correctWords.length; ci++) {
      var found = false;
      while (si < spokenWords.length) {
        if (WordCompare.normalize(spokenWords[si]) ==
            WordCompare.normalize(correctWords[ci])) {
          found = true;
          si++;
          break;
        }
        si++;
      }
      if (!found) return false;
    }
    return true;
  }

  static bool _cjkFuzzyMatch(String spoken, String correct) {
    if (spoken.contains(correct) || correct.contains(spoken)) {
      return spoken.length >= (correct.length * 0.7).floor();
    }
    final ratio = 1 -
        _levenshtein(spoken, correct) /
            (spoken.length > correct.length ? spoken.length : correct.length);
    return ratio >= 0.82;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return matrix[a.length][b.length];
  }

  /// 정답 문장의 각 단어/글자가 STT와 맞았는지 여부.
  ///
  /// CJK: 정답 글자별로 spoken에 동일(정규화) 글자가 포함되는지 판별.
  static List<bool> wordMatchFlags({
    required String correct,
    required String spoken,
    required String language,
  }) {
    if (language == 'English') {
      return _englishWordFlags(correct, spoken);
    }
    return _cjkInclusionFlags(
      correct: correct,
      spoken: spoken,
      language: language,
    );
  }

  /// CJK 포함 관계 매칭 — 정답 각 글자가 spoken에 존재하면 true.
  static List<bool> _cjkInclusionFlags({
    required String correct,
    required String spoken,
    required String language,
  }) {
    final adjustedSpoken = _spokenForCompare(spoken, language, correct: correct);
    final displayChars = correct.split('');
    if (displayChars.isEmpty) return [];

    final normCorrectChars = _normalizedChars(correct, language);
    final normSpokenChars = _normalizedChars(adjustedSpoken, language);
    final displayMap = _normCharToDisplayIndices(correct, language);
    final normMatched = _inclusionOnCharLists(
      normCorrectChars,
      normSpokenChars,
      language,
    );

    final flags = List<bool>.filled(displayChars.length, true);
    for (var i = 0; i < displayChars.length; i++) {
      if (normalize(displayChars[i], language: language).isEmpty) continue;
      flags[i] = false;
    }

    for (var ni = 0; ni < normMatched.length; ni++) {
      if (!normMatched[ni]) continue;
      if (ni >= displayMap.length) continue;
      for (final di in displayMap[ni]) {
        flags[di] = true;
      }
    }
    return flags;
  }

  /// STT 문장 각 글자의 일치 여부 (표시용).
  ///
  /// 점수(%)와 동일한 보정·정규화 기준을 쓰며, 100%일 때는
  /// 정답과 동치인 STT 글자는 모두 초록색으로 표시한다.
  static List<bool> spokenCharMatchFlags({
    required String spoken,
    required String correct,
    required String language,
  }) {
    final rawChars = spoken.split('');
    if (rawChars.isEmpty) return [];

    final adjustedSpoken = _spokenForCompare(spoken, language, correct: correct);
    final adjChars = adjustedSpoken.split('');
    if (adjChars.isEmpty) return List<bool>.filled(rawChars.length, false);

    final normSpokenChars = _normalizedChars(adjustedSpoken, language);
    final normCorrectChars = _normalizedChars(correct, language);
    final correctDisplayChars = correct.split('');

    final spokenUsed = List<bool>.filled(normSpokenChars.length, false);
    final correctMatched = _inclusionOnCharLists(
      normCorrectChars,
      normSpokenChars,
      language,
      spokenUsedOut: spokenUsed,
    );

    final allCorrectMatched = normCorrectChars.isNotEmpty &&
        correctMatched.length == normCorrectChars.length &&
        correctMatched.every((m) => m);

    final adjFlags = List<bool>.filled(adjChars.length, false);

    if (allCorrectMatched) {
      for (var i = 0; i < adjChars.length; i++) {
        final ch = adjChars[i];
        if (normalize(ch, language: language).isEmpty) {
          adjFlags[i] = true;
          continue;
        }
        adjFlags[i] = correctDisplayChars.any(
          (c) => _charsEquivalent(ch, c, language),
        );
      }
    } else {
      final displayMap = _normCharToDisplayIndices(adjustedSpoken, language);
      for (var si = 0; si < spokenUsed.length; si++) {
        if (!spokenUsed[si]) continue;
        if (si >= displayMap.length) continue;
        for (final di in displayMap[si]) {
          if (di < adjFlags.length) adjFlags[di] = true;
        }
      }
    }

    return adjFlags;
  }

  /// 정답 문장 각 글자의 일치 여부 (표시용).
  static List<bool> correctCharMatchFlags({
    required String correct,
    required String spoken,
    required String language,
  }) {
    return _cjkInclusionFlags(
      correct: correct,
      spoken: spoken,
      language: language,
    );
  }

  static List<String> _normalizedChars(String text, String language) {
    return normalize(text, language: language)
        .split('')
        .where((c) => c.isNotEmpty)
        .toList();
  }

  /// 정규화 글자 i → 원문 display 인덱스(들).
  static List<List<int>> _normCharToDisplayIndices(
    String text,
    String language,
  ) {
    final display = text.split('');
    final map = <List<int>>[];
    var accumulated = '';

    for (var i = 0; i < display.length; i++) {
      final ch = display[i];
      if (normalize(ch, language: language).isEmpty) continue;

      final beforeNorm = normalize(accumulated, language: language);
      accumulated += ch;
      final afterNorm = normalize(accumulated, language: language);
      final added = afterNorm.substring(beforeNorm.length);

      if (added.isEmpty) {
        if (map.isNotEmpty) {
          map.last.add(i);
        } else {
          map.add([i]);
        }
        continue;
      }

      for (final _ in added.split('')) {
        map.add([i]);
      }
    }
    return map;
  }

  static List<bool> _inclusionOnCharLists(
    List<String> correctChars,
    List<String> spokenChars,
    String language, {
    List<bool>? spokenUsedOut,
  }) {
    final spokenUsed = List<bool>.filled(spokenChars.length, false);
    final correctMatched = List<bool>.filled(correctChars.length, false);

    for (var ci = 0; ci < correctChars.length; ci++) {
      for (var si = 0; si < spokenChars.length; si++) {
        if (spokenUsed[si]) continue;
        if (_charsEquivalent(correctChars[ci], spokenChars[si], language)) {
          correctMatched[ci] = true;
          spokenUsed[si] = true;
          break;
        }
      }
    }
    if (spokenUsedOut != null) {
      for (var i = 0; i < spokenUsed.length; i++) {
        spokenUsedOut[i] = spokenUsed[i];
      }
    }
    return correctMatched;
  }

  /// spoken에서 아직 쓰이지 않은 글자 중 정답 글자와 등가인 것을 찾아 매칭.
  static _InclusionCore _inclusionMatchTokens(
    List<_CharToken> spokenTokens,
    List<_CharToken> correctTokens,
    String language,
  ) {
    final spokenChars = [
      for (final t in spokenTokens)
        normalize(t.char, language: language),
    ];
    final correctChars = [
      for (final t in correctTokens)
        normalize(t.char, language: language),
    ];

    final n = spokenChars.length;
    final m = correctChars.length;
    if (m == 0) {
      return _InclusionCore(
        spokenMatched: List<bool>.filled(n, false),
        correctMatched: const [],
      );
    }
    if (n == 0) {
      return _InclusionCore(
        spokenMatched: const [],
        correctMatched: List<bool>.filled(m, false),
      );
    }

    final spokenUsed = List<bool>.filled(n, false);
    final spokenMatched = List<bool>.filled(n, false);
    final correctMatched = List<bool>.filled(m, false);

    for (var ci = 0; ci < m; ci++) {
      for (var si = 0; si < n; si++) {
        if (spokenUsed[si]) continue;
        if (_charsEquivalent(correctChars[ci], spokenChars[si], language)) {
          correctMatched[ci] = true;
          spokenMatched[si] = true;
          spokenUsed[si] = true;
          break;
        }
      }
    }

    return _InclusionCore(
      spokenMatched: spokenMatched,
      correctMatched: correctMatched,
    );
  }

  /// LCS 정렬 — 영어 글자 단위 부분 매칭용.
  static _InclusionCore _alignTokens(
    List<_CharToken> spokenTokens,
    List<_CharToken> correctTokens,
    String language,
  ) {
    final n = spokenTokens.length;
    final m = correctTokens.length;
    if (m == 0) {
      return _InclusionCore(
        spokenMatched: List<bool>.filled(n, false),
        correctMatched: const [],
      );
    }
    if (n == 0) {
      return _InclusionCore(
        spokenMatched: const [],
        correctMatched: List<bool>.filled(m, false),
      );
    }

    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (_charsEquivalent(
          spokenTokens[i - 1].char,
          correctTokens[j - 1].char,
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

    final spokenMatched = List<bool>.filled(n, false);
    final correctMatched = List<bool>.filled(m, false);
    var i = n;
    var j = m;
    while (i > 0 && j > 0) {
      final diagonalMatch = _charsEquivalent(
        spokenTokens[i - 1].char,
        correctTokens[j - 1].char,
        language,
      );
      if (diagonalMatch && dp[i][j] == dp[i - 1][j - 1] + 1) {
        spokenMatched[i - 1] = true;
        correctMatched[j - 1] = true;
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return _InclusionCore(
      spokenMatched: spokenMatched,
      correctMatched: correctMatched,
    );
  }

  static List<bool> _englishWordFlags(String correct, String spoken) {
    final correctWords = EnglishPronunciationTokens.mergeTokens(
      WordCompare.splitWords(correct),
    );
    final spokenWords = EnglishPronunciationTokens.mergeTokens(
      WordCompare.splitWords(spoken),
    );
    if (correctWords.isEmpty) return [];

    final flags = List<bool>.filled(correctWords.length, false);
    var si = 0;
    for (var ci = 0; ci < correctWords.length; ci++) {
      while (si < spokenWords.length) {
        if (EnglishPronunciationTokens.areEquivalent(
          spokenWords[si],
          correctWords[ci],
        )) {
          flags[ci] = true;
          si++;
          break;
        }
        si++;
      }
    }
    return flags;
  }
}

class CjkLetterAlignment {
  final List<bool> spokenMatched;
  final List<bool> correctMatched;
  final double similarity;

  const CjkLetterAlignment({
    required this.spokenMatched,
    required this.correctMatched,
    required this.similarity,
  });
}

class _CharToken {
  final int index;
  final String char;

  const _CharToken({required this.index, required this.char});
}

class _InclusionCore {
  final List<bool> spokenMatched;
  final List<bool> correctMatched;

  const _InclusionCore({
    required this.spokenMatched,
    required this.correctMatched,
  });
}
