import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/chapter_asset_path.dart';

void main() {
  group('resolveChapterAssetPath', () {
    test('maps language-prefixed sheet filenames to bundled assets', () {
      expect(
        resolveChapterAssetPath('assets/images/ch_boarding.png'),
        'assets/images/boarding.webp',
      );
      expect(
        resolveChapterAssetPath('sent_ch_boarding.png'),
        'assets/images/boarding.webp',
      );
      expect(
        resolveChapterAssetPath('word_ch_meal.png'),
        'assets/images/meal.webp',
      );
    });

    test('prepends assets/images for filename only', () {
      expect(
        resolveChapterAssetPath('boarding.png'),
        'assets/images/boarding.webp',
      );
    });

    test('keeps bundled webp filenames', () {
      expect(
        resolveChapterAssetPath('boarding.webp'),
        'assets/images/boarding.webp',
      );
    });

    test('normalizes legacy learninghub icons subfolder', () {
      expect(
        resolveChapterAssetPath('learninghub icons/boarding.png'),
        'assets/images/boarding.webp',
      );
      expect(
        resolveChapterAssetPath('assets/images/learninghub icons/seat.png'),
        'assets/images/seat.webp',
      );
    });

    test('strips duplicate assets prefix', () {
      expect(
        resolveChapterAssetPath('assets/assets/images/boarding.png'),
        'assets/images/boarding.webp',
      );
    });

    test('returns empty for non-image text', () {
      expect(resolveChapterAssetPath('기내 탑승 안내'), '');
      expect(resolveChapterAssetPath(''), '');
    });
  });
}
