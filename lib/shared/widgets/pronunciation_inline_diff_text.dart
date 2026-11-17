import 'package:flutter/material.dart';

import '../../core/utils/cjk_pronunciation_phrase.dart';
import '../../core/utils/cjk_spoken_phonetic.dart';
import '../../core/utils/cjk_stt_segments.dart';
import '../../core/utils/english_pronunciation_tokens.dart';
import '../../core/utils/hanzi_to_pinyin_converter.dart';
import '../../core/utils/japanese_number_normalizer.dart';
import '../../core/utils/japanese_reading_fold.dart';
import '../../core/utils/scenario_answer_compare.dart';
import '../../core/utils/word_token_alignment.dart';



/// Inline diff 한 토큰 — 일치 단어 또는 오답→정답 교정 묶음.

sealed class PronunciationInlineDiffToken {

  const PronunciationInlineDiffToken();

}



class PronunciationInlineDiffMatch extends PronunciationInlineDiffToken {

  final String word;

  final String? phonetic;



  const PronunciationInlineDiffMatch(this.word, {this.phonetic});

}



class PronunciationInlineDiffCorrection extends PronunciationInlineDiffToken {

  final String spoken;

  final String? correct;

  final String? spokenPhonetic;

  final String? correctPhonetic;

  /// 음절은 같고 성조만 달라 STT가 다른 한자를 고른 경우 — 「불명확」으로 표시.
  final bool toneUnclear;



  const PronunciationInlineDiffCorrection({

    required this.spoken,

    this.correct,

    this.spokenPhonetic,

    this.correctPhonetic,

    this.toneUnclear = false,

  });

}

bool _toneUnclearForPair(String target, String spoken, String language) {
  if (language != 'Chinese') return false;
  if (target.isEmpty || spoken.isEmpty) return false;
  return ScenarioAnswerCompare.charsToneOnlyDiffer(target, spoken, language);
}

/// 성조 불명확이면 STT가 들은 성조 병음을 우선, 아니면 기존 fallback.
String? _spokenPhoneticForCorrection({
  required String target,
  required String spoken,
  required String language,
  String? fallback,
}) {
  if (language == 'Chinese' && _toneUnclearForPair(target, spoken, language)) {
    return HanziToPinyinConverter.heardTonePinyin(target, spoken) ?? fallback;
  }
  return fallback;
}

/// 교정 토큰이 모두 성조 불명확이고 Missing/일반 오답이 없으면 true.
bool _tokensAreToneUnclearOnly(List<PronunciationInlineDiffToken> tokens) {
  var sawToneUnclear = false;
  for (final token in tokens) {
    switch (token) {
      case PronunciationInlineDiffMatch():
        continue;
      case PronunciationInlineDiffCorrection(:final toneUnclear):
        if (!toneUnclear) return false;
        sawToneUnclear = true;
      case PronunciationInlineDiffMissing():
        return false;
    }
  }
  return sawToneUnclear;
}

/// 성조 불명확 교정 토큰들의 들은 병음을 모아 라벨용 문자열로.
String? _heardTonePinyinFromTokens(List<PronunciationInlineDiffToken> tokens) {
  final parts = <String>[];
  for (final token in tokens) {
    if (token is! PronunciationInlineDiffCorrection || !token.toneUnclear) {
      continue;
    }
    final phonetic = token.spokenPhonetic?.trim();
    if (phonetic != null && phonetic.isNotEmpty) {
      parts.add(phonetic);
      continue;
    }
    final correct = token.correct;
    final heard = correct != null
        ? HanziToPinyinConverter.heardTonePinyin(correct, token.spoken)
        : HanziToPinyinConverter.transliterateOrNull(token.spoken);
    if (heard != null && heard.trim().isNotEmpty) parts.add(heard.trim());
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}



class PronunciationInlineDiffMissing extends PronunciationInlineDiffToken {

  final String target;

  final String? phonetic;



  const PronunciationInlineDiffMissing(this.target, {this.phonetic});

}



List<PronunciationInlineDiffToken> formatEnglishSpokenTokensForDisplay(

  List<PronunciationInlineDiffToken> tokens,

  String targetText,

) {

  if (tokens.isEmpty) return tokens;

  final trailingPunct =
      EnglishPronunciationTokens.trailingPunctuationFromTarget(targetText);

  final result = <PronunciationInlineDiffToken>[];

  var capitalized = false;

  for (final token in tokens) {

    switch (token) {

      case PronunciationInlineDiffMatch(:final word, :final phonetic):

        var displayWord = word;

        if (!capitalized) {

          displayWord = EnglishPronunciationTokens.capitalizeFirstLetter(word);

          capitalized = true;

        }

        result.add(

          PronunciationInlineDiffMatch(displayWord, phonetic: phonetic),

        );

      case PronunciationInlineDiffCorrection(

        :final spoken,

        :final correct,

        :final spokenPhonetic,

        :final correctPhonetic,

        :final toneUnclear,

      ):

        var displaySpoken = spoken;

        if (!capitalized) {

          displaySpoken =

              EnglishPronunciationTokens.capitalizeFirstLetter(spoken);

          capitalized = true;

        }

        result.add(

          PronunciationInlineDiffCorrection(

            spoken: displaySpoken,

            correct: correct,

            spokenPhonetic: spokenPhonetic,

            correctPhonetic: correctPhonetic,

            toneUnclear: toneUnclear,

          ),

        );

      case PronunciationInlineDiffMissing(:final target, :final phonetic):

        result.add(PronunciationInlineDiffMissing(target, phonetic: phonetic));

    }

  }

  if (trailingPunct == null) return result;

  for (var i = result.length - 1; i >= 0; i--) {
    final token = result[i];
    switch (token) {
      case PronunciationInlineDiffMatch(:final word, :final phonetic):
        result[i] = PronunciationInlineDiffMatch(
          EnglishPronunciationTokens.applyTrailingPunctuation(
            word,
            trailingPunct,
          ),
          phonetic: phonetic,
        );
        return result;
      case PronunciationInlineDiffCorrection(
        :final spoken,
        :final correct,
        :final spokenPhonetic,
        :final correctPhonetic,
        :final toneUnclear,
      ):
        result[i] = PronunciationInlineDiffCorrection(
          spoken: EnglishPronunciationTokens.applyTrailingPunctuation(
            spoken,
            trailingPunct,
          ),
          correct: correct,
          spokenPhonetic: spokenPhonetic,
          correctPhonetic: correctPhonetic,
          toneUnclear: toneUnclear,
        );
        return result;
      case PronunciationInlineDiffMissing():
        continue;
    }
  }

  return result;

}



String cjkSpokenSentenceFromTokens(List<PronunciationInlineDiffToken> tokens) {
  final buffer = StringBuffer();
  for (final token in tokens) {
    final part = switch (token) {
      PronunciationInlineDiffMatch(:final word) => word,
      PronunciationInlineDiffCorrection(:final spoken) => spoken,
      PronunciationInlineDiffMissing() => '',
    };
    buffer.write(part);
  }
  return buffer.toString();
}



String _cjkPreparedSpoken(
  String spokenText,
  String targetText,
  String language,
) {
  var preprocessed = language == 'Japanese'
      ? ScenarioAnswerCompare.preprocessSpoken(spokenText, language: language)
      : spokenText;
  if (language == 'Japanese') {
    preprocessed = JapaneseNumberNormalizer.expandDigitsInText(preprocessed);
  }
  return CjkSttSegments.extractTargetScript(
    preprocessed,
    language,
    referenceText: targetText,
  ).trim();
}

List<WordAlignmentOp> _remapNumberOpsToOriginalTarget(
  List<WordAlignmentOp> ops,
  JapaneseTextExpansion expansion,
) {
  var expCursor = 0;
  final remapped = <WordAlignmentOp>[];
  for (final op in ops) {
    final targetWord = op.targetWord;
    if (targetWord == null || targetWord.isEmpty) {
      remapped.add(op);
      continue;
    }
    final orig = JapaneseNumberNormalizer.originalSliceForExpandedRange(
      expansion,
      expCursor,
      expCursor + targetWord.length,
    );
    expCursor += targetWord.length;
    remapped.add(
      WordAlignmentOp(
        kind: op.kind,
        targetWord: orig.isNotEmpty ? orig : targetWord,
        spokenWord: op.spokenWord,
      ),
    );
  }
  return remapped;
}



/// CJK 문장형 inline diff — 전체 문장 글자 단위로 틀린 부분만 취소선.
List<PronunciationInlineDiffToken> buildCjkSentenceInlineDiffTokens({
  required String targetText,
  required String spokenText,
  required String language,
  required String koreanPronunciation,
}) {
  final lexicon = CjkPronunciationPhraseBuilder.buildLexicon(
    sentence: targetText,
    pronunciation: koreanPronunciation,
    language: language,
  );
  final targetTrim = targetText.trim();
  final targetExpansion = language == 'Japanese'
      ? JapaneseNumberNormalizer.expandWithMap(targetTrim)
      : null;
  final targetForAlign = targetExpansion?.expanded ?? targetTrim;
  final prepared = _cjkPreparedSpoken(spokenText, targetText, language);

  // 일본어: STT 한자(締め)를 정답 가나(しめ)로 접어 정렬한 뒤, 표시는 STT 표면 유지.
  final fold = language == 'Japanese'
      ? JapaneseReadingFold.foldWithMap(
          prepared,
          CjkSttSegments.extractTargetScript(
            targetForAlign,
            language,
            referenceText: targetText,
          ),
        )
      : null;
  final spokenForAlign = fold?.folded ?? prepared;

  var ops = CjkPronunciationPhraseBuilder.subdivideForInlineDiffSentence(
    target: targetForAlign,
    spoken: spokenForAlign,
    language: language,
  );
  if (targetExpansion != null) {
    ops = _remapNumberOpsToOriginalTarget(ops, targetExpansion);
  }
  final displayOps = fold == null
      ? ops
      : _remapAlignmentOpsToSpokenSurface(ops, fold, prepared);

  final fallbackLexeme = lexicon.isNotEmpty
      ? lexicon.first
      : CjkPhraseLexeme(surface: targetText);

  return _inlineDiffTokensFromSubdivision(
    displayOps,
    lexicon: lexicon,
    targetLexeme: fallbackLexeme,
    spokenText: spokenText,
    language: language,
    phraseIndex: 0,
    containerTarget: targetTrim,
    containerPronunciation: koreanPronunciation,
  );
}

/// 정렬은 접힌 가나 기준, UI spoken 표면은 원본 STT(한자)로 되돌린다.
List<WordAlignmentOp> _remapAlignmentOpsToSpokenSurface(
  List<WordAlignmentOp> ops,
  JapaneseReadingFoldResult fold,
  String preparedSpoken,
) {
  var foldPos = 0;
  final remapped = <WordAlignmentOp>[];

  for (final op in ops) {
    final spokenPart = op.spokenWord;
    if (spokenPart == null || spokenPart.isEmpty) {
      remapped.add(op);
      continue;
    }

    final surface = JapaneseReadingFold.spokenSurfaceForFoldRange(
      fold,
      preparedSpoken,
      foldStart: foldPos,
      foldEnd: foldPos + spokenPart.length,
    );
    foldPos += spokenPart.length;
    remapped.add(
      WordAlignmentOp(
        kind: op.kind,
        targetWord: op.targetWord,
        spokenWord: surface.isNotEmpty ? surface : spokenPart,
      ),
    );
  }
  return remapped;
}



int _locateTargetWord(String containerTarget, int hint, String word) {
  if (word.isEmpty) return hint;
  final idx = containerTarget.indexOf(word, hint);
  return idx >= 0 ? idx : hint;
}



String? _resolveTokenPhonetic({
  required String containerTarget,
  required String containerPronunciation,
  required int rangeStart,
  required int rangeEnd,
  List<CjkPhraseLexeme>? lexicon,
  String? surfaceKey,
  String language = 'Japanese',
  String? spokenSurfaceForFallback,
  bool allowConverterFallback = false,
}) {
  // 시트 pronunciation 구문 매칭을 비율 슬라이스보다 우선 (접두 생략 시 오절단 방지).
  if (lexicon != null && surfaceKey != null) {
    final fromLexicon = CjkPronunciationPhraseBuilder.phoneticForSurface(
      lexicon,
      surfaceKey,
    );
    if (fromLexicon != null && fromLexicon.trim().isNotEmpty) {
      return fromLexicon;
    }
    final stripped = CjkPronunciationPhraseBuilder.stripPunctuation(surfaceKey);
    if (stripped != surfaceKey) {
      final fromStripped = CjkPronunciationPhraseBuilder.phoneticForSurface(
        lexicon,
        stripped,
      );
      if (fromStripped != null && fromStripped.trim().isNotEmpty) {
        return fromStripped;
      }
    }
    for (final item in lexicon) {
      final itemStrip =
          CjkPronunciationPhraseBuilder.stripPunctuation(item.surface);
      if (itemStrip == stripped && item.phonetic.trim().isNotEmpty) {
        return item.phonetic;
      }
    }
  }

  // 문장 전체 비율 슬라이스보다, 이 구간을 포함하는 lexicon 구문 하나로
  // 좁힌 슬라이스를 우선 — 옆 구문 발음이 새어 들어오는 것을 막는다.
  if (lexicon != null) {
    final scoped = CjkPronunciationPhraseBuilder.phoneticSliceScopedToLexiconPhrase(
      lexicon: lexicon,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    if (scoped != null && scoped.trim().isNotEmpty) return scoped;
  }

  final sliced = CjkPronunciationPhraseBuilder.phoneticSliceForTargetRange(
    targetText: containerTarget,
    pronunciation: containerPronunciation,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  if (sliced != null && sliced.trim().isNotEmpty) return sliced;

  if (allowConverterFallback &&
      spokenSurfaceForFallback != null &&
      spokenSurfaceForFallback.trim().isNotEmpty) {
    return CjkSpokenPhonetic.phoneticForSpokenSurface(
      spokenSurfaceForFallback,
      language: language,
    );
  }

  return null;
}



List<PronunciationInlineDiffToken> buildPronunciationInlineDiffTokens({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (CjkSttSegments.isTargetLanguage(language) &&

      koreanPronunciation.trim().isNotEmpty) {

    final lexicon = CjkPronunciationPhraseBuilder.buildLexicon(

      sentence: targetText,

      pronunciation: koreanPronunciation,

      language: language,

    );

    final alignment = CjkPronunciationPhraseBuilder.alignPhrases(

      sentence: targetText,

      pronunciation: koreanPronunciation,

      spokenText: spokenText,

      language: language,

    );

    return _tokensFromPhraseOps(
      alignment.ops,
      lexicon,
      spokenText: spokenText,
      language: language,
    );

  }



  final alignment = WordTokenAligner.alignText(

    targetText: targetText,

    spokenText: spokenText,

    language: language,

  );



  return _tokensFromPhraseOps(alignment.ops, const []);

}



List<PronunciationInlineDiffToken> _tokensFromPhraseOps(

  List<WordAlignmentOp> ops,

  List<CjkPhraseLexeme> lexicon, {

  String spokenText = '',

  String language = 'English',

}) {

  var targetIdx = 0;

  final tokens = <PronunciationInlineDiffToken>[];

  for (final op in ops) {

    switch (op.kind) {

      case WordAlignmentKind.match:

        tokens.add(

          PronunciationInlineDiffMatch(

            op.spokenWord ?? op.targetWord!,

            phonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

              lexicon,

              op.targetWord ?? op.spokenWord ?? '',

            ),

          ),

        );

        targetIdx++;

      case WordAlignmentKind.substitution:

        final targetWord = op.targetWord ?? '';

        final spokenWord = op.spokenWord ?? '';

        final targetLexeme = targetIdx < lexicon.length

            ? lexicon[targetIdx]

            : CjkPhraseLexeme(surface: targetWord);

        final phraseIndex = targetIdx;

        targetIdx++;

        if (CjkSttSegments.isTargetLanguage(language)) {

          final subOps = CjkPronunciationPhraseBuilder.subdivideForInlineDiff(

            target: targetWord,

            spoken: spokenWord,

            language: language,

          );

          final useInlineSubdivision = subOps.length > 1 ||

              (subOps.length == 1 &&

                  subOps.first.kind != WordAlignmentKind.substitution);

          if (useInlineSubdivision) {

            tokens.addAll(

              _inlineDiffTokensFromSubdivision(

                subOps,

                lexicon: lexicon,

                targetLexeme: targetLexeme,

                spokenText: spokenText,

                language: language,

                phraseIndex: phraseIndex,

                containerTarget: targetWord,

                containerPronunciation: targetLexeme.phonetic,

              ),

            );

            break;

          }

        }

        tokens.add(

          PronunciationInlineDiffCorrection(

            spoken: spokenWord,

            correct: op.targetWord,

            correctPhonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

              lexicon,

              targetWord,

            ),

            toneUnclear: _toneUnclearForPair(targetWord, spokenWord, language),

            spokenPhonetic: _spokenPhoneticForCorrection(
              target: targetWord,
              spoken: spokenWord,
              language: language,
              fallback:
                  CjkPronunciationPhraseBuilder.spokenPhoneticForSubstitution(
                rawSpoken: spokenText,
                spokenSurface: spokenWord,
                target: targetLexeme,
                language: language,
                phraseIndex: phraseIndex,
              ),
            ),

          ),

        );

      case WordAlignmentKind.insertion:

        tokens.add(

          PronunciationInlineDiffCorrection(

            spoken: op.spokenWord!,

            spokenPhonetic:

                CjkPronunciationPhraseBuilder.spokenPhoneticForInsertion(

              spokenSurface: op.spokenWord!,

              language: language,

            ),

          ),

        );

      case WordAlignmentKind.deletion:

        final targetWord = op.targetWord!;

        targetIdx++;

        tokens.add(

          PronunciationInlineDiffMissing(

            targetWord,

            phonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

              lexicon,

              targetWord,

            ),

          ),

        );

    }

  }

  return tokens;

}



/// 짧은 접두 누락(し·に 등)만 Missing+Match 분리. 긴 prefix는 char subdivide.
const _maxMissingPrefixChars = 4;

/// target = [누락 접두] + spoken 인 치환 → Missing + Match 로 분리.
List<PronunciationInlineDiffToken> _tokensFromSubstitutionOp(
  WordAlignmentOp op, {
  required List<CjkPhraseLexeme> lexicon,
  required CjkPhraseLexeme targetLexeme,
  required String spokenText,
  required String language,
  required int phraseIndex,
  required String containerTarget,
  required String containerPronunciation,
  required int targetRangeStart,
}) {
  final target = op.targetWord ?? '';
  final spoken = op.spokenWord ?? '';

  if (spoken.isNotEmpty &&
      target.length > spoken.length &&
      target.endsWith(spoken)) {
    final prefix = target.substring(0, target.length - spoken.length);
    if (prefix.isNotEmpty &&
        prefix.length <= _maxMissingPrefixChars &&
        target == prefix + spoken) {
      final prefixStart = targetRangeStart;
      final prefixEnd = targetRangeStart + prefix.length;
      final suffixStart = prefixEnd;
      final suffixEnd = targetRangeStart + target.length;
      return [
        PronunciationInlineDiffMissing(
          prefix,
          phonetic: _resolveTokenPhonetic(
            containerTarget: containerTarget,
            containerPronunciation: containerPronunciation,
            rangeStart: prefixStart,
            rangeEnd: prefixEnd,
            lexicon: lexicon,
            surfaceKey: prefix,
            language: language,
          ),
        ),
        PronunciationInlineDiffMatch(
          spoken,
          phonetic: _resolveTokenPhonetic(
            containerTarget: containerTarget,
            containerPronunciation: containerPronunciation,
            rangeStart: suffixStart,
            rangeEnd: suffixEnd,
            lexicon: lexicon,
            surfaceKey: spoken,
            language: language,
          ),
        ),
      ];
    }
  }

  final charOps = CjkPronunciationPhraseBuilder.subdivideForInlineDiffCharsOnly(
    target: target,
    spoken: spoken,
    language: language,
  );
  final isWholeSubstitution = charOps.length == 1 &&
      charOps.first.kind == WordAlignmentKind.substitution;
  if (!isWholeSubstitution) {
    return _inlineDiffTokensFromSubdivision(
      charOps,
      lexicon: lexicon,
      targetLexeme: targetLexeme,
      spokenText: spokenText,
      language: language,
      phraseIndex: phraseIndex,
      containerTarget: containerTarget,
      containerPronunciation: containerPronunciation,
      targetRangeStart: targetRangeStart,
    );
  }

  final rangeEnd = targetRangeStart + target.length;
  final toneUnclear = _toneUnclearForPair(target, spoken, language);
  return [
    PronunciationInlineDiffCorrection(
      spoken: spoken,
      correct: op.targetWord,
      correctPhonetic: _resolveTokenPhonetic(
        containerTarget: containerTarget,
        containerPronunciation: containerPronunciation,
        rangeStart: targetRangeStart,
        rangeEnd: rangeEnd,
        lexicon: lexicon,
        surfaceKey: target,
        language: language,
      ),
      spokenPhonetic: _spokenPhoneticForCorrection(
        target: target,
        spoken: spoken,
        language: language,
        fallback: CjkPronunciationPhraseBuilder.spokenPhoneticForSubstitution(
          rawSpoken: spokenText,
          spokenSurface: spoken,
          target: targetLexeme,
          language: language,
          phraseIndex: phraseIndex,
        ),
      ),
      toneUnclear: toneUnclear,
    ),
  ];
}

List<PronunciationInlineDiffToken> _inlineDiffTokensFromSubdivision(

  List<WordAlignmentOp> subOps, {

  required List<CjkPhraseLexeme> lexicon,

  required CjkPhraseLexeme targetLexeme,

  required String spokenText,

  required String language,

  required int phraseIndex,

  required String containerTarget,

  required String containerPronunciation,

  int targetRangeStart = 0,

}) {

  final tokens = <PronunciationInlineDiffToken>[];
  var targetHint = targetRangeStart;

  for (final subOp in subOps) {
    final targetWord = subOp.targetWord ?? '';
    final rangeStart = _locateTargetWord(containerTarget, targetHint, targetWord);
    final rangeEnd = targetWord.isEmpty ? rangeStart : rangeStart + targetWord.length;

    switch (subOp.kind) {
      case WordAlignmentKind.match:
        tokens.add(
          PronunciationInlineDiffMatch(
            subOp.spokenWord ?? subOp.targetWord!,
            phonetic: _resolveTokenPhonetic(
              containerTarget: containerTarget,
              containerPronunciation: containerPronunciation,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              lexicon: lexicon,
              surfaceKey: subOp.targetWord ?? subOp.spokenWord,
              language: language,
            ),
          ),
        );
        if (targetWord.isNotEmpty) targetHint = rangeEnd;
      case WordAlignmentKind.substitution:
        tokens.addAll(
          _tokensFromSubstitutionOp(
            subOp,
            lexicon: lexicon,
            targetLexeme: targetLexeme,
            spokenText: spokenText,
            language: language,
            phraseIndex: phraseIndex,
            containerTarget: containerTarget,
            containerPronunciation: containerPronunciation,
            targetRangeStart: rangeStart,
          ),
        );
        if (targetWord.isNotEmpty) targetHint = rangeEnd;
      case WordAlignmentKind.insertion:
        tokens.add(
          PronunciationInlineDiffCorrection(
            spoken: subOp.spokenWord ?? '',
            spokenPhonetic: CjkSpokenPhonetic.phoneticForSpokenSurface(
              subOp.spokenWord ?? '',
              language: language,
            ),
          ),
        );
      case WordAlignmentKind.deletion:
        tokens.add(
          PronunciationInlineDiffMissing(
            subOp.targetWord ?? '',
            phonetic: _resolveTokenPhonetic(
              containerTarget: containerTarget,
              containerPronunciation: containerPronunciation,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              lexicon: lexicon,
              surfaceKey: subOp.targetWord,
              language: language,
            ),
          ),
        );
        if (targetWord.isNotEmpty) targetHint = rangeEnd;
    }
  }

  return tokens;

}



bool pronunciationHasWordDiff({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (spokenText.trim().isEmpty) return false;

  final tokens = buildPronunciationInlineDiffTokens(

    targetText: targetText,

    spokenText: spokenText,

    language: language,

    koreanPronunciation: koreanPronunciation,

  );

  return tokens.any((token) => token is! PronunciationInlineDiffMatch);

}



bool pronunciationIsTextPerfectMatch({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (spokenText.trim().isEmpty || targetText.trim().isEmpty) return false;

  if (CjkSttSegments.isTargetLanguage(language)) {

    if (koreanPronunciation.trim().isNotEmpty) {

      return !pronunciationHasWordDiff(

        targetText: targetText,

        spokenText: spokenText,

        language: language,

        koreanPronunciation: koreanPronunciation,

      );

    }

    return ScenarioAnswerCompare.isCorrect(

      spoken: spokenText,

      correct: targetText,

      language: language,

    );

  }

  return !pronunciationHasWordDiff(

    targetText: targetText,

    spokenText: spokenText,

    language: language,

  );

}



int pronunciationMatchedWordCount({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (CjkSttSegments.isTargetLanguage(language) &&

      koreanPronunciation.trim().isNotEmpty) {

    return CjkPronunciationPhraseBuilder.alignPhrases(

      sentence: targetText,

      pronunciation: koreanPronunciation,

      spokenText: spokenText,

      language: language,

    ).matchedTargetCount;

  }

  return WordTokenAligner.alignText(

    targetText: targetText,

    spokenText: spokenText,

    language: language,

  ).matchedTargetCount;

}



/// CJK(한글 발음 가이드 포함) — 글자 LCS 기반 부분 점수.
int pronunciationAccuracyPercent({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (spokenText.trim().isEmpty) return 0;

  if (CjkSttSegments.isTargetLanguage(language) &&

      koreanPronunciation.trim().isNotEmpty) {

    final score = CjkPronunciationPhraseBuilder.accuracyPercent(

      sentence: targetText,

      pronunciation: koreanPronunciation,

      spokenText: spokenText,

      language: language,

    );

    if (pronunciationHasWordDiff(

          targetText: targetText,

          spokenText: spokenText,

          language: language,

          koreanPronunciation: koreanPronunciation,

        ) &&

        score >= 100) {

      return 99;

    }

    return score;

  }

  if (language == 'Japanese' || language == 'Chinese') {

    return CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(

      sentence: targetText,

      spokenText: spokenText,

      language: language,

    );

  }

  return WordTokenAligner.accuracyPercent(

    targetText: targetText,

    spokenText: spokenText,

    language: language,

  );

}



bool pronunciationHasPartialMatch({

  required String targetText,

  required String spokenText,

  String language = 'English',

  String koreanPronunciation = '',

}) {

  if (spokenText.trim().isEmpty) return false;

  if (CjkSttSegments.isTargetLanguage(language) &&

      koreanPronunciation.trim().isNotEmpty) {

    return pronunciationAccuracyPercent(

          targetText: targetText,

          spokenText: spokenText,

          language: language,

          koreanPronunciation: koreanPronunciation,

        ) >

        0;

  }

  return pronunciationMatchedWordCount(

        targetText: targetText,

        spokenText: spokenText,

        language: language,

        koreanPronunciation: koreanPronunciation,

      ) >

      0;

}



/// STT 인식 문장을 오답(취소선) + 정답(에메랄드 칩) Inline Diff로 표시한다.

class PronunciationInlineDiffText extends StatelessWidget {

  final String targetText;

  final String spokenText;

  final String language;

  final String correctPronunciation;

  final TextAlign textAlign;



  const PronunciationInlineDiffText({

    super.key,

    required this.targetText,

    required this.spokenText,

    this.language = 'English',

    this.correctPronunciation = '',

    this.textAlign = TextAlign.center,

  });



  static const _matchColor = Color(0xFF334155);

  static const _phoneticColor = Color(0xFF64748B);

  static const _wrongText = Color(0xFFDC2626);

  static const _wrongBg = Color(0xFFEF4444);

  static const _unclearText = Color(0xFFB45309);

  static const _unclearBg = Color(0xFFF59E0B);

  static const _correctText = Color(0xFF059669);

  static const _correctBg = Color(0xFF10B981);

  static const _perfectGreen = Color(0xFF059669);

  static const _chipRadius = BorderRadius.all(Radius.circular(16));

  static const _chipPadding =
      EdgeInsets.symmetric(vertical: 14, horizontal: 16);

  static const _clusterGap = 8.0;

  static const _surfaceFontSize = 16.0;

  static const _phoneticFontSize = 13.0;

  static const _surfaceLetterSpacing = -0.3;



  WrapAlignment get _wrapAlignment => switch (textAlign) {

        TextAlign.center => WrapAlignment.center,

        TextAlign.end || TextAlign.right => WrapAlignment.end,

        _ => WrapAlignment.start,

      };



  bool get _showPhonetic =>

      CjkSttSegments.isTargetLanguage(language) &&

      correctPronunciation.trim().isNotEmpty;



  @override

  Widget build(BuildContext context) {

    final tokens = buildPronunciationInlineDiffTokens(
      targetText: targetText,
      spokenText: spokenText,
      language: language,
      koreanPronunciation: correctPronunciation,
    );

    final isEnglish = !CjkSttSegments.isTargetLanguage(language);
    final isCjk = !isEnglish;
    final displayTokens = isEnglish
        ? formatEnglishSpokenTokensForDisplay(tokens, targetText)
        : tokens;
    final hasCorrections =
        tokens.any((token) => token is! PronunciationInlineDiffMatch);

    if (tokens.isEmpty) {
      final fallback = spokenText.trim();
      if (fallback.isEmpty) return const SizedBox.shrink();
      return Text(
        isEnglish
            ? EnglishPronunciationTokens.formatSpokenSentence(
                fallback,
                targetText,
              )
            : fallback,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _matchColor,
          height: 1.35,
        ),
      );
    }

    final useSentenceLevelDiff =
        hasCorrections &&
        (isEnglish ||
            (isCjk && displayTokens.any((token) => token is! PronunciationInlineDiffMatch)));
    if (useSentenceLevelDiff) {
      final cjkInlineTokens = isCjk
          ? buildCjkSentenceInlineDiffTokens(
              targetText: targetText,
              spokenText: spokenText,
              language: language,
              koreanPronunciation: correctPronunciation,
            )
          : displayTokens;
      final preparedSpoken = isCjk
          ? _cjkPreparedSpoken(spokenText, targetText, language)
          : null;
      final toneUnclearOnly = _tokensAreToneUnclearOnly(cjkInlineTokens);
      final heardToneLabel = toneUnclearOnly
          ? _heardTonePinyinFromTokens(cjkInlineTokens)
          : null;
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            child: _SubstitutionCluster(
              spoken: isEnglish
                  ? EnglishPronunciationTokens.formatSpokenSentence(
                      spokenText,
                      targetText,
                    )
                  : preparedSpoken!.isNotEmpty
                      ? preparedSpoken
                      : spokenText.trim(),
              spokenTokens: cjkInlineTokens,
              correct: targetText.trim(),
              spokenPhonetic: heardToneLabel,
              correctPhonetic: _showPhonetic &&
                      correctPronunciation.trim().isNotEmpty
                  ? correctPronunciation.trim()
                  : null,
              showPhonetic: _showPhonetic,
              language: language,
              separateTokensWithSpaces: isEnglish,
              toneUnclear: toneUnclearOnly,
            ),
          );
        },
      );
    }

    if (!hasCorrections) {
      return _PerfectMatchDisplay(
        sentence: _perfectSentenceLabel(displayTokens, isEnglish),
        phonetic: _perfectPhoneticLabel(displayTokens),
        textAlign: textAlign,
        showPhonetic: _showPhonetic,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          alignment: _wrapAlignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6.0,
          runSpacing: 10.0,
          children: [
            for (final token in displayTokens)
              switch (token) {
                PronunciationInlineDiffMatch(:final word, :final phonetic) =>
                  _showPhonetic
                      ? _MatchChip(
                          surface: word,
                          phonetic: phonetic,
                        )
                      : Text(
                          word,
                          style: const TextStyle(
                            fontSize: _surfaceFontSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: _surfaceLetterSpacing,
                            color: _matchColor,
                            height: 1.35,
                          ),
                        ),
                PronunciationInlineDiffCorrection(
                  :final spoken,
                  :final correct,
                  :final correctPhonetic,
                  :final spokenPhonetic,
                  :final toneUnclear,
                ) =>
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _SubstitutionCluster(
                      spoken: spoken,
                      correct: correct,
                      spokenPhonetic: spokenPhonetic,
                      correctPhonetic: correctPhonetic,
                      showPhonetic: _showPhonetic,
                      language: language,
                      toneUnclear: toneUnclear,
                    ),
                  ),
                PronunciationInlineDiffMissing(
                  :final target,
                  :final phonetic,
                ) =>
                  _CorrectChip(
                    label: target,
                    phonetic: phonetic,
                    showPhonetic: _showPhonetic,
                  ),
              },
          ],
        );
      },
    );
  }
}



String _perfectSentenceLabel(
  List<PronunciationInlineDiffToken> tokens,
  bool isEnglish,
) {
  final parts = [
    for (final token in tokens)
      if (token is PronunciationInlineDiffMatch) token.word,
  ];
  if (parts.isEmpty) return '';
  return isEnglish ? parts.join(' ') : parts.join();
}



String? _perfectPhoneticLabel(List<PronunciationInlineDiffToken> tokens) {
  final parts = [
    for (final token in tokens)
      if (token is PronunciationInlineDiffMatch &&
          (token.phonetic?.trim().isNotEmpty ?? false))
        token.phonetic!.trim(),
  ];
  if (parts.isEmpty) return null;
  return parts.join(' ');
}



/// 100점 완벽 일치 — 기존 Match 칩 + 좌상단 소형 체크.
class _PerfectMatchDisplay extends StatelessWidget {
  final String sentence;
  final String? phonetic;
  final TextAlign textAlign;
  final bool showPhonetic;

  const _PerfectMatchDisplay({
    required this.sentence,
    this.phonetic,
    required this.textAlign,
    required this.showPhonetic,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: switch (textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.end || TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _MatchChip(
            surface: sentence,
            phonetic: showPhonetic ? phonetic : null,
          ),
          const Positioned(
            top: 6,
            left: 6,
            child: Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: PronunciationInlineDiffText._perfectGreen,
            ),
          ),
        ],
      ),
    );
  }
}



class _PhraseChip extends StatelessWidget {

  final String surface;

  final String? phonetic;

  final Color surfaceColor;

  final FontWeight surfaceWeight;

  final bool strikethrough;

  final Color? phoneticColor;

  final double phoneticOpacity;



  const _PhraseChip({

    required this.surface,

    this.phonetic,

    required this.surfaceColor,

    this.surfaceWeight = FontWeight.bold,

    this.strikethrough = false,

    this.phoneticColor,

    this.phoneticOpacity = 1,

  });



  @override

  Widget build(BuildContext context) {

    final guide = phonetic?.trim() ?? '';

    final subColor = (phoneticColor ?? PronunciationInlineDiffText._phoneticColor)

        .withValues(alpha: phoneticOpacity);



    return Column(

      mainAxisSize: MainAxisSize.min,

      crossAxisAlignment: CrossAxisAlignment.center,

      children: [

        Text(

          surface,

          textAlign: TextAlign.center,

          style: TextStyle(

            fontSize: PronunciationInlineDiffText._surfaceFontSize,

            fontWeight: surfaceWeight,

            letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,

            color: surfaceColor,

            height: 1.3,

            decoration: strikethrough ? TextDecoration.lineThrough : null,

            decorationColor: surfaceColor,

          ),

        ),

        if (guide.isNotEmpty) ...[

          const SizedBox(height: 4),

          Text(

            guide,

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: PronunciationInlineDiffText._phoneticFontSize,

              fontWeight: FontWeight.w500,

              color: subColor,

              height: 1.3,

            ),

          ),

        ],

      ],

    );

  }

}



/// 일치 구문 — 소프트 글래스 칩.
class _MatchChip extends StatelessWidget {
  final String surface;
  final String? phonetic;

  const _MatchChip({
    required this.surface,
    this.phonetic,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PronunciationInlineDiffText._matchColor.withValues(alpha: 0.06),
        borderRadius: PronunciationInlineDiffText._chipRadius,
      ),
      child: Padding(
        padding: PronunciationInlineDiffText._chipPadding,
        child: _PhraseChip(
          surface: surface,
          phonetic: phonetic,
          surfaceColor: PronunciationInlineDiffText._matchColor,
          surfaceWeight: FontWeight.bold,
        ),
      ),
    );
  }
}



/// STT 문장 — 맞은 단어는 일반, 틀린 단어만 취소선.
class _SpokenInlineDiffText extends StatelessWidget {
  final List<PronunciationInlineDiffToken> tokens;
  final TextAlign textAlign;
  final bool separateTokensWithSpaces;

  const _SpokenInlineDiffText({
    required this.tokens,
    this.textAlign = TextAlign.center,
    this.separateTokensWithSpaces = true,
  });

  static const _matchStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._surfaceFontSize,
    fontWeight: FontWeight.w600,
    letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,
    color: PronunciationInlineDiffText._matchColor,
    height: 1.3,
  );

  static const _wrongStrikeStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._surfaceFontSize,
    fontWeight: FontWeight.bold,
    letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,
    color: PronunciationInlineDiffText._wrongText,
    decoration: TextDecoration.lineThrough,
    decorationColor: PronunciationInlineDiffText._wrongText,
    decorationThickness: 1.4,
    height: 1.3,
  );

  static const _unclearStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._surfaceFontSize,
    fontWeight: FontWeight.bold,
    letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,
    color: PronunciationInlineDiffText._unclearText,
    height: 1.3,
  );

  static const _missingStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._surfaceFontSize,
    fontWeight: FontWeight.bold,
    letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,
    color: PronunciationInlineDiffText._wrongText,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dashed,
    decorationColor: PronunciationInlineDiffText._wrongText,
    decorationThickness: 1.6,
    height: 1.3,
  );

  static const _missingPhoneticStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._phoneticFontSize,
    fontWeight: FontWeight.bold,
    color: Color(0xFF991B1B),
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dashed,
    decorationColor: Color(0xFF991B1B),
    decorationThickness: 1.4,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var needsSpace = false;

    for (final token in tokens) {
      if (token is PronunciationInlineDiffMissing) {
        final missing = token.target;
        if (missing.trim().isEmpty) continue;
        if (needsSpace && separateTokensWithSpaces) {
          spans.add(const TextSpan(text: ' '));
        }
        spans.add(TextSpan(text: missing, style: _missingStyle));
        needsSpace = true;
        continue;
      }

      final String? text = switch (token) {
        PronunciationInlineDiffMatch(:final word) => word,
        PronunciationInlineDiffCorrection(:final spoken) => spoken,
        PronunciationInlineDiffMissing() => null,
      };
      if (text == null || text.trim().isEmpty) continue;

      if (needsSpace && separateTokensWithSpaces) {
        spans.add(const TextSpan(text: ' '));
      }
      final style = switch (token) {
        PronunciationInlineDiffMatch() => _matchStyle,
        PronunciationInlineDiffCorrection(:final toneUnclear)
            when toneUnclear =>
          _unclearStyle,
        _ => _wrongStrikeStyle,
      };
      spans.add(TextSpan(text: text, style: style));
      needsSpace = true;
    }

    if (spans.isEmpty) return const SizedBox.shrink();

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }
}

/// STT 병음 — 토큰별로 맞은/누락/틀린 구간을 구분해 표시.
class _SpokenInlineDiffPhonetic extends StatelessWidget {
  final List<PronunciationInlineDiffToken> tokens;
  final TextAlign textAlign;
  final bool separateTokensWithSpaces;
  final String language;

  const _SpokenInlineDiffPhonetic({
    required this.tokens,
    required this.language,
    this.textAlign = TextAlign.center,
    this.separateTokensWithSpaces = true,
  });

  static const _matchStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._phoneticFontSize,
    fontWeight: FontWeight.w500,
    color: Color(0xFF991B1B),
    height: 1.3,
  );

  static const _wrongStrikeStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._phoneticFontSize,
    fontWeight: FontWeight.w500,
    color: Color(0xFF991B1B),
    decoration: TextDecoration.lineThrough,
    decorationColor: Color(0xFF991B1B),
    height: 1.3,
  );

  static const _unclearStyle = TextStyle(
    fontSize: PronunciationInlineDiffText._phoneticFontSize,
    fontWeight: FontWeight.w500,
    color: Color(0xFF92400E),
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var needsSpace = false;

    for (final token in tokens) {
      final String? phonetic = switch (token) {
        PronunciationInlineDiffMatch(:final phonetic) => phonetic,
        PronunciationInlineDiffMissing(:final phonetic) => phonetic,
        PronunciationInlineDiffCorrection(
          :final spoken,
          :final spokenPhonetic,
        ) =>
          spokenPhonetic ??
              CjkSpokenPhonetic.phoneticForSpokenSurface(
                spoken,
                language: language,
              ),
      };
      if (phonetic == null || phonetic.trim().isEmpty) continue;

      if (needsSpace && separateTokensWithSpaces) {
        spans.add(const TextSpan(text: ' '));
      }

      spans.add(
        TextSpan(
          text: phonetic,
          style: switch (token) {
            PronunciationInlineDiffMatch() => _matchStyle,
            PronunciationInlineDiffMissing() =>
              _SpokenInlineDiffText._missingPhoneticStyle,
            PronunciationInlineDiffCorrection(:final toneUnclear)
                when toneUnclear =>
              _unclearStyle,
            PronunciationInlineDiffCorrection() => _wrongStrikeStyle,
          },
        ),
      );
      needsSpace = true;
    }

    if (spans.isEmpty) return const SizedBox.shrink();

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }
}



/// 오발음/치환 — 붉은 오답 칩(또는 성조 불명확 앰버 칩) ➔ 초록 정답 칩.

class _SubstitutionCluster extends StatelessWidget {

  final String spoken;

  final List<PronunciationInlineDiffToken>? spokenTokens;

  final String? correct;

  final String? spokenPhonetic;

  final String? correctPhonetic;

  final bool showPhonetic;

  final String language;

  final bool separateTokensWithSpaces;

  final bool toneUnclear;



  const _SubstitutionCluster({

    required this.spoken,

    this.spokenTokens,

    this.correct,

    this.spokenPhonetic,

    this.correctPhonetic,

    this.showPhonetic = false,

    this.language = 'English',

    this.separateTokensWithSpaces = true,

    this.toneUnclear = false,

  });



  static const _wrongPhoneticColor = Color(0xFF991B1B);

  static const _unclearPhoneticColor = Color(0xFF92400E);



  @override

  Widget build(BuildContext context) {

    final surfaceColor = toneUnclear
        ? PronunciationInlineDiffText._unclearText
        : PronunciationInlineDiffText._wrongText;
    final bgColor = toneUnclear
        ? PronunciationInlineDiffText._unclearBg
        : PronunciationInlineDiffText._wrongBg;
    final phoneticColor =
        toneUnclear ? _unclearPhoneticColor : _wrongPhoneticColor;

    final heardPinyin = toneUnclear
        ? (spokenPhonetic?.trim().isNotEmpty == true
            ? spokenPhonetic!.trim()
            : (correct != null
                ? HanziToPinyinConverter.heardTonePinyin(correct!, spoken)
                : null) ??
            CjkSpokenPhonetic.phoneticForSpokenSurface(
              spoken,
              language: language,
            ))
        : null;

    final wrongPhonetic = (showPhonetic || toneUnclear) &&
            spoken.trim().isNotEmpty
        ? (heardPinyin ??
            CjkSpokenPhonetic.phoneticForSpokenSurface(
              spoken,
              language: language,
            ))
        : null;

    final useTokenPhonetic = (showPhonetic || toneUnclear) &&
        spokenTokens != null &&
        spokenTokens!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (toneUnclear)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '불명확',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: surfaceColor.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                ),
                if (heardPinyin != null && heardPinyin.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    heardPinyin,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: PronunciationInlineDiffText._phoneticFontSize,
                      fontWeight: FontWeight.w700,
                      color: phoneticColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.12),
            borderRadius: PronunciationInlineDiffText._chipRadius,
          ),
          child: Padding(
            padding: PronunciationInlineDiffText._chipPadding,
            child: spokenTokens != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SpokenInlineDiffText(
                        tokens: spokenTokens!,
                        textAlign: TextAlign.center,
                        separateTokensWithSpaces: separateTokensWithSpaces,
                      ),
                      if (useTokenPhonetic) ...[
                        const SizedBox(height: 4),
                        _SpokenInlineDiffPhonetic(
                          tokens: spokenTokens!,
                          language: language,
                          textAlign: TextAlign.center,
                          separateTokensWithSpaces: separateTokensWithSpaces,
                        ),
                      ] else if ((showPhonetic || toneUnclear) &&
                          (wrongPhonetic?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 4),
                        Text(
                          wrongPhonetic!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:
                                PronunciationInlineDiffText._phoneticFontSize,
                            fontWeight: FontWeight.w500,
                            color: phoneticColor.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  )
                : (showPhonetic || toneUnclear)
                    ? _PhraseChip(
                        surface: spoken,
                        phonetic: toneUnclear ? null : wrongPhonetic,
                        surfaceColor: surfaceColor,
                        surfaceWeight: FontWeight.bold,
                        phoneticColor: phoneticColor,
                        phoneticOpacity: 0.8,
                        strikethrough: !toneUnclear,
                      )
                    : Text(
                        spoken,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:
                              PronunciationInlineDiffText._surfaceFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: PronunciationInlineDiffText
                              ._surfaceLetterSpacing,
                          color: surfaceColor,
                          decoration: toneUnclear
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          decorationColor: surfaceColor,
                          decorationThickness: 1.4,
                          height: 1.3,
                        ),
                      ),
          ),
        ),
        if (correct != null) ...[
          const SizedBox(height: PronunciationInlineDiffText._clusterGap),
          const Center(
            child: Icon(
              Icons.arrow_downward_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(height: PronunciationInlineDiffText._clusterGap),
          _CorrectChip(
            label: correct!,
            phonetic: correctPhonetic,
            showPhonetic: showPhonetic,
            expand: true,
          ),
        ],
      ],
    );
  }

}



/// 누락·정답 표시용 초록 소프트 글래스 칩.

class _CorrectChip extends StatelessWidget {

  final String label;

  final String? phonetic;

  final bool showPhonetic;

  final bool expand;



  const _CorrectChip({

    required this.label,

    this.phonetic,

    this.showPhonetic = false,

    this.expand = false,

  });



  @override

  Widget build(BuildContext context) {

    final chip = DecoratedBox(

      decoration: BoxDecoration(

        color: PronunciationInlineDiffText._correctBg.withValues(alpha: 0.15),

        borderRadius: PronunciationInlineDiffText._chipRadius,

      ),

      child: Padding(

        padding: PronunciationInlineDiffText._chipPadding,

        child: showPhonetic

            ? _PhraseChip(

                surface: label,

                phonetic: phonetic,

                surfaceColor: PronunciationInlineDiffText._correctText,

                surfaceWeight: FontWeight.bold,

              )

            : Text(

                label,

                textAlign: TextAlign.center,

                style: const TextStyle(

                  fontSize: PronunciationInlineDiffText._surfaceFontSize,

                  fontWeight: FontWeight.bold,

                  letterSpacing: PronunciationInlineDiffText._surfaceLetterSpacing,

                  color: PronunciationInlineDiffText._correctText,

                  height: 1.3,

                ),

              ),

      ),

    );

    if (expand) {
      return SizedBox(width: double.infinity, child: chip);
    }
    return chip;
  }

}

