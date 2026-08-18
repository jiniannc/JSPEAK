import 'package:flutter_test/flutter_test.dart';

import 'package:jspeak/core/utils/cjk_stt_segments.dart';

void main() {
  group('CjkSttSegments', () {
    test('parse splits CJK and romanization', () {
      final segments = CjkSttSegments.parse(
        'ご搭乗券 gotoujouken を onegai',
        'Japanese',
      );
      expect(segments.length, 4);
      expect(segments[0].text, 'ご搭乗券');
      expect(segments[0].isTargetScript, isTrue);
      expect(segments[1].text, ' gotoujouken ');
      expect(segments[1].isTargetScript, isFalse);
      expect(segments[2].text, 'を');
      expect(segments[2].isTargetScript, isTrue);
      expect(segments[3].isTargetScript, isFalse);
    });

    test('extractTargetScript removes pronunciation', () {
      final extracted = CjkSttSegments.extractTargetScript(
        'ご搭乗券 gotoujouken を onegai',
        'Japanese',
      );
      expect(extracted, 'ご搭乗券を');
    });

    test('extractTargetScript keeps QR when reference has QR', () {
      const reference = 'QRコードをスキャンしております';
      expect(
        CjkSttSegments.extractTargetScript(
          'QRコードをスキャンしております',
          'Japanese',
          referenceText: reference,
        ),
        reference,
      );
      expect(
        CjkSttSegments.extractTargetScript(
          'Q R コードをスキャンしております',
          'Japanese',
          referenceText: reference,
        ),
        reference,
      );
    });

    test('extractTargetScript keeps multi-word Latin brand from reference', () {
      const reference = 'Visit Japan Webのご登録はお済みでしょうか？';
      expect(
        CjkSttSegments.extractTargetScript(
          reference,
          'Japanese',
          referenceText: reference,
        ),
        'VISITJAPANWEBのご登録はお済みでしょうか',
      );
      expect(
        CjkSttSegments.extractTargetScript(
          'ベジットジャパンanWEBのご登録はお済みでしょうか',
          'Japanese',
          referenceText: reference,
        ),
        'ベジットジャパンWEBのご登録はお済みでしょうか',
      );
    });

    test('extractTargetScript without reference still strips QR', () {
      expect(
        CjkSttSegments.extractTargetScript(
          'QRコードをスキャンしております',
          'Japanese',
        ),
        'コードをスキャンしております',
      );
    });

    test('English passthrough', () {
      expect(
        CjkSttSegments.extractTargetScript('hello world', 'English'),
        'hello world',
      );
    });
  });
}
