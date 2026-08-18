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

    test('이미 ご가 붙어있으면 중복 적용하지 않는다 (ご搭乗券 → ごご搭乗券 방지)', () {
      expect(
        JapaneseSttFixMap.apply('ご搭乗券をお願いいたします'),
        'ご搭乗券をお願いいたします',
      );
    });

    test('접두 ご 누락 시에는 정상적으로 보정한다', () {
      expect(
        JapaneseSttFixMap.apply('搭乗券をお願いいたします'),
        'ご搭乗券をお願いいたします',
      );
    });
  });
}
