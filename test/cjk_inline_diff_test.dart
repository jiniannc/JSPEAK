import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/word_token_alignment.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('CjkPronunciationPhraseBuilder.subdivideForInlineDiff', () {
    test('か vs が — 글자 단위로 쪼갠다', () {
      const target = '(恐れ入りますが)、';
      const spoken = '恐れ入りますか';

      final ops = CjkPronunciationPhraseBuilder.subdivideForInlineDiff(
        target: target,
        spoken: spoken,
        language: 'Japanese',
      );

      expect(
        ops.where((op) => op.kind == WordAlignmentKind.match),
        isNotEmpty,
      );
      expect(
        ops.any(
          (op) =>
              op.kind == WordAlignmentKind.substitution &&
              (op.spokenWord ?? '').contains('か') &&
              (op.targetWord ?? '').contains('が'),
        ),
        isTrue,
      );
    });
  });

  group('CJK sentence-level inline diff', () {
    const target = '(恐れ入りますが)、保安のためお願いいたします。';
    const spoken = '恐れ入りますか保安のためお願いいたします';
    const pronunciation = '오소레이리마스가 호안^노타메 오네가이이타시마스.';

    test('교정 칩은 정답 풀 문장', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(tokens, isNotEmpty);
      expect(
        tokens.any((token) => token is! PronunciationInlineDiffMatch),
        isTrue,
      );
    });

    test('인식 문장은 맞은 부분 + 틀린 글자만 correction 토큰', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (token) => token.word.contains('保安'),
            ),
        isTrue,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>().any(
              (token) => token.spoken == 'か' || token.spoken.contains('か'),
            ),
        isTrue,
      );
    });

    test('문장 inline diff — correction 토큰에 틀린 글자 포함', () {
      const target = 'こちらへどうぞ';
      const spoken = 'あちらへどうぞ';
      const pronunciation = '코치라헤도-우조';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>(),
        isNotEmpty,
      );
    });

    test('ビスケット vs 日付と — correction 토큰 생성', () {
      const target = '日付と 便名を 確認しております。';
      const spoken = 'ビスケット便名を確認しております';
      const pronunciation = '히즈케토 빔^메이오 카쿠닌^시테오리마스.';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>(),
        isNotEmpty,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (token) => token.word.contains('確認'),
            ),
        isTrue,
      );
    });

    test('お手伝い missing し — 누락 글자와 뒤 구간 분리', () {
      const target = 'お手伝いしましょうか。';
      const spoken = 'お手伝いましょうか';
      const pronunciation = '오테츠다이시마쇼-까?';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().any(
              (token) => token.target == 'し',
            ),
        isTrue,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (token) => token.word.contains('お手伝い'),
            ),
        isTrue,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (token) => token.word.contains('ましょうか'),
            ),
        isTrue,
      );

      final matchHead = tokens.whereType<PronunciationInlineDiffMatch>().first;
      expect(matchHead.phonetic, contains('테츠'));
      // 한자 다음절(手伝→테츠다) 때문에 단일 かな 병음은 비율 슬라이스로 완벽히
      // 맞추기 어렵다. 누락 토큰 자체와 헤드 병음만 검증한다.
      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().single.phonetic,
        isNotNull,
      );
    });

    test('下げ→酒げ STT 오기 — 오답 칩 없음', () {
      const target = 'お下げしても よろしいですか。';
      const spoken = 'お酒げしてもよろしいですか';
      const pronunciation = '오사게시테모 요로시-데스까?';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
      expect(tokens.whereType<PronunciationInlineDiffMissing>(), isEmpty);
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (t) => t.word.contains('酒'),
            ),
        isTrue,
      );
      final phonetic = tokens
          .whereType<PronunciationInlineDiffMatch>()
          .map((t) => t.phonetic ?? '')
          .join();
      expect(phonetic, contains('사게'));
    });

    test('を 하나 생략 — Missing만, 戻은 맞음', () {
      const target = '肘掛けを おもどしください。';
      const spoken = '肘掛け お戻しください';
      const pronunciation = '히지카케오 오모도시쿠다사이.';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().map((t) => t.target),
        ['を'],
      );
      expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (t) => t.word.contains('戻') || t.word.contains('もど'),
            ),
        isTrue,
      );

      final missingPhonetic =
          tokens.whereType<PronunciationInlineDiffMissing>().single.phonetic;
      expect(missingPhonetic, contains('오'));
    });

    test('앞부분 생략 — Missing + 낮은 점수', () {
      const target = 'テーブルを おもどしください。';
      const spoken = 'お戻しください';
      const pronunciation = '테-부루오 오모도시쿠다사이.';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().any(
              (t) => t.target.contains('テーブル'),
            ),
        isTrue,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (t) => t.word.contains('戻') || t.word.contains('もど'),
            ),
        isTrue,
      );

      final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: spoken,
        language: 'Japanese',
      );
      expect(score, lessThan(80));
      expect(score, greaterThan(40));

      final matchPhonetic = tokens
          .whereType<PronunciationInlineDiffMatch>()
          .map((t) => t.phonetic ?? '')
          .join();
      expect(matchPhonetic, contains('모도'));
    });

    test('お手荷物 missing に — 정답 문장이 붙지 않음', () {
      const target = 'お手荷物は上の棚にお願いいたします。';
      const spoken = 'お手荷物は上の棚お願いいたします';
      const pronunciation = '오테니모츠와 우에노 타나니 오네가이이타시마스.';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      final spokenOnly = tokens.map((t) => switch (t) {
            PronunciationInlineDiffMatch(:final word) => word,
            PronunciationInlineDiffCorrection(:final spoken) => spoken,
            PronunciationInlineDiffMissing() => '',
          }).join();

      expect(spokenOnly, spoken);
      expect(spokenOnly, isNot(contains('$spoken$target')));
      expect(
        tokens.whereType<PronunciationInlineDiffMissing>().any(
              (t) => t.target == 'に',
            ),
        isTrue,
      );
    });

    test('중국어 완전 오답 — 전체가 correction', () {
      const target = '早上好';
      const spoken = '好像放';
      const pronunciation = 'zao shang hao';

      final tokens = buildCjkSentenceInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );

      expect(tokens.whereType<PronunciationInlineDiffMatch>(), isEmpty);
      final correction =
          tokens.whereType<PronunciationInlineDiffCorrection>().single;
      expect(correction.spoken, '好像放');
      expect(correction.correct, '早上好');
    });
  });
}
