import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/japanese_to_korean_converter.dart';

void main() {
  group('JapaneseToKoreanConverter', () {
    test('히라가나 STT 텍스트를 한글로 변환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('くろかわの'),
        '쿠로카와노',
      );
    });

    test('한자 STT 텍스트를 한글로 변환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('黒川の'),
        '쿠로카와노',
      );
    });

    test('除菌 2단계 변환', () {
      expect(JapaneseToKoreanConverter.toHiragana('除菌'), 'じょきん');
      expect(JapaneseToKoreanConverter.transliterateOrNull('除菌'), '죠킨');
    });

    test('助けてございます 구문을 변환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('助けてございます'),
        '타스케테고자이마스',
      );
    });

    test('변환 불가 한자만 있으면 null을 반환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('齟齬'),
        isNull,
      );
    });

    test('특수문자만 있으면 null을 반환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('。、'),
        isNull,
      );
    });
  });
}
