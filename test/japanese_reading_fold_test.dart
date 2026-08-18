import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/japanese_reading_fold.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('JapaneseReadingFold', () {
    test('締め → しめ (정답 가나 오라클)', () {
      expect(
        JapaneseReadingFold.fold(
          'シートベルトをお締めください',
          'シートベルトをおしめください。',
        ),
        'シートベルトをおしめください',
      );
    });

    test('下さい → ください', () {
      expect(
        JapaneseReadingFold.fold('下さい', 'ください'),
        'ください',
      );
    });

    test('표시용 surface 매핑 — 접힌 구간이 STT 한자로 복원', () {
      const spoken = 'シートベルトをお締めください';
      const target = 'シートベルトをおしめください。';
      final fold = JapaneseReadingFold.foldWithMap(spoken, target);
      expect(fold.folded, 'シートベルトをおしめください');

      // 「しめ」에 해당하는 spoken surface 는 「締め」
      final shimeStart = fold.folded.indexOf('しめ');
      final surface = JapaneseReadingFold.spokenSurfaceForFoldRange(
        fold,
        spoken,
        foldStart: shimeStart,
        foldEnd: shimeStart + 2,
      );
      expect(surface, '締め');
    });
  });

  test('下げ→酒げ STT 한자 오기 — 동치로 접힘', () {
    expect(
      JapaneseReadingFold.fold(
        'お酒げしてもよろしいですか',
        'お下げしてもよろしいですか。',
      ),
      'お下げしてもよろしいですか',
    );
  });

  test('앞부분 생략 — 정답 접두를 거짓으로 채우지 않음', () {
    expect(
      JapaneseReadingFold.fold(
        'お戻しください',
        'テーブルをおもどしください。',
      ),
      'おもどしください',
    );
  });

  test('もの→者 — 같은 읽기면 동치, 모노 중복 없음', () {
    const target = 'そのままお席でお待ちください。お手伝いできる者を呼んでまいります。';
    const spoken = 'そのままお席でお待ちくださいお手伝いできるものを読んで参ります';
    const pronunciation =
        '소노마마 오세키데 오마치 쿠다사이. 오테즈다이 데키루 모노오 욘데 마이리마스.';

    expect(
      JapaneseReadingFold.fold(
        spoken,
        'そのままお席でお待ちくださいお手伝いできる者を呼んでまいります',
      ),
      'そのままお席でお待ちくださいお手伝いできる者を呼んでまいります',
    );

    final tokens = buildCjkSentenceInlineDiffTokens(
      targetText: target,
      spokenText: spoken,
      language: 'Japanese',
      koreanPronunciation: pronunciation,
    );

    final spokenPhonetic = tokens.map((t) {
      return switch (t) {
        PronunciationInlineDiffMatch(:final phonetic) => phonetic ?? '',
        PronunciationInlineDiffCorrection(:final spokenPhonetic) =>
          spokenPhonetic ?? '',
        PronunciationInlineDiffMissing() => '',
      };
    }).join();

    expect(spokenPhonetic.contains('모노모노'), isFalse);
    expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
  });

  test('결과 diff — 締め는 오답이 아니고 시메 병음 유지', () {
    const target = 'シートベルトをおしめください。';
    const spoken = 'シートベルトをお締めください';
    const pronunciation = '시-토베루토 오시메쿠다사이.';

    final tokens = buildCjkSentenceInlineDiffTokens(
      targetText: target,
      spokenText: spoken,
      language: 'Japanese',
      koreanPronunciation: pronunciation,
    );

    expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
    expect(tokens.whereType<PronunciationInlineDiffMissing>(), isEmpty);

    final surface = tokens
        .whereType<PronunciationInlineDiffMatch>()
        .map((t) => t.word)
        .join();
    expect(surface, contains('締め'));

    final phonetic = tokens
        .whereType<PronunciationInlineDiffMatch>()
        .map((t) => t.phonetic ?? '')
        .join();
    expect(phonetic, contains('시메'));

    final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
      sentence: target,
      spokenText: spoken,
      language: 'Japanese',
    );
    expect(score, greaterThanOrEqualTo(95));
  });
}
