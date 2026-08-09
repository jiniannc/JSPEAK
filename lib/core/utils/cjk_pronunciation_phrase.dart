import 'cjk_stt_segments.dart';
import 'japanese_to_korean_converter.dart';
import 'scenario_answer_compare.dart';
import 'word_token_alignment.dart';
import 'word_compare.dart';

/// 표면(일본어/중국어) + 한글 발음 가이드 한 구문.
class CjkPhraseLexeme {
  final String surface;
  final String phonetic;

  const CjkPhraseLexeme({
    required this.surface,
    this.phonetic = '',
  });
}

/// CJK 문장을 구문 단위로 나누고 시트 `pronunciation`(한글 발음)과 짝짓는다.
class CjkPronunciationPhraseBuilder {
  CjkPronunciationPhraseBuilder._();

  static final RegExp _jpParticle = RegExp(r'[とをにはのでがはもへ]');
  static final RegExp _kanji = RegExp(r'[\u4E00-\u9FFF]');
  static final RegExp _punct = RegExp(r'[。、！？，,\.!?]');
  static final RegExp _phoneticSplit = RegExp(r'[\s/]+');

  static List<String> parsePhoneticTokens(String pronunciation) => pronunciation
      .split(_phoneticSplit)
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  static String normalizePhonetic(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\-·・]'), '');

  static List<String> segmentSurface(String text, {required String language}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    if (_hasSlashSegments(trimmed)) {
      return _splitSlashSegments(trimmed);
    }

    if (language == 'Japanese') {
      return _segmentJapanese(trimmed);
    }
    if (language == 'Chinese') {
      return _segmentChinese(trimmed);
    }
    return [trimmed];
  }

  static List<String> _segmentJapanese(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(ch);

      if (_punct.hasMatch(ch)) {
        tokens.add(buffer.toString());
        buffer.clear();
        continue;
      }

      if (i + 1 < text.length) {
        final next = text[i + 1];
        if (_jpParticle.hasMatch(ch) && _kanji.hasMatch(next)) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      }
    }

    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  static List<String> _segmentChinese(String text) {
    if (text.contains(' ')) {
      return WordCompare.splitWords(text);
    }

    final tokens = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buffer.write(ch);
      if (_punct.hasMatch(ch)) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens.isEmpty ? [text] : tokens;
  }

  static bool _hasSlashSegments(String text) => text.contains('/');

  static List<String> _splitSlashSegments(String text) => text
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String _prepareSpokenForCompare(String spoken, String language) {
    if (!CjkSttSegments.isTargetLanguage(language)) return spoken.trim();
    final preprocessed = language == 'Japanese'
        ? ScenarioAnswerCompare.preprocessSpoken(spoken, language: language)
        : spoken;
    return CjkSttSegments.extractTargetScript(preprocessed, language);
  }

  static List<CjkPhraseLexeme> buildLexicon({
    required String sentence,
    required String pronunciation,
    required String language,
  }) {
    final surfaces = segmentSurface(sentence, language: language);
    if (surfaces.isEmpty) return [];

    final phonetics = parsePhoneticTokens(pronunciation);
    if (phonetics.isEmpty) {
      return [
        for (final surface in surfaces) CjkPhraseLexeme(surface: surface),
      ];
    }

    return _zipSurfacesWithPhonetics(surfaces, phonetics);
  }

  static List<CjkPhraseLexeme> _zipSurfacesWithPhonetics(
    List<String> surfaces,
    List<String> phonetics,
  ) {
    if (surfaces.length == phonetics.length) {
      return List.generate(
        surfaces.length,
        (i) => CjkPhraseLexeme(
          surface: surfaces[i],
          phonetic: phonetics[i],
        ),
      );
    }

    if (surfaces.length == 1) {
      return [
        CjkPhraseLexeme(
          surface: surfaces.first,
          phonetic: phonetics.join(' '),
        ),
      ];
    }

    final weights = surfaces
        .map((s) => s.replaceAll(_punct, '').length)
        .toList();
    final totalWeight =
        weights.fold<int>(0, (sum, w) => sum + w).clamp(1, 9999);

    final result = <CjkPhraseLexeme>[];
    var phoneticCursor = 0;

    for (var i = 0; i < surfaces.length; i++) {
      final remainingPhonetics = phonetics.length - phoneticCursor;
      final remainingSurfaces = surfaces.length - i;

      int take;
      if (i == surfaces.length - 1) {
        take = remainingPhonetics;
      } else {
        final share = (weights[i] / totalWeight * phonetics.length).round();
        take = share.clamp(1, remainingPhonetics - remainingSurfaces + 1);
      }

      final slice = phonetics.sublist(
        phoneticCursor,
        phoneticCursor + take,
      );
      phoneticCursor += take;

      result.add(
        CjkPhraseLexeme(
          surface: surfaces[i],
          phonetic: slice.join(' '),
        ),
      );
    }

    return result;
  }

  static String stripPunctuation(String text) =>
      text.replaceAll(_punct, '').trim();

  static bool surfacesEquivalent(String a, String b, String language) {
    if (a.trim().isEmpty || b.trim().isEmpty) return false;
    if (ScenarioAnswerCompare.charsEquivalentForCompare(a, b, language)) {
      return true;
    }
    final na = stripPunctuation(a);
    final nb = stripPunctuation(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    return ScenarioAnswerCompare.charsEquivalentForCompare(na, nb, language);
  }

  /// STT 구문을 정답 구문 수/경계에 맞게 재매핑 — 부분 문자열·suffix 일치 추출.
  static List<String> mapSpokenSegmentsToTarget({
    required List<String> spokenSegments,
    required List<String> targetPhrases,
    required String language,
  }) {
    final n = targetPhrases.length;
    if (n == 0) return spokenSegments;

    final spokenFull = spokenSegments.join();
    if (spokenFull.isEmpty) return List.filled(n, '');

    if (spokenSegments.length == n) {
      var allExact = true;
      for (var i = 0; i < n; i++) {
        if (!surfacesEquivalent(
          targetPhrases[i],
          spokenSegments[i],
          language,
        )) {
          allExact = false;
          break;
        }
      }
      if (allExact) return List<String>.from(spokenSegments);
    }

    final mapped = List<String>.filled(n, '');
    final claimed = List<bool>.filled(spokenFull.length, false);

    void claimRange(int start, int end) {
      for (var i = start; i < end; i++) {
        if (i >= 0 && i < claimed.length) claimed[i] = true;
      }
    }

    bool rangeFree(int start, int end) {
      for (var i = start; i < end; i++) {
        if (claimed[i]) return false;
      }
      return true;
    }

    // 뒤쪽 정답 구문(예: 座席でございます)을 긴 STT blob에서 먼저 추출.
    for (var ti = n - 1; ti >= 0; ti--) {
      final target = targetPhrases[ti];
      if (target.trim().isEmpty) continue;

      final match = _findBestEquivalentRange(
        needle: target,
        haystack: spokenFull,
        language: language,
        rangeFree: rangeFree,
      );
      if (match != null) {
        mapped[ti] = spokenFull.substring(match.$1, match.$2);
        claimRange(match.$1, match.$2);
      }
    }

    // 미매칭 슬롯 — 아직 claim 안 된 spoken 구간을 순서대로 배분.
    final unclaimed = StringBuffer();
    for (var i = 0; i < spokenFull.length; i++) {
      if (!claimed[i]) unclaimed.write(spokenFull[i]);
    }
    var leftover = unclaimed.toString();

    for (var ti = 0; ti < n; ti++) {
      if (mapped[ti].isNotEmpty) continue;
      if (leftover.isEmpty) continue;

      final morphemes = segmentSurface(leftover, language: language);
      if (morphemes.isEmpty) {
        mapped[ti] = leftover;
        leftover = '';
        continue;
      }

      mapped[ti] = morphemes.first;
      final idx = leftover.indexOf(morphemes.first);
      if (idx >= 0) {
        leftover = leftover.replaceFirst(morphemes.first, '');
      } else {
        leftover = '';
      }
    }

    if (leftover.trim().isNotEmpty) {
      for (var ti = n - 1; ti >= 0; ti--) {
        if (mapped[ti].isEmpty) {
          mapped[ti] = leftover.trim();
          break;
        }
        if (!surfacesEquivalent(mapped[ti], targetPhrases[ti], language)) {
          mapped[ti] = '${mapped[ti]}$leftover';
          break;
        }
      }
    }

    return mapped;
  }

  /// haystack 안에서 needle과 동치인 구간 탐색 — 길이·우측 정렬 우선.
  static (int start, int end)? _findBestEquivalentRange({
    required String needle,
    required String haystack,
    required String language,
    required bool Function(int start, int end) rangeFree,
  }) {
    if (needle.trim().isEmpty || haystack.isEmpty) return null;

    (int, int)? best;
    var bestLen = 0;

    for (var start = 0; start < haystack.length; start++) {
      for (var end = start + 1; end <= haystack.length; end++) {
        if (!rangeFree(start, end)) continue;
        final slice = haystack.substring(start, end);
        if (!surfacesEquivalent(needle, slice, language)) continue;
        final len = end - start;
        if (len > bestLen || (len == bestLen && start > (best?.$1 ?? -1))) {
          best = (start, end);
          bestLen = len;
        }
      }
    }

    return best;
  }

  static List<String> _charUnits(String text, String language) {
    final stripped = stripPunctuation(text);
    return stripped.split('').where((c) => c.trim().isNotEmpty).toList();
  }

  /// 정답·STT 문자 단위 LCS 길이 (구두점 제외).
  static int characterLcsMatchedLength(
    String target,
    String spoken,
    String language,
  ) {
    final t = _charUnits(target, language);
    final s = _charUnits(spoken, language);
    if (t.isEmpty || s.isEmpty) return 0;

    final n = t.length;
    final m = s.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (ScenarioAnswerCompare.charsEquivalentForCompare(
          t[i - 1],
          s[j - 1],
          language,
        )) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }
    return dp[n][m];
  }

  static int _targetCharacterCount(String text, String language) =>
      _charUnits(text, language).length;

  /// 맞춘 글자 수 / 정답 전체 글자 수 기반 부분 점수.
  static int accuracyPercentByCharacters({
    required String sentence,
    required String spokenText,
    required String language,
  }) {
    final spokenPrepared = _prepareSpokenForCompare(spokenText, language);
    final targetLen = _targetCharacterCount(sentence, language);
    if (targetLen == 0) {
      return spokenPrepared.trim().isEmpty ? 100 : 0;
    }
    final matched = characterLcsMatchedLength(
      sentence,
      spokenPrepared,
      language,
    );
    return ((matched / targetLen) * 100).round().clamp(0, 100);
  }

  /// 거대한 substitution을 형태소/구문 단위 ops로 분할.
  static List<WordAlignmentOp> subdivideSubstitution({
    required String target,
    required String spoken,
    required String language,
  }) {
    if (surfacesEquivalent(target, spoken, language)) {
      return [
        WordAlignmentOp(
          kind: WordAlignmentKind.match,
          targetWord: target,
          spokenWord: spoken,
        ),
      ];
    }

    final targetMorphs = segmentSurface(target, language: language);
    final spokenMorphs = segmentSurface(spoken, language: language);

    if (targetMorphs.length <= 1 || spokenMorphs.length <= 1) {
      return [
        WordAlignmentOp(
          kind: WordAlignmentKind.substitution,
          targetWord: target,
          spokenWord: spoken,
        ),
      ];
    }

    return WordTokenAligner.align(
      targetWords: targetMorphs,
      spokenWords: spokenMorphs,
      language: language,
    ).ops;
  }

  static List<WordAlignmentOp> _subdivideAlignmentOps(
    List<WordAlignmentOp> ops,
    String language,
  ) {
    final result = <WordAlignmentOp>[];
    for (final op in ops) {
      if (op.kind == WordAlignmentKind.substitution &&
          op.targetWord != null &&
          op.spokenWord != null) {
        result.addAll(
          subdivideSubstitution(
            target: op.targetWord!,
            spoken: op.spokenWord!,
            language: language,
          ),
        );
      } else {
        result.add(op);
      }
    }
    return result;
  }

  static bool phoneticsEquivalent(String a, String b) {
    final na = normalizePhonetic(a);
    final nb = normalizePhonetic(b);
    if (na.isEmpty || nb.isEmpty) return na == nb;
    if (na == nb) return true;
    return _levenshteinRatio(na, nb) >= 0.82;
  }

  static double _levenshteinRatio(String a, String b) {
    if (a == b) return 1;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1;
    return 1 - dist / maxLen;
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  /// 구문 단위 정렬 — 표면 fuzzy + 한글 발음 유사도로 match 판정.
  static WordTokenAlignment alignPhrases({
    required String sentence,
    required String pronunciation,
    required String spokenText,
    required String language,
  }) {
    final lexicon = buildLexicon(
      sentence: sentence,
      pronunciation: pronunciation,
      language: language,
    );
    if (lexicon.isEmpty) return const WordTokenAlignment([]);

    final targetSurfaces = lexicon.map((e) => e.surface).toList();
    final spokenPrepared = _prepareSpokenForCompare(
      spokenText,
      language,
    );
    final autoSpoken = segmentSurface(spokenPrepared, language: language);
    final spokenSurfaces = mapSpokenSegmentsToTarget(
      spokenSegments: autoSpoken,
      targetPhrases: targetSurfaces,
      language: language,
    );

    final baseAlignment = WordTokenAligner.align(
      targetWords: targetSurfaces,
      spokenWords: spokenSurfaces,
      language: language,
    );

    final refinedOps = <WordAlignmentOp>[];
    var targetCursor = 0;

    for (final op in baseAlignment.ops) {
      switch (op.kind) {
        case WordAlignmentKind.match:
          refinedOps.add(op);
          targetCursor++;
        case WordAlignmentKind.substitution:
          final target = lexicon[targetCursor];
          final spokenSurface = op.spokenWord ?? '';
          final spokenHint = _spokenPhoneticHint(
            spokenText,
            spokenSurface,
            target,
            language,
            phraseIndex: targetCursor,
          );
          final phoneticMatch = phoneticsEquivalent(
            target.phonetic,
            spokenHint,
          );
          if (surfacesEquivalent(spokenSurface, target.surface, language) ||
              phoneticMatch) {
            refinedOps.add(
              WordAlignmentOp(
                kind: WordAlignmentKind.match,
                targetWord: target.surface,
                spokenWord: spokenSurface,
              ),
            );
          } else {
            refinedOps.add(op);
          }
          targetCursor++;
        case WordAlignmentKind.deletion:
          refinedOps.add(op);
          targetCursor++;
        case WordAlignmentKind.insertion:
          refinedOps.add(op);
      }
    }

    return WordTokenAlignment(
      _subdivideAlignmentOps(refinedOps, language),
    );
  }

  /// 구문 정렬 + 글자 LCS 기반 부분 점수 (0~100).
  static int accuracyPercent({
    required String sentence,
    required String pronunciation,
    required String spokenText,
    required String language,
  }) {
    return accuracyPercentByCharacters(
      sentence: sentence,
      spokenText: spokenText,
      language: language,
    );
  }

  static String _spokenPhoneticHint(
    String rawSpoken,
    String spokenSurface,
    CjkPhraseLexeme target,
    String language, {
    int phraseIndex = 0,
  }) {
    if (surfacesEquivalent(spokenSurface, target.surface, language)) {
      return target.phonetic;
    }

    final nonScriptParts = CjkSttSegments.parse(rawSpoken, language)
        .where((s) => !s.isTargetScript)
        .map((s) => s.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (phraseIndex < nonScriptParts.length) {
      return nonScriptParts[phraseIndex];
    }
    if (nonScriptParts.length == 1) {
      return nonScriptParts.first;
    }

    return '';
  }

  /// 치환 오답 칩용 — STT에 한글/로마字 발음표기가 있을 때만 서브텍스트로 노출.
  static String? spokenPhoneticForSubstitution({
    required String rawSpoken,
    required String spokenSurface,
    required CjkPhraseLexeme target,
    required String language,
    int phraseIndex = 0,
  }) {
    if (surfacesEquivalent(spokenSurface, target.surface, language)) {
      return null;
    }

    final hint = _spokenPhoneticHint(
      rawSpoken,
      spokenSurface,
      target,
      language,
      phraseIndex: phraseIndex,
    );
    if (hint.isNotEmpty && !phoneticsEquivalent(hint, target.phonetic)) {
      return hint;
    }

    if (language == 'Japanese') {
      return JapaneseToKoreanConverter.transliterateOrNull(spokenSurface);
    }
    return null;
  }

  static String? spokenPhoneticForInsertion({
    required String spokenSurface,
    required String language,
  }) {
    if (language == 'Japanese') {
      return JapaneseToKoreanConverter.transliterateOrNull(spokenSurface);
    }
    return null;
  }

  static String? phoneticForSurface(
    List<CjkPhraseLexeme> lexicon,
    String surface,
  ) {
    for (final item in lexicon) {
      if (item.surface == surface) return item.phonetic;
    }
    return null;
  }
}
