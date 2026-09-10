import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// JSPEAKLOGO.svg — 언어별 accent / wordmark 색 치환.
class JspeakLogoColorMapper extends ColorMapper {
  const JspeakLogoColorMapper({
    required this.logoAccent,
    required this.wordmarkColor,
  });

  static const svgLogoAccent = Color(0xFF0755B8);
  static const svgWordmark = Color(0xFF191F50);

  final Color logoAccent;
  final Color wordmarkColor;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == svgLogoAccent) return logoAccent;
    if (color == svgWordmark) return wordmarkColor;
    return color;
  }

  @override
  bool operator ==(Object other) {
    return other is JspeakLogoColorMapper &&
        other.logoAccent == logoAccent &&
        other.wordmarkColor == wordmarkColor;
  }

  @override
  int get hashCode => Object.hash(logoAccent, wordmarkColor);
}
