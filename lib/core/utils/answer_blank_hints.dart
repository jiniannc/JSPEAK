import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/hint_run_badge.dart';
import 'scenario_answer_compare.dart';
import 'word_compare.dart';
import 'word_token_alignment.dart';

/// 정답 문장을 글자 단위 언더라인으로 보여주고,
/// 인식/입력 텍스트와 순차 매칭해 맞은 글자는 공개·틀린 글자는 빨간색으로 표시한다.
///
/// [blankFrame]이 있고 구조 힌트가 켜지면 `____` 외 단어는 미리 공개되고,
/// 입력 매칭은 주요 단어(빈칸)에만 적용할 수 있다.
class AnswerBlankHints {
  AnswerBlankHints._();

  static final RegExp _stripPunct = RegExp(r'[.,!?;:"()\[\]…。、？！]');

  static bool isPunctuationChar(String char) =>
      char.isNotEmpty && char.replaceAll(_stripPunct, '').isEmpty;

  static String _wordCore(String word) {
    var end = word.length;
    while (end > 0 && isPunctuationChar(word[end - 1])) {
      end--;
    }
    return word.substring(0, end);
  }

  static String _trailingPunctuation(String word) {
    final chars = <String>[];
    for (var i = word.length - 1; i >= 0; i--) {
      final c = word[i];
      if (isPunctuationChar(c)) {
        chars.add(c);
      } else {
        break;
      }
    }
    return chars.reversed.join();
  }

  /// `____`, `____.`, `( )`, `（）`, 전각 밑줄 등 빈칸 표기.
  static final RegExp _blankPattern = RegExp(
    r'[_\uFF3F]{2,}[.,!?;:]?|\(\s*\)|（\s*）|\[\s*\]|〈\s*〉|[_\uFF3F]+',
  );
  static const _blankSentinel = '§BLANK§';

  /// blank_frame 안의 빈칸을 센티널로 통일.
  static String normalizeBlankFrame(String blankFrame) {
    return blankFrame.replaceAll(_blankPattern, ' $_blankSentinel ');
  }

  static bool _isBlankWord(String word) {
    final cleaned = word.replaceAll(_stripPunct, '').trim();
    if (cleaned == _blankSentinel) return true;
    if (cleaned.isEmpty) return false;
    return RegExp(r'^_+$').hasMatch(cleaned);
  }

  /// 화면에 그릴 슬롯 (단어 간격은 [isGap]).
  /// [isKey]는 blank_frame 기준 주요 단어(빈칸) 여부.
  static List<BlankLetter> displayLetters(
    String correct, {
    required String language,
    String blankFrame = '',
  }) {
    final keyFlags = keyLetterFlags(
      correct: correct,
      blankFrame: blankFrame,
      language: language,
    );
    final isCjk = language == 'Japanese' || language == 'Chinese';

    if (isCjk) {
      var keyWordCounter = -1;
      var inKeyRun = false;
      var letterIdx = 0;
      final out = <BlankLetter>[];
      for (final c in correct.split('')) {
        if (c.trim().isEmpty) continue;
        if (isPunctuationChar(c)) {
          inKeyRun = false;
          out.add(
            BlankLetter(char: c, isKey: false, isPunctuation: true),
          );
          continue;
        }
        final isKey = letterIdx < keyFlags.length ? keyFlags[letterIdx] : true;
        letterIdx++;
        if (isKey) {
          if (!inKeyRun) {
            keyWordCounter++;
            inKeyRun = true;
          }
          out.add(
            BlankLetter(
              char: c,
              isKey: true,
              keyWordIndex: keyWordCounter,
            ),
          );
        } else {
          inKeyRun = false;
          out.add(BlankLetter(char: c, isKey: false));
        }
      }
      return out;
    }

    final out = <BlankLetter>[];
    final words = correct.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var letterIndex = 0;
    var keyWordCounter = -1;
    var firstWord = true;
    for (final word in words) {
      if (!firstWord) out.add(const BlankLetter.gap());
      firstWord = false;

      final core = _wordCore(word);
      final trailing = _trailingPunctuation(word);
      final letters = core.split('').where((c) => c.isNotEmpty).toList();
      if (letters.isEmpty && trailing.isEmpty) continue;

      if (letters.isNotEmpty) {
        final wordIsKey =
            letterIndex < keyFlags.length && keyFlags[letterIndex];
        final keyIdx = wordIsKey ? (++keyWordCounter) : -1;
        for (final ch in letters) {
          out.add(
            BlankLetter(char: ch, isKey: wordIsKey, keyWordIndex: keyIdx),
          );
          letterIndex++;
        }
      }
      for (final p in trailing.split('')) {
        out.add(
          BlankLetter(char: p, isKey: false, isPunctuation: true),
        );
      }
    }
    return out;
  }

  /// 각 매칭 글자가 주요 단어(빈칸)인지.
  /// blank_frame이 비어 있거나 빈칸을 못 찾으면 모두 주요(미리 공개하지 않음).
  static List<bool> keyLetterFlags({
    required String correct,
    required String blankFrame,
    required String language,
  }) {
    final letters = _rawMatchLetters(correct, language: language);
    if (letters.isEmpty) return const [];
    if (blankFrame.trim().isEmpty) {
      return List<bool>.filled(letters.length, true);
    }

    final isCjk = language == 'Japanese' || language == 'Chinese';
    final flags = isCjk
        ? _cjkKeyFlags(correct, blankFrame, letters.length)
        : _englishKeyFlags(correct, blankFrame, letters.length);

    // 빈칸을 하나도 못 찾으면 전부 주요로 두어 힌트 시 전체 공개를 막는다.
    if (!flags.contains(true) || !flags.contains(false)) {
      return List<bool>.filled(letters.length, true);
    }
    return flags;
  }

  static List<bool> _englishKeyFlags(
    String correct,
    String blankFrame,
    int letterCount,
  ) {
    final correctWords = WordCompare.splitWords(correct);
    final frameWords = WordCompare.splitWords(normalizeBlankFrame(blankFrame));
    final wordIsKey = <bool>[];
    for (var i = 0; i < correctWords.length; i++) {
      if (i < frameWords.length && _isBlankWord(frameWords[i])) {
        wordIsKey.add(true);
      } else if (i < frameWords.length) {
        wordIsKey.add(false);
      } else {
        // 프레임보다 정답이 길면 남는 단어는 주요로 취급
        wordIsKey.add(true);
      }
    }

    // 프레임에 빈칸이 없으면 실패로 간주
    if (!wordIsKey.contains(true)) {
      return List<bool>.filled(letterCount, true);
    }

    final flags = <bool>[];
    for (var wi = 0; wi < correctWords.length; wi++) {
      final letters = correctWords[wi]
          .replaceAll(_stripPunct, '')
          .split('')
          .where((c) => c.isNotEmpty);
      for (final _ in letters) {
        flags.add(wi < wordIsKey.length ? wordIsKey[wi] : true);
      }
    }
    while (flags.length < letterCount) {
      flags.add(true);
    }
    return flags.take(letterCount).toList();
  }

  static List<bool> _cjkKeyFlags(
    String correct,
    String blankFrame,
    int letterCount,
  ) {
    final flags = List<bool>.filled(letterCount, false);
    final normalized = normalizeBlankFrame(blankFrame);
    final structureParts = normalized
        .split(_blankSentinel)
        .map(
          (p) => p.replaceAll(_stripPunct, '').replaceAll(RegExp(r'\s+'), ''),
        )
        .where((p) => p.isNotEmpty)
        .toList();

    final hasBlank =
        normalized.contains(_blankSentinel) ||
        RegExp(r'_+').hasMatch(blankFrame);
    if (!hasBlank || structureParts.isEmpty) {
      return List<bool>.filled(letterCount, true);
    }

    final normCorrect = correct
        .replaceAll(_stripPunct, '')
        .replaceAll(RegExp(r'\s+'), '');

    var cursor = 0;
    for (final part in structureParts) {
      final idx = normCorrect.indexOf(part, cursor);
      if (idx < 0) {
        return List<bool>.filled(letterCount, true);
      }
      for (var i = cursor; i < idx && i < letterCount; i++) {
        flags[i] = true;
      }
      cursor = idx + part.length;
    }
    for (var i = cursor; i < letterCount; i++) {
      flags[i] = true;
    }

    if (!flags.contains(true)) {
      return List<bool>.filled(letterCount, true);
    }
    return flags;
  }

  /// blank_frame에서 주요 단어(빈칸) 목록 — 입력·채점 단위.
  static List<String> extractKeyWordList({
    required String correct,
    required String blankFrame,
    required String language,
  }) {
    final display = displayLetters(
      correct,
      language: language,
      blankFrame: blankFrame,
    );
    final words = <String>[];
    final buf = StringBuffer();
    var currentIdx = -999;
    for (final d in display) {
      if (d.isGap || !d.isKey) {
        if (buf.isNotEmpty) {
          words.add(buf.toString());
          buf.clear();
          currentIdx = -999;
        }
        continue;
      }
      if (currentIdx != d.keyWordIndex && buf.isNotEmpty) {
        words.add(buf.toString());
        buf.clear();
      }
      currentIdx = d.keyWordIndex;
      buf.write(d.char);
    }
    if (buf.isNotEmpty) words.add(buf.toString());
    return words;
  }

  /// 연속된 주요 단어끼리 묶은 런. 예: [[0,1], [2]] = security work / understanding
  static List<List<int>> contiguousKeyRuns({
    required String correct,
    required String blankFrame,
    required String language,
  }) {
    final keys = extractKeyWordList(
      correct: correct,
      blankFrame: blankFrame,
      language: language,
    );
    if (keys.isEmpty) return const [];

    final display = displayLetters(
      correct,
      language: language,
      blankFrame: blankFrame,
    );

    bool adjacent(int a, int b) {
      var lastA = -1;
      var firstB = -1;
      for (var i = 0; i < display.length; i++) {
        final d = display[i];
        if (d.isGap) continue;
        if (d.isKey && d.keyWordIndex == a) lastA = i;
        if (d.isKey && d.keyWordIndex == b && firstB < 0) firstB = i;
      }
      if (lastA < 0 || firstB < 0 || firstB <= lastA) return false;
      for (var i = lastA + 1; i < firstB; i++) {
        final d = display[i];
        if (!d.isGap && !d.isKey) return false;
      }
      return true;
    }

    final runs = <List<int>>[];
    var current = <int>[0];
    for (var i = 1; i < keys.length; i++) {
      if (adjacent(i - 1, i)) {
        current.add(i);
      } else {
        runs.add(current);
        current = [i];
      }
    }
    runs.add(current);
    return runs;
  }

  /// 런에 해당하는 정답 문구 (공백 연결).
  static String runAnswerText({
    required String correct,
    required String blankFrame,
    required String language,
    required List<int> keyIndices,
  }) {
    final keys = extractKeyWordList(
      correct: correct,
      blankFrame: blankFrame,
      language: language,
    );
    return [
      for (final i in keyIndices)
        if (i >= 0 && i < keys.length) keys[i],
    ].join(' ');
  }

  /// blank_frame에서 주요 단어(빈칸에 해당하는 정답 조각)만 이어 붙인 문자열.
  static String extractKeyAnswer({
    required String correct,
    required String blankFrame,
    required String language,
  }) => extractKeyWordList(
    correct: correct,
    blankFrame: blankFrame,
    language: language,
  ).join();

  /// [displayLetters] 슬롯이 속하는 가라오케 토큰 인덱스.
  /// 영어는 단어, CJK는 글자(공백 제외) 단위.
  static int karaokeTokenIndexForLetter({
    required List<BlankLetter> letters,
    required int letterIndex,
    required String language,
  }) {
    if (letterIndex <= 0 || letters.isEmpty) return 0;
    final last = letterIndex.clamp(0, letters.length - 1);
    if (WordCompare.isCjkLanguage(language)) {
      var idx = 0;
      for (var i = 0; i < last; i++) {
        if (!letters[i].isGap) idx++;
      }
      return idx;
    }
    var idx = 0;
    for (var i = 0; i < last; i++) {
      if (letters[i].isGap) idx++;
    }
    return idx;
  }

  static List<String> _rawMatchLetters(
    String text, {
    required String language,
  }) {
    final normalized = ScenarioAnswerCompare.normalize(text, language: language);
    return normalized.split('').where((c) => c.isNotEmpty).toList();
  }

  /// 매칭용 글자 스트림 (공백·문장부호 제거, 소문자).
  static List<String> matchLetters(String text, {required String language}) =>
      _rawMatchLetters(text, language: language);

  /// 빈칸 힌트 입력 — 영어는 단어 사이 공백을 제거해 'Could you'를 이어 붙여 비교.
  static List<String> _spokenLettersForBlankMatch(
    String text, {
    required String language,
  }) {
    final letters = matchLetters(text, language: language);
    if (language == 'English') {
      return letters.where((c) => c.trim().isNotEmpty).toList();
    }
    return letters;
  }

  /// 각 표시 슬롯의 상태.
  ///
  /// [structureRevealed]면 비주요 글자는 미리 공개.
  /// [keyRuns] + [blankRunInputs]면 연속 빈칸 런 단위로 매칭.
  static List<BlankLetterState> letterStates({
    required String correct,
    required String spoken,
    required String language,
    String blankFrame = '',
    bool structureRevealed = false,
    List<String>? blankInputs,
    List<List<int>>? keyRuns,
    List<String>? blankRunInputs,
    bool keyboardTyping = false,
  }) {
    final display = displayLetters(
      correct,
      language: language,
      blankFrame: blankFrame,
    );

    final adjustedSpoken = language == 'Japanese'
        ? ScenarioAnswerCompare.preprocessSpoken(spoken, language: language)
        : spoken;

    final matchChars = <String>[];
    final isKeyMatch = <bool>[];
    final keyWordOf = <int>[];
    final displayToMatch = <int?>[];
    for (final d in display) {
      if (d.isGap) {
        displayToMatch.add(null);
      } else if (d.isPunctuation) {
        displayToMatch.add(null);
      } else {
        displayToMatch.add(matchChars.length);
        matchChars.add(
          ScenarioAnswerCompare.normalize(d.char, language: language),
        );
        isKeyMatch.add(d.isKey);
        keyWordOf.add(d.keyWordIndex);
      }
    }

    final structureActive =
        structureRevealed &&
        isKeyMatch.contains(true) &&
        isKeyMatch.contains(false);

    final matchStates = List<BlankLetterState>.generate(matchChars.length, (i) {
      if (structureActive && !isKeyMatch[i]) {
        return BlankLetterState.structure(matchChars[i]);
      }
      return const BlankLetterState.blank();
    });

    void matchAgainst(
      List<int> indices,
      String input, {
      bool englishWordAligned = false,
    }) {
      if (indices.isEmpty) return;
      final fixedInput = language == 'Japanese'
          ? ScenarioAnswerCompare.preprocessSpoken(input, language: language)
          : input;
      final spokenMatch = _spokenLettersForBlankMatch(
        fixedInput,
        language: language,
      );
      final targetChars = [for (final i in indices) matchChars[i]];

      if (language == 'English') {
        if (englishWordAligned) {
          _matchEnglishWordAligned(
            indices: indices,
            matchChars: matchChars,
            matchStates: matchStates,
            spoken: fixedInput,
            correct: correct,
            blankFrame: blankFrame,
          );
          return;
        }
        // 타이핑 힌트: LCS(부분수열) 대신 왼쪽부터 순차 접두사.
        for (var ti = 0; ti < targetChars.length; ti++) {
          if (ti >= spokenMatch.length) break;
          if (ScenarioAnswerCompare.charsEquivalentForCompare(
            spokenMatch[ti],
            targetChars[ti],
            language,
          )) {
            matchStates[indices[ti]] = BlankLetterState.correct(targetChars[ti]);
          } else {
            if (keyboardTyping) {
              matchStates[indices[ti]] =
                  BlankLetterState.wrong(spokenMatch[ti]);
            } else {
              break;
            }
          }
        }
        return;
      }

      if (keyboardTyping) {
        for (var ti = 0; ti < targetChars.length; ti++) {
          if (ti >= spokenMatch.length) break;
          if (ScenarioAnswerCompare.charsEquivalentForCompare(
            spokenMatch[ti],
            targetChars[ti],
            language,
          )) {
            matchStates[indices[ti]] =
                BlankLetterState.correct(targetChars[ti]);
          } else {
            matchStates[indices[ti]] =
                BlankLetterState.wrong(spokenMatch[ti]);
          }
        }
        return;
      }

      final alignment = ScenarioAnswerCompare.alignLetterLists(
        spokenLetters: spokenMatch,
        correctLetters: targetChars,
        language: language,
      );

      for (var ti = 0; ti < targetChars.length; ti++) {
        if (!alignment.correctMatched[ti]) continue;
        matchStates[indices[ti]] = BlankLetterState.correct(targetChars[ti]);
      }
    }

    if (structureActive &&
        keyRuns != null &&
        blankRunInputs != null &&
        keyRuns.isNotEmpty) {
      for (var r = 0; r < keyRuns.length; r++) {
        final wordIdxs = keyRuns[r];
        final indices = <int>[
          for (var i = 0; i < matchChars.length; i++)
            if (isKeyMatch[i] && wordIdxs.contains(keyWordOf[i])) i,
        ];
        matchAgainst(
          indices,
          r < blankRunInputs.length ? blankRunInputs[r] : '',
        );
      }
    } else if (structureActive && blankInputs != null) {
      final byWord = <int, List<int>>{};
      for (var i = 0; i < matchChars.length; i++) {
        if (!isKeyMatch[i]) continue;
        byWord.putIfAbsent(keyWordOf[i], () => []).add(i);
      }
      for (final entry in byWord.entries) {
        final wi = entry.key;
        matchAgainst(
          entry.value,
          wi >= 0 && wi < blankInputs.length ? blankInputs[wi] : '',
        );
      }
    } else if (keyboardTyping && language == 'English') {
      _matchEnglishKeyboardTyping(
        matchChars: matchChars,
        matchStates: matchStates,
        spoken: adjustedSpoken,
        correct: correct,
        blankFrame: blankFrame,
      );
    } else {
      matchAgainst(
        [
          for (var i = 0; i < matchChars.length; i++)
            if (!structureActive || isKeyMatch[i]) i,
        ],
        adjustedSpoken,
        englishWordAligned: language == 'English',
      );
    }

    return [
      for (var i = 0; i < display.length; i++)
        if (display[i].isGap)
          const BlankLetterState.blank()
        else if (display[i].isPunctuation)
          BlankLetterState.structure(display[i].char)
        else
          matchStates[displayToMatch[i]!],
    ];
  }

  /// 언더라인 슬롯 + 상태 (틀린 영어 단어 overflow 칸 포함).
  static BlankHintLayout layout({
    required String correct,
    required String spoken,
    required String language,
    String blankFrame = '',
    bool structureRevealed = false,
    List<String>? blankInputs,
    List<List<int>>? keyRuns,
    List<String>? blankRunInputs,
    bool keyboardTyping = false,
  }) {
    final letters = displayLetters(
      correct,
      language: language,
      blankFrame: blankFrame,
    );
    final states = letterStates(
      correct: correct,
      spoken: spoken,
      language: language,
      blankFrame: blankFrame,
      structureRevealed: structureRevealed,
      blankInputs: blankInputs,
      keyRuns: keyRuns,
      blankRunInputs: blankRunInputs,
      keyboardTyping: keyboardTyping,
    );
    if (language != 'English' ||
        spoken.trim().isEmpty ||
        (structureRevealed && blankRunInputs != null)) {
      return BlankHintLayout(letters: letters, states: states);
    }
    if (keyboardTyping) {
      return _expandEnglishKeyboardOverflow(
        letters: letters,
        states: states,
        spoken: spoken,
        correct: correct,
      );
    }
    return _expandEnglishWrongOverflow(
      letters: letters,
      states: states,
      spoken: spoken,
      correct: correct,
    );
  }

  /// 틀린 영어 단어가 정답보다 길면 해당 단어 뒤에 overflow 슬롯 추가.
  static BlankHintLayout _expandEnglishWrongOverflow({
    required List<BlankLetter> letters,
    required List<BlankLetterState> states,
    required String spoken,
    required String correct,
  }) {
    final alignment = _englishWordBlankAlignment(
      correct: correct,
      spoken: spoken,
    );
    final expandedLetters = <BlankLetter>[];
    final expandedStates = <BlankLetterState>[];

    var wordIdx = 0;
    var i = 0;
    while (i < letters.length) {
      if (letters[i].isGap) {
        expandedLetters.add(letters[i]);
        expandedStates.add(states[i]);
        i++;
        continue;
      }

      final wordStart = i;
      while (i < letters.length && !letters[i].isGap) {
        expandedLetters.add(letters[i]);
        expandedStates.add(states[i]);
        i++;
      }
      var coreEnd = i;
      while (coreEnd > wordStart && letters[coreEnd - 1].isPunctuation) {
        coreEnd--;
      }
      final wordSlotCount = coreEnd - wordStart;
      final info = alignment[wordIdx];

      if (info != null &&
          info.kind == _EnglishWordBlankKind.wrong &&
          info.spokenWord != null) {
        final spokenLetters = matchLetters(info.spokenWord!, language: 'English')
            .where((c) => c.trim().isNotEmpty)
            .toList();
        if (spokenLetters.length > wordSlotCount) {
          final template = letters[wordStart];
          for (var oi = wordSlotCount; oi < spokenLetters.length; oi++) {
            expandedLetters.add(
              BlankLetter(
                char: spokenLetters[oi],
                isKey: template.isKey,
                keyWordIndex: template.keyWordIndex,
                isOverflow: true,
              ),
            );
            expandedStates.add(
              BlankLetterState.wrong(spokenLetters[oi]),
            );
          }
        }
      }
      wordIdx++;
    }

    return BlankHintLayout(letters: expandedLetters, states: expandedStates);
  }

  /// displayLetters 기준 단어 인덱스 → matchChars 인덱스 목록.
  static Map<int, List<int>> _englishWordToMatchIndices({
    required String correct,
    String blankFrame = '',
  }) {
    final display = displayLetters(
      correct,
      language: 'English',
      blankFrame: blankFrame,
    );
    final wordToMatchIndices = <int, List<int>>{};
    var matchIdx = 0;
    var wordIdx = 0;
    for (final d in display) {
      if (d.isGap) {
        wordIdx++;
        continue;
      }
      if (!d.isPunctuation) {
        wordToMatchIndices.putIfAbsent(wordIdx, () => []).add(matchIdx);
        matchIdx++;
      }
    }
    return wordToMatchIndices;
  }

  /// 키보드 타이핑 — 단어 N은 정답 단어 N과만 1:1, 글자 단위 피드백.
  static void _matchEnglishKeyboardTyping({
    required List<String> matchChars,
    required List<BlankLetterState> matchStates,
    required String spoken,
    required String correct,
    String blankFrame = '',
  }) {
    final spokenWords = WordCompare.splitWords(spoken);
    if (spokenWords.isEmpty) return;

    final correctWords = WordCompare.splitWords(correct);
    final wordToMatchIndices = _englishWordToMatchIndices(
      correct: correct,
      blankFrame: blankFrame,
    );

    for (var wi = 0; wi < spokenWords.length; wi++) {
      final charIndices = wordToMatchIndices[wi];
      if (charIndices == null || charIndices.isEmpty) continue;

      final spokenLetters = matchLetters(spokenWords[wi], language: 'English')
          .where((c) => c.trim().isNotEmpty)
          .toList();
      final wordFullyMatched = wi < correctWords.length &&
          WordCompare.normalize(spokenWords[wi]) ==
              WordCompare.normalize(correctWords[wi]);

      if (wordFullyMatched) {
        for (final mi in charIndices) {
          matchStates[mi] = BlankLetterState.correct(matchChars[mi]);
        }
        continue;
      }

      for (var ci = 0;
          ci < spokenLetters.length && ci < charIndices.length;
          ci++) {
        final mi = charIndices[ci];
        final targetChar = matchChars[mi];
        final spokenChar = spokenLetters[ci];
        if (ScenarioAnswerCompare.charsEquivalentForCompare(
          spokenChar,
          targetChar,
          'English',
        )) {
          matchStates[mi] = BlankLetterState.correct(targetChar);
        } else {
          matchStates[mi] = BlankLetterState.wrong(spokenChar);
        }
      }
    }
  }

  /// 키보드 타이핑 — 정답보다 긴 오타 단어 overflow 슬롯.
  static BlankHintLayout _expandEnglishKeyboardOverflow({
    required List<BlankLetter> letters,
    required List<BlankLetterState> states,
    required String spoken,
    required String correct,
  }) {
    final spokenWords = WordCompare.splitWords(spoken);
    final correctWords = WordCompare.splitWords(correct);
    final expandedLetters = <BlankLetter>[];
    final expandedStates = <BlankLetterState>[];

    var wordIdx = 0;
    var i = 0;
    while (i < letters.length) {
      if (letters[i].isGap) {
        expandedLetters.add(letters[i]);
        expandedStates.add(states[i]);
        i++;
        continue;
      }

      final wordStart = i;
      while (i < letters.length && !letters[i].isGap) {
        expandedLetters.add(letters[i]);
        expandedStates.add(states[i]);
        i++;
      }
      var coreEnd = i;
      while (coreEnd > wordStart && letters[coreEnd - 1].isPunctuation) {
        coreEnd--;
      }
      final wordSlotCount = coreEnd - wordStart;

      if (wordIdx < spokenWords.length) {
        final spokenLetters =
            matchLetters(spokenWords[wordIdx], language: 'English')
                .where((c) => c.trim().isNotEmpty)
                .toList();
        final fullyMatched = wordIdx < correctWords.length &&
            WordCompare.normalize(spokenWords[wordIdx]) ==
                WordCompare.normalize(correctWords[wordIdx]);

        if (!fullyMatched && spokenLetters.length > wordSlotCount) {
          final template = letters[wordStart];
          for (var oi = wordSlotCount; oi < spokenLetters.length; oi++) {
            expandedLetters.add(
              BlankLetter(
                char: spokenLetters[oi],
                isKey: template.isKey,
                keyWordIndex: template.keyWordIndex,
                isOverflow: true,
              ),
            );
            expandedStates.add(
              BlankLetterState.wrong(spokenLetters[oi]),
            );
          }
        }
      }
      wordIdx++;
    }

    return BlankHintLayout(letters: expandedLetters, states: expandedStates);
  }

  /// 정답 단어 인덱스별 STT 매칭 — 생략(deletion)·치환·부분 인식 포함.
  static Map<int, _EnglishWordBlankInfo> _englishWordBlankAlignment({
    required String correct,
    required String spoken,
  }) {
    final correctWords = WordCompare.splitWords(correct);
    final spokenWords = WordCompare.splitWords(spoken);
    if (correctWords.isEmpty || spokenWords.isEmpty) return {};

    final alignment = WordTokenAligner.align(
      targetWords: correctWords,
      spokenWords: spokenWords,
      language: 'English',
    );

    final result = <int, _EnglishWordBlankInfo>{};
    var targetIdx = 0;
    for (final op in alignment.ops) {
      switch (op.kind) {
        case WordAlignmentKind.match:
          result[targetIdx] = _EnglishWordBlankInfo(
            kind: _EnglishWordBlankKind.matched,
            spokenWord: op.spokenWord,
          );
          targetIdx++;
        case WordAlignmentKind.substitution:
          final spokenWord = op.spokenWord ?? '';
          final targetWord = op.targetWord ?? '';
          final normSpoken = WordCompare.normalize(spokenWord);
          final normTarget = WordCompare.normalize(targetWord);
          if (normTarget.startsWith(normSpoken) && normSpoken.isNotEmpty) {
            result[targetIdx] = _EnglishWordBlankInfo(
              kind: _EnglishWordBlankKind.partial,
              spokenWord: spokenWord,
            );
          } else {
            result[targetIdx] = _EnglishWordBlankInfo(
              kind: _EnglishWordBlankKind.wrong,
              spokenWord: spokenWord,
            );
          }
          targetIdx++;
        case WordAlignmentKind.deletion:
          targetIdx++;
        case WordAlignmentKind.insertion:
          break;
      }
    }

    // 라이브 STT: 마지막 토큰이 다음 정답 단어의 접두사면 부분 일치.
    if (targetIdx < correctWords.length) {
      final lastSpoken = spokenWords.last;
      final normSpoken = WordCompare.normalize(lastSpoken);
      final normTarget = WordCompare.normalize(correctWords[targetIdx]);
      final existing = result[targetIdx];
      if (normTarget.startsWith(normSpoken) &&
          normSpoken.isNotEmpty &&
          normSpoken != normTarget &&
          (existing == null || existing.kind != _EnglishWordBlankKind.matched)) {
        result[targetIdx] = _EnglishWordBlankInfo(
          kind: _EnglishWordBlankKind.partial,
          spokenWord: lastSpoken,
        );
      }
    }

    return result;
  }

  /// 영어 STT 오답 유형 — 가이드 멘트 분기용.
  static EnglishSpeakingWrongKind classifyEnglishSpeakingWrong({
    required String correct,
    required String spoken,
  }) {
    final correctWords = WordCompare.splitWords(correct);
    final spokenWords = WordCompare.splitWords(spoken);
    if (correctWords.isEmpty || spokenWords.isEmpty) {
      return EnglishSpeakingWrongKind.mispronunciation;
    }

    final alignment = WordTokenAligner.align(
      targetWords: correctWords,
      spokenWords: spokenWords,
      language: 'English',
    );

    final matchedCorrect = <int>{};
    final wrongCorrect = <int>{};
    final omittedCorrect = <int>{};
    var targetIdx = 0;
    for (final op in alignment.ops) {
      switch (op.kind) {
        case WordAlignmentKind.match:
          matchedCorrect.add(targetIdx);
          targetIdx++;
        case WordAlignmentKind.substitution:
          final spokenWord = op.spokenWord ?? '';
          final targetWord = op.targetWord ?? '';
          final normSpoken = WordCompare.normalize(spokenWord);
          final normTarget = WordCompare.normalize(targetWord);
          if (normTarget.startsWith(normSpoken) && normSpoken.isNotEmpty) {
            matchedCorrect.add(targetIdx);
          } else {
            wrongCorrect.add(targetIdx);
          }
          targetIdx++;
        case WordAlignmentKind.deletion:
          omittedCorrect.add(targetIdx);
          targetIdx++;
        case WordAlignmentKind.insertion:
          break;
      }
    }

    if (wrongCorrect.isNotEmpty) {
      return EnglishSpeakingWrongKind.mispronunciation;
    }
    if (omittedCorrect.isEmpty) {
      return EnglishSpeakingWrongKind.mispronunciation;
    }

    final hasMatchAfterOmission = omittedCorrect.any(
      (o) => matchedCorrect.any((m) => m > o),
    );
    if (!hasMatchAfterOmission) {
      return EnglishSpeakingWrongKind.incompleteEnding;
    }
    return EnglishSpeakingWrongKind.omittedWord;
  }

  /// STT·발음 피드백 — 단어 정렬 후 맞으면 공개·틀리면 빨간색(발화 글자).
  static void _matchEnglishWordAligned({
    required List<int> indices,
    required List<String> matchChars,
    required List<BlankLetterState> matchStates,
    required String spoken,
    required String correct,
    String blankFrame = '',
  }) {
    if (WordCompare.splitWords(spoken).isEmpty) return;

    final alignment = _englishWordBlankAlignment(
      correct: correct,
      spoken: spoken,
    );

    final display = displayLetters(
      correct,
      language: 'English',
      blankFrame: blankFrame,
    );
    final indexSet = indices.toSet();

    final wordToMatchIndices = <int, List<int>>{};
    var matchIdx = 0;
    var wordIdx = 0;
    for (final d in display) {
      if (d.isGap) {
        wordIdx++;
        continue;
      }
      if (indexSet.contains(matchIdx)) {
        wordToMatchIndices.putIfAbsent(wordIdx, () => []).add(matchIdx);
      }
      matchIdx++;
    }

    for (final entry in wordToMatchIndices.entries) {
      final wi = entry.key;
      final charIndices = entry.value;
      if (charIndices.isEmpty) continue;

      final info = alignment[wi];
      if (info == null || info.spokenWord == null) continue;

      switch (info.kind) {
        case _EnglishWordBlankKind.matched:
          for (final i in charIndices) {
            matchStates[i] = BlankLetterState.correct(matchChars[i]);
          }
        case _EnglishWordBlankKind.partial:
          final normSpoken = WordCompare.normalize(info.spokenWord!);
          for (var ci = 0;
              ci < normSpoken.length && ci < charIndices.length;
              ci++) {
            matchStates[charIndices[ci]] =
                BlankLetterState.correct(matchChars[charIndices[ci]]);
          }
        case _EnglishWordBlankKind.wrong:
          final spokenLetters = matchLetters(info.spokenWord!, language: 'English')
              .where((c) => c.trim().isNotEmpty)
              .toList();
          for (var ci = 0;
              ci < charIndices.length && ci < spokenLetters.length;
              ci++) {
            matchStates[charIndices[ci]] =
                BlankLetterState.wrong(spokenLetters[ci]);
          }
      }
    }
  }
}

enum _EnglishWordBlankKind { matched, partial, wrong }

enum EnglishSpeakingWrongKind {
  /// 틀린 단어(치환) — 빨간색 표시.
  mispronunciation,
  /// 중간 단어 누락 — 빈칸.
  omittedWord,
  /// 문장 끝까지 말하지 못함(타임아웃 등).
  incompleteEnding,
}

class _EnglishWordBlankInfo {
  final _EnglishWordBlankKind kind;
  final String? spokenWord;

  const _EnglishWordBlankInfo({
    required this.kind,
    this.spokenWord,
  });
}

class BlankHintLayout {
  final List<BlankLetter> letters;
  final List<BlankLetterState> states;

  const BlankHintLayout({
    required this.letters,
    required this.states,
  });
}

class BlankLetter {
  final String char;
  final bool isGap;
  final bool isKey;
  final bool isOverflow;
  final bool isPunctuation;

  /// 주요 단어(빈칸) 순번. 구조/간격은 -1.
  final int keyWordIndex;

  const BlankLetter({
    required this.char,
    this.isKey = true,
    this.keyWordIndex = -1,
    this.isOverflow = false,
    this.isPunctuation = false,
  }) : isGap = false;

  const BlankLetter.gap()
    : char = '',
      isGap = true,
      isKey = false,
      isOverflow = false,
      isPunctuation = false,
      keyWordIndex = -1;
}

class BlankLetterState {
  final BlankRevealKind kind;
  final String? shown;

  const BlankLetterState._(this.kind, this.shown);

  const BlankLetterState.blank() : this._(BlankRevealKind.blank, null);
  const BlankLetterState.correct(String char)
    : this._(BlankRevealKind.correct, char);
  const BlankLetterState.wrong(String char)
    : this._(BlankRevealKind.wrong, char);
  const BlankLetterState.structure(String char)
    : this._(BlankRevealKind.structure, char);
}

enum BlankRevealKind { blank, correct, wrong, structure }

/// 언어별 빈칸 슬롯·간격 — 힌트/정답 공개 전후 레이아웃 폭을 맞춘다.
class BlankLayoutSpec {
  final double letterGap;
  final double groupGap;
  final double minSlotWidth;
  final double maxSlotWidth;
  final String blankPlaceholder;

  const BlankLayoutSpec({
    required this.letterGap,
    required this.groupGap,
    required this.minSlotWidth,
    required this.maxSlotWidth,
    required this.blankPlaceholder,
  });

  static bool isCjk(String language) =>
      language == 'Japanese' || language == 'Chinese';

  static BlankLayoutSpec forLanguage(String language, double fontSize) {
    if (isCjk(language)) {
      return BlankLayoutSpec(
        letterGap: fontSize * 0.14,
        groupGap: fontSize * 0.36,
        minSlotWidth: fontSize * 0.98,
        maxSlotWidth: fontSize * 1.35,
        blankPlaceholder: '＿',
      );
    }
    return BlankLayoutSpec(
      letterGap: 1.0,
      groupGap: 8.0,
      minSlotWidth: 8.0,
      maxSlotWidth: fontSize * 1.15,
      blankPlaceholder: '_',
    );
  }
}

/// [AnswerBlankHintView]와 동일한 폭 계산 (테스트·프리레이아웃용).
class AnswerBlankHintMetrics {
  AnswerBlankHintMetrics._();

  static TextStyle letterStyle(double fontSize) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1,
      );

  static double measureTextWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  static double charSlotWidth({
    required String char,
    required String language,
    required double fontSize,
  }) {
    final spec = BlankLayoutSpec.forLanguage(language, fontSize);
    final style = letterStyle(fontSize);
    final sample = char.isEmpty
        ? (BlankLayoutSpec.isCjk(language) ? '国' : 'x')
        : char;
    final charW = measureTextWidth(sample, style);
    final placeW = measureTextWidth(spec.blankPlaceholder, style);
    return (charW > placeW ? charW : placeW)
        .clamp(spec.minSlotWidth, spec.maxSlotWidth);
  }
}

/// 언더라인 힌트 — [maxWidth] 안에서 단어 그룹 단위로 줄바꿈.
class AnswerBlankHintView extends StatefulWidget {
  final String correctSentence;
  final String spokenText;
  final String language;
  final Color accentColor;
  final Color? blankColor;
  final double fontSize;
  final String blankFrame;
  final bool structureRevealed;
  final double? maxWidth;
  final List<String> blankInputs;
  final int? selectedBlankIndex;
  final ValueChanged<int>? onBlankTap;
  final bool showHintRunLabels;
  final bool keyboardTyping;
  /// TTS 가라오케 — 현재 읽고 있는 토큰. null이면 비활성.
  final int? karaokeTokenIndex;
  /// 힌트 공개 후 빈칸 영역을 한 번 강조하는 트리거.
  final int attentionToken;

  const AnswerBlankHintView({
    super.key,
    required this.correctSentence,
    required this.spokenText,
    required this.language,
    required this.accentColor,
    this.blankColor,
    this.fontSize = 16,
    this.blankFrame = '',
    this.structureRevealed = false,
    this.maxWidth,
    this.blankInputs = const [],
    this.selectedBlankIndex,
    this.onBlankTap,
    this.showHintRunLabels = false,
    this.keyboardTyping = false,
    this.karaokeTokenIndex,
    this.attentionToken = 0,
  });

  @override
  State<AnswerBlankHintView> createState() => _AnswerBlankHintViewState();
}

class _AnswerBlankHintViewState extends State<AnswerBlankHintView>
    with TickerProviderStateMixin {
  static const Color _runBorderColor = Color(0xFFFF8F00);
  /// 테두리를 레이아웃 안쪽에 두어 Clip/말풍선에 잘리지 않게 함.
  static const double _borderInset = 4.0;

  /// 줄 사이 간격.
  static const double _lineGap = 6.0;
  /// 측정 폭 vs 실제 렌더(폰트·테두리·가ra오케) 오차 흡수.
  static const double _linePackSlack = 8.0;

  late final AnimationController _pulse;
  late final AnimationController _revealController;
  late final AnimationController _blankFlashController;
  late final AnimationController _attentionController;

  List<int>? _structureRevealOrder;
  bool _structureRevealComplete = false;

  BlankLayoutSpec get _layout =>
      BlankLayoutSpec.forLanguage(widget.language, widget.fontSize);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _revealController = AnimationController(vsync: this);
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _structureRevealComplete = true);
      }
    });
    _blankFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (widget.structureRevealed) {
      _beginStructureReveal();
    } else if (widget.karaokeTokenIndex != null) {
      _pulse.repeat(reverse: true);
    }
    if (widget.attentionToken > 0) {
      _attentionController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant AnswerBlankHintView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.structureRevealed && !oldWidget.structureRevealed) {
      _beginStructureReveal();
    } else if (!widget.structureRevealed && oldWidget.structureRevealed) {
      _structureRevealOrder = null;
      _structureRevealComplete = false;
      _revealController
        ..stop()
        ..value = 0;
      _blankFlashController
        ..stop()
        ..value = 0;
    }
    if (widget.attentionToken != oldWidget.attentionToken) {
      _blankFlashController.forward(from: 0);
      _attentionController.forward(from: 0);
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    }

    final karaokeOn = widget.karaokeTokenIndex != null;
    if ((widget.structureRevealed || karaokeOn) && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.structureRevealed && !karaokeOn && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _beginStructureReveal() {
    final layout = AnswerBlankHints.layout(
      correct: widget.correctSentence,
      spoken: widget.spokenText,
      language: widget.language,
      blankFrame: widget.blankFrame,
      structureRevealed: true,
      keyRuns: AnswerBlankHints.contiguousKeyRuns(
        correct: widget.correctSentence,
        blankFrame: widget.blankFrame,
        language: widget.language,
      ),
      keyboardTyping: widget.keyboardTyping,
    );

    final order = <int>[];
    for (var i = 0; i < layout.states.length; i++) {
      if (layout.states[i].kind == BlankRevealKind.structure) {
        order.add(i);
      }
    }
    order.shuffle(math.Random());

    _structureRevealOrder = order;
    _structureRevealComplete = order.isEmpty;
    _revealController.duration = Duration(
      milliseconds: (380 + order.length * 62).clamp(380, 2600),
    );
    _revealController.forward(from: 0);
    _blankFlashController.forward(from: 0);
    _pulse.repeat(reverse: true);
  }

  double _letterRevealT(int letterIndex, BlankLetterState state) {
    if (state.kind != BlankRevealKind.structure) return 1.0;
    if (_structureRevealComplete) return 1.0;
    final order = _structureRevealOrder;
    if (order == null || order.isEmpty) return 1.0;

    final pos = order.indexOf(letterIndex);
    if (pos < 0) return 1.0;

    const slot = 0.11;
    final start = pos / order.length * (1.0 - slot);
    final t = _revealController.value;
    if (t <= start) return 0.0;
    return ((t - start) / slot).clamp(0.0, 1.0);
  }

  bool _isDimmedKeyBlank(int keyWordIndex) {
    final selected = widget.selectedBlankIndex;
    if (selected == null || keyWordIndex < 0) return false;
    return selected != keyWordIndex;
  }

  _KaraokeLetterRole _karaokeRoleFor(List<BlankLetter> letters, int letterIndex) {
    final active = widget.karaokeTokenIndex;
    if (active == null) return _KaraokeLetterRole.none;
    final token = AnswerBlankHints.karaokeTokenIndexForLetter(
      letters: letters,
      letterIndex: letterIndex,
      language: widget.language,
    );
    if (token < active) return _KaraokeLetterRole.past;
    if (token == active) return _KaraokeLetterRole.current;
    return _KaraokeLetterRole.upcoming;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _revealController.dispose();
    _blankFlashController.dispose();
    _attentionController.dispose();
    super.dispose();
  }

  TextStyle get _letterStyle => TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w800,
        height: 1,
      );

  double get _slotH => widget.fontSize + 10;

  double _charSlotWidth(String char) {
    return AnswerBlankHintMetrics.charSlotWidth(
      char: char,
      language: widget.language,
      fontSize: widget.fontSize,
    );
  }

  /// 틀린 글자는 발화 문자 폭, 그 외는 정답 문자 폭.
  double _slotWidthFor(
    int letterIdx,
    List<BlankLetter> letters,
    List<BlankLetterState> states,
  ) {
    if (letterIdx < states.length &&
        states[letterIdx].kind == BlankRevealKind.wrong) {
      final shown = states[letterIdx].shown;
      if (shown != null && shown.isNotEmpty) {
        return _charSlotWidth(shown);
      }
    }
    return _charSlotWidth(letters[letterIdx].char);
  }

  double _visualGroupWidth(
    List<BlankLetter> letters,
    List<BlankLetterState> states,
    _VisualGroup group,
  ) {
    var w = 0.0;
    var inWord = false;
    for (final idx in group.items) {
      if (idx == null) {
        w += _layout.groupGap;
        inWord = false;
        continue;
      }
      if (inWord) w += _layout.letterGap;
      w += _slotWidthFor(idx, letters, states);
      inWord = true;
    }
    // 빈칸 런은 힌트 여부와 무관하게 테두리 폭 예약
    if (group.isKeyRun) {
      w += _borderInset * 2 + 4; // border width 2px × 2 sides
    }
    return w;
  }

  double measureWidth(
    List<BlankLetter> letters,
    List<BlankLetterState> states,
    List<_VisualGroup> groups,
  ) {
    var w = 0.0;
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) w += _layout.groupGap;
      w += _visualGroupWidth(letters, states, groups[g]);
    }
    return w;
  }

  /// 단어(빈칸 런) 경계에서만 줄바꿈 — [maxWidth]가 없으면 한 줄로 유지.
  /// Row 기반이라 intrinsic width가 실제 필요한 폭 그대로 부모에 보고됨
  /// (Wrap은 intrinsic width를 "가장 넓은 그룹" 정도로만 보고해 IntrinsicWidth
  /// 부모가 있을 때 불필요하게 좁게 잡혀 과도한 줄바꿈이 생김).
  List<List<_VisualGroup>> _packGroupsIntoLines(
    List<BlankLetter> letters,
    List<BlankLetterState> states,
    List<_VisualGroup> groups,
    double? maxWidth,
  ) {
    if (groups.isEmpty || maxWidth == null || !maxWidth.isFinite) {
      return [groups];
    }

    final budget = math.max(0.0, maxWidth - _linePackSlack);
    final lines = <List<_VisualGroup>>[];
    var currentLine = <_VisualGroup>[];
    var currentW = 0.0;

    for (final group in groups) {
      final groupW = _visualGroupWidth(letters, states, group);
      final gap = currentLine.isEmpty ? 0.0 : _layout.groupGap;
      final needed = gap + groupW;

      if (currentLine.isNotEmpty && currentW + needed > budget) {
        lines.add(currentLine);
        currentLine = [group];
        currentW = groupW;
      } else {
        currentW += needed;
        currentLine.add(group);
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final keyRuns = AnswerBlankHints.contiguousKeyRuns(
      correct: widget.correctSentence,
      blankFrame: widget.blankFrame,
      language: widget.language,
    );
    final layout = AnswerBlankHints.layout(
      correct: widget.correctSentence,
      spoken: widget.spokenText,
      language: widget.language,
      blankFrame: widget.blankFrame,
      structureRevealed: widget.structureRevealed,
      keyRuns: keyRuns,
      blankRunInputs: widget.structureRevealed &&
              widget.selectedBlankIndex != null
          ? widget.blankInputs
          : null,
      keyboardTyping: widget.keyboardTyping,
    );
    final letters = layout.letters;
    final states = layout.states;
    final muted =
        widget.blankColor ?? widget.accentColor.withValues(alpha: 0.35);
    final groups = _visualGroups(letters, keyRuns);
    final lines = _packGroupsIntoLines(letters, states, groups, widget.maxWidth);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulse,
        _revealController,
        _blankFlashController,
        _attentionController,
      ]),
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var li = 0; li < lines.length; li++)
              Padding(
                padding: EdgeInsets.only(top: li > 0 ? _lineGap : 0),
                child: ClipRect(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.maxWidth ?? double.infinity,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var gi = 0; gi < lines[li].length; gi++) ...[
                          if (gi > 0) SizedBox(width: _layout.groupGap),
                          _buildVisualGroup(
                            letters,
                            states,
                            muted,
                            lines[li][gi],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGroupWordSpans(
    List<BlankLetter> letters,
    List<BlankLetterState> states,
    Color muted,
    _VisualGroup group,
  ) {
    final children = <Widget>[];
    var j = 0;
    while (j < group.items.length) {
      if (group.items[j] == null) {
        children.add(SizedBox(width: _layout.groupGap));
        j++;
        continue;
      }

      final spanIndices = <int>[];
      final firstIdx = group.items[j]!;
      final keyWordIdx =
          letters[firstIdx].isKey ? letters[firstIdx].keyWordIndex : -1;

      while (j < group.items.length && group.items[j] != null) {
        final idx = group.items[j]!;
        if (letters[idx].isKey &&
            keyWordIdx >= 0 &&
            letters[idx].keyWordIndex != keyWordIdx) {
          break;
        }
        spanIndices.add(idx);
        j++;
      }

      var wordKaraoke = _KaraokeLetterRole.none;
      if (widget.karaokeTokenIndex != null) {
        for (final idx in spanIndices) {
          final role = _karaokeRoleFor(letters, idx);
          if (role == _KaraokeLetterRole.current) {
            wordKaraoke = _KaraokeLetterRole.current;
            break;
          }
          if (role == _KaraokeLetterRole.past) {
            wordKaraoke = _KaraokeLetterRole.past;
          }
        }
      }

      Widget wordRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var k = 0; k < spanIndices.length; k++) ...[
            if (k > 0) SizedBox(width: _layout.letterGap),
            _LetterSlot(
              state: spanIndices[k] < states.length
                  ? states[spanIndices[k]]
                  : const BlankLetterState.blank(),
              correctChar: letters[spanIndices[k]].char,
              isPunctuation: letters[spanIndices[k]].isPunctuation,
              accent: widget.accentColor,
              muted: muted,
              slotHeight: _slotH,
              slotWidth: _slotWidthFor(spanIndices[k], letters, states),
              letterStyle: _letterStyle,
              blankPlaceholder: _layout.blankPlaceholder,
              revealT: _letterRevealT(
                spanIndices[k],
                spanIndices[k] < states.length
                    ? states[spanIndices[k]]
                    : const BlankLetterState.blank(),
              ),
              dimmed: letters[spanIndices[k]].isKey &&
                  _isDimmedKeyBlank(letters[spanIndices[k]].keyWordIndex),
              karaokeRole: _karaokeRoleFor(letters, spanIndices[k]),
            ),
          ],
        ],
      );

      if (wordKaraoke == _KaraokeLetterRole.current) {
        final t = Curves.easeInOut.transform(_pulse.value);
        wordRow = DecoratedBox(
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.14 + t * 0.08),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.16 + t * 0.14),
                blurRadius: 8 + t * 4,
                spreadRadius: 0.2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: wordRow,
          ),
        );
      }

      children.add(wordRow);
    }
    return children;
  }

  Widget _buildVisualGroup(
    List<BlankLetter> letters,
    List<BlankLetterState> states,
    Color muted,
    _VisualGroup group,
  ) {
    final keyIdx = group.runIndex ?? -1;
    final tappable =
        widget.structureRevealed && group.isKeyRun && widget.onBlankTap != null;
    final selected = tappable && widget.selectedBlankIndex == keyIdx;
    final filled = keyIdx >= 0 &&
        keyIdx < widget.blankInputs.length &&
        widget.blankInputs[keyIdx].trim().isNotEmpty;
    final selectionActive =
        widget.selectedBlankIndex != null && widget.structureRevealed;
    final dimmedBlank = group.isKeyRun && selectionActive && !selected;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _buildGroupWordSpans(letters, states, muted, group),
    );

    // 모든 그룹에 동일한 세로 여백 → 힌트 on/off 시 높이 불변·정렬 유지
    // 빈칸 런은 가로 여백도 항상 확보, 테두리는 투명→주황으로만 전환
    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: group.isKeyRun ? _borderInset : 0,
        vertical: _borderInset,
      ),
      child: Opacity(
        opacity: dimmedBlank
            ? 0.34
            : (selectionActive && !group.isKeyRun ? 0.62 : 1.0),
        child: row,
      ),
    );

    const borderWidth = 2.0;
    final attention = math.sin(_attentionController.value * math.pi);
    final Color borderColor;
    Color? fillColor;
    List<BoxShadow>? glow;
    if (!group.isKeyRun) {
      borderColor = Colors.transparent;
    } else if (!widget.structureRevealed) {
      borderColor = Colors.transparent;
    } else if (filled && !selected) {
      borderColor = _runBorderColor.withValues(alpha: dimmedBlank ? 0.14 : 0.32);
    } else {
      // 레이아웃 불변: 두께 고정, 투명도·글로우만 살살 호흡
      final t = Curves.easeInOut.transform(_pulse.value);
      final flash = math.sin(_blankFlashController.value * math.pi);
      if (selected) {
        borderColor = widget.accentColor.withValues(alpha: 0.92);
        fillColor = widget.accentColor.withValues(alpha: 0.14 + t * 0.04);
        glow = [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.28 + t * 0.12),
            blurRadius: 8 + t * 4,
            spreadRadius: 0.5,
          ),
        ];
      } else if (dimmedBlank) {
        borderColor = _runBorderColor.withValues(alpha: 0.12);
      } else {
        borderColor =
            _runBorderColor.withValues(
              alpha: 0.42 + t * 0.28 + flash * 0.22 + attention * 0.18,
            );
        if (flash > 0.02) {
          fillColor = _runBorderColor.withValues(
            alpha: 0.04 + flash * 0.10 + attention * 0.10,
          );
          glow = [
            BoxShadow(
              color: _runBorderColor.withValues(
                alpha: 0.14 + flash * 0.22 + attention * 0.22,
              ),
              blurRadius: 6 + flash * 8 + attention * 10,
              spreadRadius: flash * 0.6 + attention * 1.2,
            ),
          ];
        } else {
          glow = [
            BoxShadow(
              color: _runBorderColor.withValues(alpha: 0.10 + t * 0.14),
              blurRadius: 4 + t * 4,
              spreadRadius: 0,
            ),
          ];
        }
      }
    }

    final boxed = Transform.scale(
      scale: 1 + attention * 0.045,
      alignment: Alignment.center,
      child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: fillColor,
        border: Border.all(
          color: borderColor,
          width: selected ? 2.5 : borderWidth,
        ),
        boxShadow: glow,
      ),
      child: padded,
      ),
    );

    if (!tappable) {
      return _wrapHintRunLabel(keyIdx, group, boxed);
    }

    return _wrapHintRunLabel(
      keyIdx,
      group,
      GestureDetector(
        onTap: () => widget.onBlankTap!(keyIdx),
        behavior: HitTestBehavior.opaque,
        child: boxed,
      ),
    );
  }

  Widget _wrapHintRunLabel(int runIndex, _VisualGroup group, Widget child) {
    if (!widget.showHintRunLabels || !group.isKeyRun || runIndex < 0) {
      return child;
    }
    return Stack(
      // 바깥 레이아웃이 ClipRect를 사용하므로, 배지까지 포함한 높이를
      // Stack 안에 확보해야 세 번째 힌트의 번호 윗부분이 잘리지 않는다.
      clipBehavior: Clip.hardEdge,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          child: HintRunBadge(
            number: runIndex + 1,
            color: widget.accentColor,
          ),
        ),
      ],
    );
  }

  List<List<int>> _wordIndexGroups(List<BlankLetter> letters) {
    final words = <List<int>>[];
    var current = <int>[];
    for (var i = 0; i < letters.length; i++) {
      if (letters[i].isGap) {
        if (current.isNotEmpty) words.add(current);
        current = [];
      } else {
        final cur = letters[i];
        if (cur.isPunctuation) {
          current.add(i);
          continue;
        }
        if (current.isNotEmpty) {
          int? lastContentIdx;
          for (final idx in current.reversed) {
            if (!letters[idx].isPunctuation) {
              lastContentIdx = idx;
              break;
            }
          }
          if (lastContentIdx != null) {
            final prev = letters[lastContentIdx];
            if (prev.isKey != cur.isKey ||
                (prev.isKey &&
                    cur.isKey &&
                    prev.keyWordIndex != cur.keyWordIndex)) {
              words.add(current);
              current = [];
            }
          }
        }
        current.add(i);
      }
    }
    if (current.isNotEmpty) words.add(current);
    return words;
  }

  List<_VisualGroup> _visualGroups(
    List<BlankLetter> letters,
    List<List<int>> keyRuns,
  ) {
    final keyWordToRun = <int, int>{};
    for (var run = 0; run < keyRuns.length; run++) {
      for (final keyWordIndex in keyRuns[run]) {
        keyWordToRun[keyWordIndex] = run;
      }
    }

    final groups = <_VisualGroup>[];
    for (final word in _wordIndexGroups(letters)) {
      final first = letters[word.first];
      final runIndex = first.isKey ? keyWordToRun[first.keyWordIndex] : null;
      final canMerge =
          runIndex != null &&
          groups.isNotEmpty &&
          groups.last.runIndex == runIndex;
      if (canMerge) {
        groups.last.items
          ..add(null)
          ..addAll(word);
      } else {
        groups.add(_VisualGroup(items: [...word], runIndex: runIndex));
      }
    }
    return groups;
  }

}

class _VisualGroup {
  final List<int?> items;
  final int? runIndex;

  _VisualGroup({required this.items, required this.runIndex});

  bool get isKeyRun => runIndex != null;
}

enum _KaraokeLetterRole { none, upcoming, current, past }

class _LetterSlot extends StatelessWidget {
  final BlankLetterState state;
  final String correctChar;
  final bool isPunctuation;
  final Color accent;
  final Color muted;
  final double slotHeight;
  final double slotWidth;
  final TextStyle letterStyle;
  final String blankPlaceholder;
  final double revealT;
  final bool dimmed;
  final _KaraokeLetterRole karaokeRole;

  const _LetterSlot({
    required this.state,
    required this.correctChar,
    this.isPunctuation = false,
    required this.accent,
    required this.muted,
    required this.slotHeight,
    required this.slotWidth,
    required this.letterStyle,
    required this.blankPlaceholder,
    this.revealT = 1.0,
    this.dimmed = false,
    this.karaokeRole = _KaraokeLetterRole.none,
  });

  @override
  Widget build(BuildContext context) {
    const wrongColor = Color(0xFFE53935);
    final kind = state.kind;
    final pendingStructure =
        kind == BlankRevealKind.structure && revealT <= 0.001;
    final effectiveKind =
        pendingStructure ? BlankRevealKind.blank : kind;
    final showAnswer = effectiveKind != BlankRevealKind.blank;
    final display = effectiveKind == BlankRevealKind.wrong
        ? (state.shown ?? '')
        : correctChar;
    final pop = kind == BlankRevealKind.structure
        ? Curves.easeOutBack.transform(revealT.clamp(0.0, 1.0))
        : 1.0;
    final color = switch (effectiveKind) {
      BlankRevealKind.correct => accent,
      BlankRevealKind.structure => accent.withValues(alpha: dimmed ? 0.38 : 0.72),
      BlankRevealKind.wrong => wrongColor,
      BlankRevealKind.blank => dimmed ? muted.withValues(alpha: 0.45) : accent,
    };

    if (isPunctuation) {
      return SizedBox(
        width: slotWidth,
        height: slotHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              correctChar,
              style: letterStyle.copyWith(
                color: dimmed ? color.withValues(alpha: 0.45) : color,
              ),
            ),
          ),
        ),
      );
    }

    late final Color barColor;
    var barHeight = 2.0;
    if (effectiveKind == BlankRevealKind.correct) {
      barColor = accent.withValues(alpha: dimmed ? 0.22 : 0.55);
    } else if (effectiveKind == BlankRevealKind.structure) {
      barColor = accent.withValues(alpha: dimmed ? 0.18 : 0.4);
    } else if (effectiveKind == BlankRevealKind.wrong) {
      barColor = wrongColor.withValues(alpha: 0.7);
    } else if (karaokeRole == _KaraokeLetterRole.current) {
      barColor = accent;
      barHeight = 3.0;
    } else if (karaokeRole == _KaraokeLetterRole.past) {
      barColor = accent.withValues(alpha: 0.45);
    } else if (karaokeRole == _KaraokeLetterRole.upcoming) {
      barColor = muted.withValues(alpha: 0.22);
    } else {
      barColor = dimmed ? muted.withValues(alpha: 0.28) : muted;
    }

    final letterWidget = effectiveKind == BlankRevealKind.blank
        ? const SizedBox.shrink()
        : showAnswer
            ? Text(
                display,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: letterStyle.copyWith(
                  color: color,
                  decoration: effectiveKind == BlankRevealKind.wrong
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: wrongColor,
                ),
              )
            : const SizedBox.shrink();

    final body = Column(
      children: [
        Expanded(
          child: Center(child: letterWidget),
        ),
        Container(
          height: barHeight,
          width: slotWidth,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );

    if (kind == BlankRevealKind.structure && revealT < 1.0) {
      return SizedBox(
        width: slotWidth,
        height: slotHeight,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - pop)),
          child: Transform.scale(
            scale: 0.55 + 0.45 * pop,
            alignment: Alignment.bottomCenter,
            child: Opacity(opacity: pop.clamp(0.0, 1.0), child: body),
          ),
        ),
      );
    }

    return SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: body,
    );
  }
}
