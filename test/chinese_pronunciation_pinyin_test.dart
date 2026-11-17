import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/cjk_spoken_phonetic.dart';
import 'package:jspeak/core/utils/hanzi_to_pinyin_converter.dart';
import 'package:jspeak/core/utils/scenario_answer_compare.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('HanziToPinyinConverter', () {
    test('STT 오답 한자를 성조 병음으로 변환', () {
      expect(
        HanziToPinyinConverter.transliterateOrNull('欢迎当机'),
        'huān yíng dāng jī',
      );
    });
  });

  group('Chinese wrong chip pinyin', () {
    const target = '欢迎登机';
    const spoken = '欢迎当机';
    const pronunciation = 'huān yíng dēng jī';

    test('오답 칩 spokenPhonetic에 성조 병음 포함', () {
      expect(
        CjkSpokenPhonetic.phoneticForSpokenSurface(
          spoken,
          language: 'Chinese',
        ),
        'huān yíng dāng jī',
      );
    });

    test('diff 토큰 오답 칩에 병음 매핑', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: spoken,
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );

      final corrections = tokens.whereType<PronunciationInlineDiffCorrection>();
      expect(corrections, isNotEmpty);

      for (final c in corrections) {
        if (c.spoken.contains('当机') || c.spoken.contains('当')) {
          expect(c.spokenPhonetic, isNotNull);
          expect(c.toneUnclear, isFalse);
        }
      }
    });
  });

  group('Chinese homophone grading', () {
    const target = '欢迎登机';
    const pronunciation = 'huān yíng dēng jī';

    test('병음·성조가 같으면 다른 한자도 동음으로 판정', () {
      expect(HanziToPinyinConverter.isHomophone('登', '灯'), isTrue);
      expect(HanziToPinyinConverter.isHomophone('银行', '银航'), isTrue);
    });

    test('성조만 다르면 동음 아님·성조 전용 차이', () {
      expect(HanziToPinyinConverter.isHomophone('登', '当'), isFalse);
      expect(HanziToPinyinConverter.isHomophone('买', '卖'), isFalse);
      expect(HanziToPinyinConverter.isToneOnlyDiff('买', '卖'), isTrue);
      expect(HanziToPinyinConverter.isToneOnlyDiff('登', '等'), isTrue);
      expect(HanziToPinyinConverter.isToneOnlyDiff('登', '当'), isFalse);
    });

    test('동음 한자로 인식돼도 100점·정답', () {
      expect(
        pronunciationAccuracyPercent(
          targetText: target,
          spokenText: '欢迎灯机',
          language: 'Chinese',
          koreanPronunciation: pronunciation,
        ),
        100,
      );
      expect(
        ScenarioAnswerCompare.isCorrect(
          spoken: '欢迎灯机',
          correct: target,
          language: 'Chinese',
        ),
        isTrue,
      );
      expect(
        ScenarioAnswerCompare.similarityPercent(
          spoken: '欢迎灯机',
          correct: target,
          language: 'Chinese',
        ),
        100,
      );
    });

    test('동음 한자 칩은 오답으로 표시되지 않음', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: '欢迎灯机',
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );
      expect(tokens.whereType<PronunciationInlineDiffCorrection>(), isEmpty);
    });

    test('성조만 다른 한자는 부분 점수(0.9)만 감점', () {
      // 登(dēng) → 等(děng): 음절 같고 성조만 다름. 4글자 중 1글자 → 97.5 → 98
      final score = pronunciationAccuracyPercent(
        targetText: target,
        spokenText: '欢迎等机',
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );
      expect(score, 98);
      expect(score, lessThan(100));
      expect(
        ScenarioAnswerCompare.charMatchCredit('登', '等', 'Chinese'),
        ScenarioAnswerCompare.toneMismatchCredit,
      );
    });

    test('성조만 다른 칩은 toneUnclear + 들은 성조 병음', () {
      expect(
        HanziToPinyinConverter.heardTonePinyin('登', '等'),
        'děng',
      );
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: '欢迎等机',
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );
      final corrections = tokens.whereType<PronunciationInlineDiffCorrection>();
      expect(corrections, isNotEmpty);
      expect(corrections.any((c) => c.toneUnclear), isTrue);
      final toneChips = corrections.where((c) => c.spoken.contains('等'));
      expect(toneChips, isNotEmpty);
      for (final c in toneChips) {
        expect(c.toneUnclear, isTrue);
        expect(c.spokenPhonetic, isNotNull);
        expect(c.spokenPhonetic, contains('děng'));
      }
    });

    test('음절이 다른 한자는 여전히 큰 감점·toneUnclear 아님', () {
      // 登(dēng) → 当(dāng): 음절 자체 다름
      final score = pronunciationAccuracyPercent(
        targetText: target,
        spokenText: '欢迎当机',
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );
      expect(score, lessThan(98));
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: target,
        spokenText: '欢迎当机',
        language: 'Chinese',
        koreanPronunciation: pronunciation,
      );
      final corrections = tokens.whereType<PronunciationInlineDiffCorrection>();
      expect(corrections, isNotEmpty);
      expect(
        corrections.where((c) => c.spoken.contains('当')).every(
              (c) => !c.toneUnclear,
            ),
        isTrue,
      );
    });
  });
}
