import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/shared/widgets/pronunciation_inline_diff_text.dart';

void main() {
  group('pronunciationMatchedWordCount', () {
    test('공통 단어 수를 반환한다', () {
      expect(
        pronunciationMatchedWordCount(
          targetText: 'This is security work',
          spokenText: "it's security work",
        ),
        2,
      );
    });
  });
}
