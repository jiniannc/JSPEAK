import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/japanese_reading_fold.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  test('Visit Japan Web — 가타카나 STT를 라틴 브랜드로 접음', () {
    expect(
      JapaneseReadingFold.fold(
        'ベジットジャパンWEBのご登録はお済みでしょうか',
        'Visit Japan Webのご登録はお済みでしょうか？',
      ),
      'VisitJapanWebのご登録はお済みでしょうか',
    );
  });

  test('Visit Japan Web — STT anWEB 잡음에서도 고득점·빨간 칩 없음', () {
    const target = 'Visit Japan Webのご登録はお済みでしょうか？';
    const spoken = 'ベジットジャパンanWEBのご登録はお済みでしょうか';
    const pronunciation = '비짓^토자팡^웨부노 고토-로쿠와 오스미데쇼-까?';

    final tokens = buildCjkSentenceInlineDiffTokens(
      targetText: target,
      spokenText: spoken,
      language: 'Japanese',
      koreanPronunciation: pronunciation,
    );

    expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
    expect(tokens.whereType<PronunciationInlineDiffMissing>(), isEmpty);

    final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
      sentence: target,
      spokenText: spoken,
      language: 'Japanese',
    );
    expect(score, greaterThanOrEqualTo(90));
  });
}
