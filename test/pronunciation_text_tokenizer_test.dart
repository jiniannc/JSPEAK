import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/pronunciation_text_tokenizer.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('PronunciationTextTokenizer', () {
    test('일본어 무공백 문장은 구문 단위로 분리한다', () {
      expect(
        PronunciationTextTokenizer.tokenize(
          '日付と便名を',
          language: 'Japanese',
        ),
        ['日付と', '便名を'],
      );
    });

    test('슬래시 구간은 구간 단위로 분리한다', () {
      expect(
        PronunciationTextTokenizer.tokenize(
          'Chicken / Beef',
          language: 'English',
        ),
        ['Chicken', 'Beef'],
      );
    });
  });

  group('pronunciation diff helpers', () {
    test('90점대여도 틀린 단어가 있으면 diff를 감지한다', () {
      expect(
        pronunciationHasWordDiff(
          targetText: 'May I see your boarding pass?',
          spokenText: 'May I sea your boarding pass',
          language: 'English',
        ),
        isTrue,
      );
    });

    test('텍스트 완벽 일치 시 acoustic mismatch 판별', () {
      expect(
        pronunciationIsTextPerfectMatch(
          targetText: 'May I see your boarding pass?',
          spokenText: 'May I see your boarding pass?',
          language: 'English',
        ),
        isTrue,
      );
      expect(
        pronunciationHasWordDiff(
          targetText: 'May I see your boarding pass?',
          spokenText: 'May I see your boarding pass?',
          language: 'English',
        ),
        isFalse,
      );
    });

    test('CJK 무공백 문장에서도 diff 토큰이 생성된다', () {
      final tokens = buildPronunciationInlineDiffTokens(
        targetText: 'お願いします',
        spokenText: 'おねがいします',
        language: 'Japanese',
      );
      expect(tokens, isNotEmpty);
    });
  });
}
