import 'package:flutter/material.dart';



import '../../core/utils/cjk_pronunciation_phrase.dart';

import '../../core/utils/cjk_stt_segments.dart';

import '../../core/utils/japanese_to_korean_converter.dart';

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



  const PronunciationInlineDiffCorrection({

    required this.spoken,

    this.correct,

    this.spokenPhonetic,

    this.correctPhonetic,

  });

}



class PronunciationInlineDiffMissing extends PronunciationInlineDiffToken {

  final String target;

  final String? phonetic;



  const PronunciationInlineDiffMissing(this.target, {this.phonetic});

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

  return [

    for (final op in ops)

      switch (op.kind) {

        WordAlignmentKind.match => () {

            final word = op.spokenWord ?? op.targetWord!;

            targetIdx++;

            return PronunciationInlineDiffMatch(

              word,

              phonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

                lexicon,

                op.targetWord ?? op.spokenWord ?? '',

              ),

            );

          }(),

        WordAlignmentKind.substitution => () {

            final targetWord = op.targetWord ?? '';

            final targetLexeme = targetIdx < lexicon.length

                ? lexicon[targetIdx]

                : CjkPhraseLexeme(surface: targetWord);

            final phraseIndex = targetIdx;

            targetIdx++;

            return PronunciationInlineDiffCorrection(

              spoken: op.spokenWord!,

              correct: op.targetWord,

              correctPhonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

                lexicon,

                targetWord,

              ),

              spokenPhonetic:

                  CjkPronunciationPhraseBuilder.spokenPhoneticForSubstitution(

                rawSpoken: spokenText,

                spokenSurface: op.spokenWord!,

                target: targetLexeme,

                language: language,

                phraseIndex: phraseIndex,

              ),

            );

          }(),

        WordAlignmentKind.insertion => PronunciationInlineDiffCorrection(

            spoken: op.spokenWord!,

            spokenPhonetic:

                CjkPronunciationPhraseBuilder.spokenPhoneticForInsertion(

              spokenSurface: op.spokenWord!,

              language: language,

            ),

          ),

        WordAlignmentKind.deletion => () {

            final targetWord = op.targetWord!;

            targetIdx++;

            return PronunciationInlineDiffMissing(

              targetWord,

              phonetic: CjkPronunciationPhraseBuilder.phoneticForSurface(

                lexicon,

                targetWord,

              ),

            );

          }(),

      },

  ];

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

    return CjkPronunciationPhraseBuilder.accuracyPercent(

      sentence: targetText,

      pronunciation: koreanPronunciation,

      spokenText: spokenText,

      language: language,

    );

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

  static const _correctText = Color(0xFF059669);

  static const _correctBg = Color(0xFF10B981);

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



    if (tokens.isEmpty) {
      final fallback = spokenText.trim();
      if (fallback.isEmpty) return const SizedBox.shrink();
      return Text(
        fallback,
        textAlign: textAlign,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _matchColor,
          height: 1.35,
        ),
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
            for (final token in tokens)
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
                ) =>
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _SubstitutionCluster(
                      spoken: spoken,
                      correct: correct,
                      spokenPhonetic: spokenPhonetic,
                      correctPhonetic: correctPhonetic,
                      showPhonetic: _showPhonetic,
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



/// 오발음/치환 — 붉은 오답 칩 ➔ 초록 정답 칩.

class _SubstitutionCluster extends StatelessWidget {

  final String spoken;

  final String? correct;

  final String? spokenPhonetic;

  final String? correctPhonetic;

  final bool showPhonetic;



  const _SubstitutionCluster({

    required this.spoken,

    this.correct,

    this.spokenPhonetic,

    this.correctPhonetic,

    this.showPhonetic = false,

  });



  static const _wrongPhoneticColor = Color(0xFF991B1B);



  @override

  Widget build(BuildContext context) {

    final wrongPhonetic = spokenPhonetic ??

        (showPhonetic && spoken.trim().isNotEmpty

            ? JapaneseToKoreanConverter.transliterateOrNull(

                spoken,

                language: 'Japanese',

              )

            : null);



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      mainAxisSize: MainAxisSize.min,

      children: [

        DecoratedBox(

          decoration: BoxDecoration(

            color: PronunciationInlineDiffText._wrongBg.withValues(alpha: 0.12),

            borderRadius: PronunciationInlineDiffText._chipRadius,

          ),

          child: Padding(

            padding: PronunciationInlineDiffText._chipPadding,

            child: showPhonetic

                ? _PhraseChip(

                    surface: spoken,

                    phonetic: wrongPhonetic,

                    surfaceColor: PronunciationInlineDiffText._wrongText,

                    surfaceWeight: FontWeight.bold,

                    phoneticColor: _wrongPhoneticColor,

                    phoneticOpacity: 0.8,

                    strikethrough: true,

                  )

                : Text(

                    spoken,

                    textAlign: TextAlign.center,

                    style: TextStyle(

                      fontSize: PronunciationInlineDiffText._surfaceFontSize,

                      fontWeight: FontWeight.bold,

                      letterSpacing:
                          PronunciationInlineDiffText._surfaceLetterSpacing,

                      color: PronunciationInlineDiffText._wrongText,

                      decoration: TextDecoration.lineThrough,

                      decorationColor: PronunciationInlineDiffText._wrongText,

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

