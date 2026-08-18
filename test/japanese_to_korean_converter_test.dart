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

    test('手伝い 한자 구문을 변환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('お手伝いましょうか'),
        '오테츠다이마쇼우카',
      );
    });

    test('변환 불가 한자만 있으면 null을 반환한다', () {
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('齟齬'),
        isNull,
      );
    });

    test('일부 한자만 미등록이어도 null — 남은 글자로 거짓 부분 발음을 만들지 않는다', () {
      // '対応'・'怒'는 사전에 없음. 'の'만 남겨 '노'라는 엉뚱한 부분 발음을
      // 보여주면 안 되고, 전체를 변환 실패로 처리해야 한다.
      expect(
        JapaneseToKoreanConverter.transliterateOrNull('対応の怒りましょうか'),
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
