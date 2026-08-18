import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// BackdropFilter 기반 시나리오 스타일 글래스 패널.
class TrueGlassPanel extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool nested;
  final Widget child;

  const TrueGlassPanel({
    super.key,
    required this.radius,
    required this.child,
    this.padding,
    this.margin,
    this.nested = false,
  });

  static const _glassShadow = Color(0x0F000000);
  static const _blurSigma = 12.0;
  static const _fillAlpha = 0.65;
  static const _nestedFillAlpha = 0.35;
  static const _glassBorderAlpha = 0.8;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.white.withValues(
        alpha: nested ? _nestedFillAlpha : _fillAlpha,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: nested
          ? null
          : Border.all(
              color: Colors.white.withValues(alpha: _glassBorderAlpha),
              width: 1.5,
            ),
    );

    final panel = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    // Flutter Web CanvasKit: BackdropFilter + hot restart 시 WebGL context lost
    // → LateInitializationError (_handledContextLostEvent). 블러 없이 동일 톤 유지.
    if (kIsWeb) {
      return Container(
        margin: margin,
        decoration: nested
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: const [
                  BoxShadow(
                    color: _glassShadow,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: decoration,
            child: panel,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: nested
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                BoxShadow(
                  color: _glassShadow,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
          ),
          child: DecoratedBox(
            decoration: decoration,
            child: panel,
          ),
        ),
      ),
    );
  }
}
