import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/avatar_asset_path.dart';
import 'package:jspeak/data/models/scenario_line.dart';

void main() {
  group('resolveAvatarAssetPath', () {
    test('bare avatar key adds webp under assets/images', () {
      expect(
        resolveAvatarAssetPath('avatar_normal'),
        'assets/images/avatar_normal.webp',
      );
    });

    test('filename only resolves under assets/images', () {
      expect(
        resolveAvatarAssetPath('avatar_happy.png'),
        'assets/images/avatar_happy.webp',
      );
    });

    test('full asset path maps png to bundled webp', () {
      expect(
        resolveAvatarAssetPath('assets/images/avatar_wink.png'),
        'assets/images/avatar_wink.webp',
      );
    });

    test('male crew avatarm_ prefix resolves under assets/images', () {
      expect(
        resolveAvatarAssetPath('avatarm_snacks'),
        'assets/images/avatarm_snacks.webp',
      );
      expect(
        resolveAvatarAssetPath('avatarm_creditcard.png'),
        'assets/images/avatarm_creditcard.webp',
      );
    });
  });

  group('ScenarioLine avatar_image', () {
    test('parses avatar_image from json', () {
      final line = ScenarioLine.fromJson({
        'scenario_id': 'en_test',
        'order': 2,
        'speaker': 'Crew',
        'text_ko': 'ko',
        'text_target': 'en',
        'language': 'English',
        'avatar_image': 'avatar_normal',
      });

      expect(line.avatarImage, 'assets/images/avatar_normal.webp');
    });
  });
}
