import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/language_palette.dart';
import '../../features/learning/widgets/learning_hub_chapter_mode_dock.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/jspeak_logo_color_mapper.dart';
import '../../shared/widgets/language_header_badge.dart';

/// 스플래시 구간에 헤더·학습 UI 에셋을 미리 디코드해 첫 전환 지연을 줄인다.
abstract final class AppAssetPreloader {
  static bool _warmedUp = false;

  static Future<void> warmUp(BuildContext context) async {
    if (_warmedUp) return;

    await Future.wait([
      _precacheHeaderLogos(context),
      ChapterModeDock.precacheModeIcons(context),
      LanguageHeaderBadge.precacheAll(context),
    ]);

    _warmedUp = true;
  }

  static Future<void> _precacheHeaderLogos(BuildContext context) async {
    const palettes = [
      LanguagePalette.english,
      LanguagePalette.japanese,
      LanguagePalette.chinese,
    ];

    Future<void> loadPalette(LanguagePalette palette) {
      return SvgAssetLoader(
        AppHeader.homeBrandLogoAsset,
        colorMapper: JspeakLogoColorMapper(
          logoAccent: palette.brandLogoAccent,
          wordmarkColor: palette.brandWordmark,
        ),
      ).loadBytes(context);
    }

    // Web CanvasKit — SVG isolate 병렬 디코드 시 picture dispose 충돌이 난다.
    if (kIsWeb) {
      for (final palette in palettes) {
        await loadPalette(palette);
      }
    } else {
      await Future.wait(palettes.map(loadPalette));
    }
  }
}
