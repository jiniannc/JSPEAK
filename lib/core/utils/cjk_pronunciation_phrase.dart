import 'cjk_spoken_phonetic.dart';
import 'cjk_stt_segments.dart';
import 'japanese_number_normalizer.dart';
import 'japanese_reading_fold.dart';
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
  static final RegExp _kanji = RegExp(r'[\u4E00-\u9FFF\u3005\u3006\u3007\u303B]');
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

  static String _prepareSpokenForCompare(
    String spoken,
    String language, {
    String? referenceText,
  }) {
    if (!CjkSttSegments.isTargetLanguage(language)) return spoken.trim();
    var preprocessed = language == 'Japanese'
        ? ScenarioAnswerCompare.preprocessSpoken(spoken, language: language)
        : spoken;
    if (language == 'Japanese') {
      preprocessed = JapaneseNumberNormalizer.expandDigitsInText(preprocessed);
    }
    final extracted = CjkSttSegments.extractTargetScript(
      preprocessed,
      language,
      referenceText: referenceText,
    );
    if (language == 'Japanese' &&
        referenceText != null &&
        referenceText.trim().isNotEmpty) {
      final targetExpanded = JapaneseNumberNormalizer.expandDigitsInText(
        referenceText,
      );
      final targetScript = CjkSttSegments.extractTargetScript(
        targetExpanded,
        language,
        referenceText: referenceText,
      );
      return JapaneseReadingFold.fold(extracted, targetScript);
    }
    return extracted;
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
      if (phonetics.length > 1) {
        final split = _splitSingleSurfaceByPhoneticWeights(
          surfaces.first,
          phonetics,
        );
        if (split != null) return split;
      }
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

  /// 세그멘테이션이 (예: を 뒤가 히라가나라) 문장 전체를 구문 하나로 뭉쳐도,
  /// pronunciation에 남아 있는 공백 구분은 실제 구문 경계 힌트다.
  /// 그 힌트를 이용해 하나의 surface를 phonetics 개수만큼 비율로 재분할한다.
  /// (반대 방향인 `weights` 분배 로직과 대칭.) 재분할 없이 문장 전체를
  /// 하나로 두면, 뒤쪽 글자의 발음 음절 수가 글자 수와 안 맞을 때 그 오차가
  /// 앞쪽 구문 경계까지 새어 들어와 옆 단어 발음이 섞여 보일 수 있다.
  static List<CjkPhraseLexeme>? _splitSingleSurfaceByPhoneticWeights(
    String surface,
    List<String> phonetics,
  ) {
    final weights = phonetics
        .map(
          (p) => p.replaceAll(RegExp(r'[-\^.·・\s]'), '').length,
        )
        .toList();
    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
    if (totalWeight <= 0) return null;

    final totalChars = _contentCharCount(surface);
    if (totalChars < phonetics.length) return null;

    final result = <CjkPhraseLexeme>[];
    var charCursor = 0;
    var contentConsumed = 0;
    var weightConsumed = 0;

    for (var i = 0; i < phonetics.length; i++) {
      final isLast = i == phonetics.length - 1;
      int targetContentEnd;
      if (isLast) {
        targetContentEnd = totalChars;
      } else {
        weightConsumed += weights[i];
        final remainingPhrases = phonetics.length - i - 1;
        targetContentEnd = (weightConsumed / totalWeight * totalChars).round();
        targetContentEnd = targetContentEnd.clamp(
          contentConsumed + 1,
          totalChars - remainingPhrases,
        );
      }

      var idx = charCursor;
      var content = contentConsumed;
      while (idx < surface.length && content < targetContentEnd) {
        if (!_punct.hasMatch(surface[idx])) content++;
        idx++;
      }

      result.add(
        CjkPhraseLexeme(
          surface: surface.substring(charCursor, idx),
          phonetic: phonetics[i],
        ),
      );
      charCursor = idx;
      contentConsumed = content;
    }

    if (charCursor < surface.length) {
      final last = result.removeLast();
      result.add(
        CjkPhraseLexeme(
          surface: last.surface + surface.substring(charCursor),
          phonetic: last.phonetic,
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
    if (language == 'Japanese') {
      target = JapaneseNumberNormalizer.expandDigitsInText(target);
    }
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

  /// LCS로 매칭되지 않은 STT 글자들 — [accuracyPercentByCharacters]가 점수를
  /// 깎는 실제 근거. 단어/구문 diff에서는 발음이 비슷해 "완벽 일치"로
  /// 보여도, STT가 잡음·필러를 여분의 글자로 인식했으면 여기 나타난다.
  static List<String> extraRecognizedChars({
    required String sentence,
    required String spokenText,
    required String language,
  }) {
    final spokenPrepared = _prepareSpokenForCompare(
      spokenText,
      language,
      referenceText: sentence,
    );
    final t = _charUnits(sentence, language);
    final s = _charUnits(spokenPrepared, language);
    if (t.isEmpty || s.isEmpty) return const [];

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

    final matchedSpokenIdx = <int>{};
    var i = n;
    var j = m;
    while (i > 0 && j > 0) {
      if (ScenarioAnswerCompare.charsEquivalentForCompare(
            t[i - 1],
            s[j - 1],
            language,
          ) &&
          dp[i][j] == dp[i - 1][j - 1] + 1) {
        matchedSpokenIdx.add(j - 1);
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return [
      for (var k = 0; k < s.length; k++)
        if (!matchedSpokenIdx.contains(k)) s[k],
    ];
  }

  /// 맞춘 글자 수 / 정답 전체 글자 수 기반 부분 점수.
  static int accuracyPercentByCharacters({
    required String sentence,
    required String spokenText,
    required String language,
  }) {
    final spokenPrepared = _prepareSpokenForCompare(
      spokenText,
      language,
      referenceText: sentence,
    );
    final targetLen = _targetCharacterCount(sentence, language);
    if (targetLen == 0) {
      return spokenPrepared.trim().isEmpty ? 100 : 0;
    }
    final matched = characterLcsMatchedLength(
      sentence,
      spokenPrepared,
      language,
    );
    final spokenLen = _targetCharacterCount(spokenPrepared, language);
    var score = (matched / targetLen) * 100;
    // STT가 정답보다 글자를 더 넣어도 LCS만으로는 100점이 되는 문제 보정.
    if (spokenLen > targetLen) {
      score -= ((spokenLen - targetLen) / targetLen) * 100;
    }
    return score.round().clamp(0, 100);
  }

  /// 거대한 substitution을 형태소/구문 단위 ops로 분할 (채점·정렬용).
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

  /// inline diff UI용 — 형태소 분할 실패 시 글자 단위로 쪼갠다.
  static List<WordAlignmentOp> subdivideForInlineDiff({
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

    if (targetMorphs.length > 1 && spokenMorphs.length > 1) {
      final morphOps = WordTokenAligner.align(
        targetWords: targetMorphs,
        spokenWords: spokenMorphs,
        language: language,
      ).ops;
      final onlyWholeSubstitution = morphOps.length == 1 &&
          morphOps.first.kind == WordAlignmentKind.substitution;
      if (!onlyWholeSubstitution) {
        return morphOps;
      }
    }

    return _subdivideByCharacters(target, spoken, language);
  }

  /// 문장형 inline diff — morph 생략, 항상 글자 단위(중간 누락·false match 방지).
  static List<WordAlignmentOp> subdivideForInlineDiffSentence({
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
    return _subdivideByCharacters(target, spoken, language);
  }

  /// 구문 내부 char subdivide — morph 없이 글자 단위만.
  static List<WordAlignmentOp> subdivideForInlineDiffCharsOnly({
    required String target,
    required String spoken,
    required String language,
  }) => subdivideForInlineDiffSentence(
        target: target,
        spoken: spoken,
        language: language,
      );

  static List<WordAlignmentOp> _subdivideByCharacters(
    String target,
    String spoken,
    String language,
  ) {
    final targetUnits = _charUnits(target, language);
    final spokenUnits = _charUnits(spoken, language);

    if (targetUnits.isEmpty && spokenUnits.isEmpty) {
      return [
        WordAlignmentOp(
          kind: WordAlignmentKind.substitution,
          targetWord: target,
          spokenWord: spoken,
        ),
      ];
    }

    final charAlignment = WordTokenAligner.align(
      targetWords: targetUnits,
      spokenWords: spokenUnits,
      language: language,
    );
    final lcsOps = _coalesceAdjacentInsertionDeletion(
      _mergeAdjacentCharOps(charAlignment.ops),
    );

    final matchedLen = characterLcsMatchedLength(target, spoken, language);
    final maxLen = targetUnits.length > spokenUnits.length
        ? targetUnits.length
        : spokenUnits.length;
    if (maxLen > 0 && matchedLen / maxLen < 0.5) {
      return _coalesceAdjacentInsertionDeletion(
        _mergeAdjacentCharOps(
          _subdivideByCharactersPositional(targetUnits, spokenUnits, language),
        ),
      );
    }

    // 중간 누락(を·し 등) 뒤 Match는 그대로 둔다.
    // Missing UI가 누락 글자를 보여 주므로, gap을 substitution으로
    // 합치면 戻/もど처럼 한자·가나 정렬이 깨진다.
    return lcsOps;
  }

  /// 같은 인덱스끼리 비교 — LCS가 好처럼 엇갈린 글자를 match 처리하는 것을 방지.
  static List<WordAlignmentOp> _subdivideByCharactersPositional(
    List<String> targetUnits,
    List<String> spokenUnits,
    String language,
  ) {
    final ops = <WordAlignmentOp>[];
    final maxLen = targetUnits.length > spokenUnits.length
        ? targetUnits.length
        : spokenUnits.length;

    for (var i = 0; i < maxLen; i++) {
      final hasTarget = i < targetUnits.length;
      final hasSpoken = i < spokenUnits.length;
      if (hasTarget && hasSpoken) {
        final tc = targetUnits[i];
        final sc = spokenUnits[i];
        if (ScenarioAnswerCompare.charsEquivalentForCompare(tc, sc, language)) {
          ops.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.match,
              targetWord: tc,
              spokenWord: sc,
            ),
          );
        } else {
          ops.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.substitution,
              targetWord: tc,
              spokenWord: sc,
            ),
          );
        }
      } else if (hasSpoken) {
        ops.add(
          WordAlignmentOp(
            kind: WordAlignmentKind.insertion,
            spokenWord: spokenUnits[i],
          ),
        );
      } else {
        ops.add(
          WordAlignmentOp(
            kind: WordAlignmentKind.deletion,
            targetWord: targetUnits[i],
          ),
        );
      }
    }
    return ops;
  }

  static List<WordAlignmentOp> _coalesceAdjacentInsertionDeletion(
    List<WordAlignmentOp> ops,
  ) {
    final result = <WordAlignmentOp>[];
    var i = 0;
    while (i < ops.length) {
      if (i + 1 < ops.length) {
        final current = ops[i];
        final next = ops[i + 1];
        if (current.kind == WordAlignmentKind.insertion &&
            next.kind == WordAlignmentKind.deletion) {
          result.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.substitution,
              spokenWord: current.spokenWord,
              targetWord: next.targetWord,
            ),
          );
          i += 2;
          continue;
        }
        if (current.kind == WordAlignmentKind.deletion &&
            next.kind == WordAlignmentKind.insertion) {
          result.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.substitution,
              spokenWord: next.spokenWord,
              targetWord: current.targetWord,
            ),
          );
          i += 2;
          continue;
        }
      }
      result.add(ops[i]);
      i++;
    }
    return result;
  }

  static List<WordAlignmentOp> _mergeAdjacentCharOps(
    List<WordAlignmentOp> ops,
  ) {
    if (ops.isEmpty) return ops;

    final merged = <WordAlignmentOp>[];
    WordAlignmentKind? currentKind;
    final targetBuf = StringBuffer();
    final spokenBuf = StringBuffer();

    void flush() {
      if (currentKind == null) return;
      final t = targetBuf.toString();
      final s = spokenBuf.toString();
      targetBuf.clear();
      spokenBuf.clear();

      switch (currentKind!) {
        case WordAlignmentKind.match:
          merged.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.match,
              targetWord: t,
              spokenWord: s,
            ),
          );
        case WordAlignmentKind.substitution:
          merged.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.substitution,
              targetWord: t.isEmpty ? null : t,
              spokenWord: s.isEmpty ? null : s,
            ),
          );
        case WordAlignmentKind.deletion:
          merged.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.deletion,
              targetWord: t.isEmpty ? null : t,
            ),
          );
        case WordAlignmentKind.insertion:
          merged.add(
            WordAlignmentOp(
              kind: WordAlignmentKind.insertion,
              spokenWord: s.isEmpty ? null : s,
            ),
          );
      }
      currentKind = null;
    }

    for (final op in ops) {
      if (currentKind != null && currentKind != op.kind) {
        flush();
      }
      currentKind = op.kind;
      switch (op.kind) {
        case WordAlignmentKind.match:
          targetBuf.write(op.targetWord);
          spokenBuf.write(op.spokenWord);
        case WordAlignmentKind.substitution:
          targetBuf.write(op.targetWord ?? '');
          spokenBuf.write(op.spokenWord ?? '');
        case WordAlignmentKind.deletion:
          targetBuf.write(op.targetWord ?? '');
        case WordAlignmentKind.insertion:
          spokenBuf.write(op.spokenWord ?? '');
      }
    }
    flush();
    return merged;
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
      referenceText: sentence,
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

  /// 치환 오답 칩용 — STT spokenSurface만 가나→한글 변환 (원문 누락 토큰 phonetic 혼입 방지).
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

    if (language == 'Japanese' || language == 'Chinese') {
      return CjkSpokenPhonetic.phoneticForSpokenSurface(
        spokenSurface,
        language: language,
      );
    }
    return null;
  }

  static String? spokenPhoneticForInsertion({
    required String spokenSurface,
    required String language,
  }) {
    if (language == 'Japanese' || language == 'Chinese') {
      return CjkSpokenPhonetic.phoneticForSpokenSurface(
        spokenSurface,
        language: language,
      );
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

  /// 원문 [rangeStart, rangeEnd) 구간에 해당하는 pronunciation 슬라이스.
  /// `-` `^` 등 장음/악센트 기호는 길이 비율에서 제외해 글자 수와 맞춘다.
  static String? phoneticSliceForTargetRange({
    required String targetText,
    required String pronunciation,
    required int rangeStart,
    required int rangeEnd,
  }) {
    if (rangeStart >= rangeEnd || pronunciation.trim().isEmpty) return null;

    final phoneticBody = parsePhoneticTokens(pronunciation)
        .join()
        .replaceAll(RegExp(r'[-\^.·・]'), '');
    if (phoneticBody.isEmpty) return null;

    final totalUnits = _contentCharCount(targetText);
    if (totalUnits <= 0) return null;

    final clampedEnd = rangeEnd.clamp(0, targetText.length);
    final clampedStart = rangeStart.clamp(0, clampedEnd);
    final startUnits = _contentCharCount(targetText.substring(0, clampedStart));
    final endUnits = _contentCharCount(targetText.substring(0, clampedEnd));
    if (startUnits >= endUnits) return null;

    final phoneticLen = phoneticBody.length;
    final sliceStart = (startUnits / totalUnits * phoneticLen).floor();
    var sliceEnd = (endUnits / totalUnits * phoneticLen).ceil();
    if (sliceEnd <= sliceStart) sliceEnd = sliceStart + 1;
    sliceEnd = sliceEnd.clamp(0, phoneticLen);

    final slice = phoneticBody.substring(
      sliceStart.clamp(0, phoneticLen),
      sliceEnd,
    );
    return slice.isEmpty ? null : slice;
  }

  static int _contentCharCount(String text) =>
      text.replaceAll(_punct, '').replaceAll(RegExp(r'\s+'), '').length;

  /// [phoneticSliceForTargetRange]를 문장 전체가 아닌, [rangeStart,rangeEnd)를
  /// 포함하는 개별 lexicon 구문 하나로 좁혀서 슬라이스한다.
  ///
  /// 문장 전체 길이 비율로 슬라이스하면, 한 글자가 발음상 2음절 이상인
  /// 구문(예: `願` 한 글자 → `네가` 2음절)이 뒤쪽에 있을 때 그 오차가
  /// 앞쪽 구문 경계까지 새어 들어와 옆 단어 발음 일부가 섞여 보인다
  /// (예: 「ご搭乗」의 발음에 다음 단어 「券」의 첫 음절이 끼어듦).
  /// 구문 단위로 좁히면 오차가 그 구문 내부로만 갇힌다.
  static String? phoneticSliceScopedToLexiconPhrase({
    required List<CjkPhraseLexeme> lexicon,
    required int rangeStart,
    required int rangeEnd,
  }) {
    var offset = 0;
    for (final item in lexicon) {
      final start = offset;
      final end = offset + item.surface.length;
      if (rangeStart >= start &&
          rangeEnd <= end &&
          item.phonetic.trim().isNotEmpty) {
        return phoneticSliceForTargetRange(
          targetText: item.surface,
          pronunciation: item.phonetic,
          rangeStart: rangeStart - start,
          rangeEnd: rangeEnd - start,
        );
      }
      offset = end;
    }
    return null;
  }
}
