import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_pronunciation_phrase.dart';
import 'package:jspeak/core/utils/japanese_to_korean_converter.dart';
import 'package:jspeak/core/utils/word_token_alignment.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('JapaneseToKoreanConverter', () {
    test('한자 除菌 → 히라가나 → 한글 2단계 변환', () {
      expect(JapaneseToKoreanConverter.toHiragana('除菌'), 'じょきん');
      expect(JapaneseToKoreanConverter.transliterateOrNull('除菌'), '죠킨');
    });

    test('除菌を STT 구문 변환', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('除菌を'),
        '죠킨오',
      );
    });

    test('미등록 한자는 건너뛰고 나머지는 변환', () {
      expect(JapaneseToKoreanConverter.toHiragana('除菌齟'), contains('じょきん'));
    });
  });

  group('CjkPronunciationPhraseBuilder — 부분 일치', () {
    const target = 'お一人様ずつご搭乗券を確認しております。';
    const spoken = 'ホイトリス様ずつこと除菌を確認しております';
    const pronunciation = '오히토리사마즈츠 고토-죠-켄오 카쿠닌시테 오리마스';

    test('마지막 구문은 Green match', () {
      final alignment = CjkPronunciationPhraseBuilder.alignPhrases(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spoken,
        language: 'Japanese',
      );

      final matches = alignment.ops
          .where((op) => op.kind == WordAlignmentKind.match)
          .toList();
      expect(matches, isNotEmpty);
      expect(
        matches.any((op) => (op.targetWord ?? '').contains('確認')),
        isTrue,
      );
    });

    test('부분 일치 시 0점이 아닌 점수', () {
      final lexicon = CjkPronunciationPhraseBuilder.buildLexicon(
        sentence: target,
        pronunciation: pronunciation,
        language: 'Japanese',
      );
      final matched = CjkPronunciationPhraseBuilder.alignPhrases(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spoken,
        language: 'Japanese',
      ).matchedTargetCount;

      final score = ((matched / lexicon.length) * 100).round();
      expect(score, greaterThanOrEqualTo(30));
      expect(score, lessThan(100));
    });

    test('diff UI에서 마지막 구문은 Match 칩', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (t) => t.word.contains('確認'),
            ),
        isTrue,
      );
    });

    test('오답 칩 除菌を 에 한글 발음 병기', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('除菌を'),
        isNotNull,
      );
    });

    test('100% 완벽 일치 시 diff 토큰이 비어 있지 않다', () {
      const target = '除菌を確認しております。';
      const spoken = '除菌を確認しております。';
      const pronunciation = '죠-켄오 카쿠닌시테 오리마스';

      expect(
        pronunciationIsTextPerfectMatch(
          targetText: target,
          spokenText: spoken,
          language: 'Japanese',
          koreanPronunciation: pronunciation,
        ),
        isTrue,
      );

      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(tokens, isNotEmpty);
      expect(tokens.every((t) => t is PronunciationInlineDiffMatch), isTrue);
    });
  });

  group('CjkPronunciationPhraseBuilder — 座席 부분 일치', () {
    const target = '鶴川に座席でございます';
    const spoken = '通路側の座席でございます。';
    const pronunciation = '츠루가와니 자세키데고자이마스';

    test('뒤쪽 구문 座席でございます 는 Match', () {
      final alignment = CjkPronunciationPhraseBuilder.alignPhrases(
        sentence: target,
        pronunciation: pronunciation,
        spokenText: spoken,
        language: 'Japanese',
      );

      final matches = alignment.ops
          .where((op) => op.kind == WordAlignmentKind.match)
          .toList();
      expect(matches, isNotEmpty);
      expect(
        matches.any((op) => (op.targetWord ?? '').contains('座席')),
        isTrue,
      );
    });

    test('앞부분 오답·뒷부분 정답으로 칩 분할', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Japanese',
        koreanPronunciation: pronunciation,
      );

      expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isNotEmpty);
      expect(
        tokens.whereType<PronunciationInlineDiffMatch>().any(
              (t) => t.word.contains('座席'),
            ),
        isTrue,
      );
      expect(
        tokens.whereType<PronunciationInlineDiffCorrection>().any(
              (t) => (t.spoken).contains('通路') || (t.correct ?? '').contains('鶴川'),
            ),
        isTrue,
      );
    });

    test('글자 LCS 기반 부분 점수 — 0점 아님', () {
      final score = CjkPronunciationPhraseBuilder.accuracyPercentByCharacters(
        sentence: target,
        spokenText: spoken,
        language: 'Japanese',
      );
      expect(score, greaterThanOrEqualTo(60));
      expect(score, lessThan(100));
    });

    test('STT가 한 덩어리여도 뒤쪽 구문 추출', () {
      const spokenBlob = '通路側の座席でございます';
      final mapped = CjkPronunciationPhraseBuilder.mapSpokenSegmentsToTarget(
        spokenSegments: [spokenBlob],
        targetPhrases: CjkPronunciationPhraseBuilder.segmentSurface(
          target,
          language: 'Japanese',
        ),
        language: 'Japanese',
      );

      expect(
        mapped.any((s) => s.contains('座席でございます')),
        isTrue,
      );
    });
  });
}
