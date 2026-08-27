import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Flutter Web CanvasKit에서 [BackdropFilter]가 WebGL context lost·셰이더 오류를
/// 반복 유발한다. Web은 반투명 채움만, 네이티브는 블러를 유지한다.
class WebSafeBackdropBlur extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final ImageFilter? filter;

  const WebSafeBackdropBlur({
    super.key,
    required this.child,
    required this.sigmaX,
    required this.sigmaY,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;
    return BackdropFilter(
      filter: filter ?? ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: child,
    );
  }
}
