import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/japanese_stt_fix_map.dart';

void main() {
  group('JapaneseSttFixMap', () {
    test('後藤直近 → ご搭乗券', () {
      expect(
        JapaneseSttFixMap.apply('後藤直近をお願いいたします'),
        'ご搭乗券をお願いいたします',
      );
    });

    test('致します → いたします', () {
      expect(
        JapaneseSttFixMap.apply('お願い致します'),
        'お願いいたします',
      );
    });
  });
}
