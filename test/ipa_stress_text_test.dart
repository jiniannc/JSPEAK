import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/features/dashboard/dashboard_palette.dart';
import 'package:jspeak/shared/widgets/ipa_stress_text.dart';

void main() {
  const base = TextStyle(fontSize: 15);

  TextSpan? findSpanContaining(List<TextSpan> spans, String text) {
    for (final span in spans) {
      if (span.text?.contains(text) ?? false) return span;
    }
    return null;
  }

  test('souvenir 주강세 음절 nɪə만 라임색', () {
    final spans = IpaStressText.buildStressSpans('[ˌsuːvəˈnɪə]', base);
    final stressed = findSpanContaining(spans, 'nɪ');
    expect(stressed, isNotNull);
    expect(stressed!.style?.color, DashboardPalette.lime);
    expect(stressed.style?.fontWeight, FontWeight.w800);
  });

  test('복합 발음에서 각 단어의 주강세 음절만 강조', () {
    final spans =
        IpaStressText.buildStressSpans('[ɪˈmɜːrdʒənsi ˈeksɪt roʊ]', base);
    final mer = findSpanContaining(spans, 'mɜːr');
    final eks = findSpanContaining(spans, 'eks');
    expect(mer?.style?.color, DashboardPalette.lime);
    expect(eks?.style?.color, DashboardPalette.lime);
  });

  test('주강세 없는 음절은 옅은 청록', () {
    final spans = IpaStressText.buildStressSpans('[ɪˈmɜːrdʒənsi]', base);
    final unstressed = findSpanContaining(spans, 'ɪ');
    expect(
      unstressed?.style?.color,
      DashboardPalette.teal.withValues(alpha: 0.55),
    );
  });
}
