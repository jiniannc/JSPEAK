import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/chapter_asset_path.dart';

void main() {
  group('resolveChapterAssetPath', () {
    test('keeps full assets path', () {
      expect(
        resolveChapterAssetPath('assets/images/ch_boarding.png'),
        'assets/images/ch_boarding.png',
      );
    });

    test('prepends assets/images for filename only', () {
      expect(
        resolveChapterAssetPath('boarding.png'),
        'assets/images/boarding.png',
      );
    });

    test('normalizes legacy learninghub icons subfolder', () {
      expect(
        resolveChapterAssetPath('learninghub icons/boarding.png'),
        'assets/images/boarding.png',
      );
      expect(
        resolveChapterAssetPath('assets/images/learninghub icons/seat.png'),
        'assets/images/seat.png',
      );
    });

    test('strips duplicate assets prefix', () {
      expect(
        resolveChapterAssetPath('assets/assets/images/boarding.png'),
        'assets/images/boarding.png',
      );
    });

    test('returns empty for non-image text', () {
      expect(resolveChapterAssetPath('기내 탑승 안내'), '');
      expect(resolveChapterAssetPath(''), '');
    });
  });
}
