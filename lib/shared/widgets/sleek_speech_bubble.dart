import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 둥근 몸통 + 꼬리가 이어진 슬릭 말풍선 (테두리 없음).
class SleekSpeechBubblePainter extends CustomPainter {
  final List<Color> gradient;
  final Color shadowColor;
  final double shadowStrength;
  final bool tailAtTop;
  final bool showTail;
  final double cornerRadius;

  const SleekSpeechBubblePainter({
    required this.gradient,
    required this.shadowColor,
    this.shadowStrength = 0.2,
    this.tailAtTop = false,
    this.showTail = true,
    this.cornerRadius = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 11.0;
    const tailHeight = 8.0;
    final radius = cornerRadius;

    if (!showTail) {
      _paintRoundedRect(canvas, size, radius);
      return;
    }

    if (tailAtTop) {
      _paintBubble(
        canvas: canvas,
        size: size,
        radius: radius,
        tailWidth: tailWidth,
        tailHeight: tailHeight,
        bodyTop: tailHeight,
        bodyBottom: size.height,
        tailCenterY: tailHeight,
        tailTipY: 0,
      );
    } else {
      _paintBubble(
        canvas: canvas,
        size: size,
        radius: radius,
        tailWidth: tailWidth,
        tailHeight: tailHeight,
        bodyTop: 0,
        bodyBottom: size.height - tailHeight,
        tailCenterY: size.height - tailHeight,
        tailTipY: size.height - tailHeight + tailHeight + 1.5,
      );
    }
  }

  void _paintRoundedRect(Canvas canvas, Size size, double radius) {
    final fillTop = gradient.first;
    final fillBottom = gradient.length > 1 ? gradient.last : gradient.first;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    canvas.drawShadow(
      path,
      shadowColor.withValues(alpha: shadowStrength),
      10,
      false,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45)),
    );
    canvas.restore();
  }

  void _paintBubble({
    required Canvas canvas,
    required Size size,
    required double radius,
    required double tailWidth,
    required double tailHeight,
    required double bodyTop,
    required double bodyBottom,
    required double tailCenterY,
    required double tailTipY,
  }) {
    final tailCenterX = size.width * 0.54;
    final fillTop = gradient.first;
    final fillBottom = gradient.length > 1 ? gradient.last : gradient.first;
    final bodyHeight = bodyBottom - bodyTop;

    final bubblePath = Path();

    if (tailAtTop) {
      bubblePath
        ..moveTo(tailCenterX - tailWidth / 2, bodyTop)
        ..quadraticBezierTo(
          tailCenterX,
          tailTipY,
          tailCenterX + tailWidth / 2,
          bodyTop,
        )
        ..lineTo(size.width - radius, bodyTop)
        ..arcToPoint(
          Offset(size.width, bodyTop + radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, bodyBottom - radius)
        ..arcToPoint(
          Offset(size.width - radius, bodyBottom),
          radius: Radius.circular(radius),
        )
        ..lineTo(radius, bodyBottom)
        ..arcToPoint(
          Offset(0, bodyBottom - radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(0, bodyTop + radius)
        ..arcToPoint(
          Offset(radius, bodyTop),
          radius: Radius.circular(radius),
        )
        ..close();
    } else {
      bubblePath
        ..moveTo(radius, bodyTop)
        ..lineTo(size.width - radius, bodyTop)
        ..arcToPoint(
          Offset(size.width, bodyTop + radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, bodyBottom - radius)
        ..arcToPoint(
          Offset(size.width - radius, bodyBottom),
          radius: Radius.circular(radius),
        )
        ..lineTo(tailCenterX + tailWidth / 2, bodyBottom)
        ..quadraticBezierTo(
          tailCenterX,
          tailTipY,
          tailCenterX - tailWidth / 2,
          bodyBottom,
        )
        ..lineTo(radius, bodyBottom)
        ..arcToPoint(
          Offset(0, bodyBottom - radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(0, bodyTop + radius)
        ..arcToPoint(
          Offset(radius, bodyTop),
          radius: Radius.circular(radius),
        )
        ..close();
    }

    canvas.drawShadow(
      bubblePath,
      shadowColor.withValues(alpha: shadowStrength),
      10,
      false,
    );

    canvas.drawPath(
      bubblePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ).createShader(Rect.fromLTWH(0, bodyTop, size.width, bodyHeight)),
    );

    canvas.save();
    canvas.clipPath(bubblePath);
    canvas.drawRect(
      Rect.fromLTWH(0, bodyTop, size.width, bodyHeight * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, bodyTop, size.width, bodyHeight * 0.45)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SleekSpeechBubblePainter oldDelegate) {
    return oldDelegate.shadowStrength != shadowStrength ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.gradient != gradient ||
        oldDelegate.tailAtTop != tailAtTop ||
        oldDelegate.showTail != showTail ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

/// 주사위 힌트·시나리오 빈칸 힌트 등에 쓰는 그라데이션 말풍선.
class SleekSpeechBubble extends StatefulWidget {
  final List<Color> gradient;
  final Color shadowColor;
  final Widget child;
  final bool animate;
  final int staggerIndex;
  final bool tailAtTop;
  final bool float;
  final bool showTail;
  final double cornerRadius;
  final EdgeInsetsGeometry? contentPadding;

  const SleekSpeechBubble({
    super.key,
    required this.gradient,
    required this.shadowColor,
    required this.child,
    this.animate = true,
    this.staggerIndex = 0,
    this.tailAtTop = false,
    this.float = true,
    this.showTail = true,
    this.cornerRadius = 20,
    this.contentPadding,
  });

  @override
  State<SleekSpeechBubble> createState() => _SleekSpeechBubbleState();
}

class _SleekSpeechBubbleState extends State<SleekSpeechBubble>
    with TickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 520);
  static const _floatDuration = Duration(milliseconds: 2200);

  late final AnimationController _enterController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );
    _floatController = AnimationController(
      vsync: this,
      duration: _floatDuration,
    );

    if (widget.animate) {
      Future<void>.delayed(
        Duration(milliseconds: 80 + widget.staggerIndex * 120),
        () {
          if (!mounted) return;
          _enterController.forward(from: 0);
          if (widget.float) {
            _floatController.repeat(reverse: true);
          }
        },
      );
    } else {
      _enterController.value = 1;
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _floatController]),
      builder: (context, _) {
        final enterT = widget.animate
            ? Curves.easeOutBack.transform(_enterController.value.clamp(0.0, 1.0))
            : 1.0;
        final floatY = widget.float
            ? math.sin(_floatController.value * math.pi) * 2.5
            : 0.0;
        final shadowStrength = widget.float
            ? 0.18 + 0.1 * math.sin(_floatController.value * math.pi)
            : 0.2;

        return IgnorePointer(
          ignoring: widget.animate && _enterController.value < 0.04,
          child: Opacity(
            opacity: widget.animate
                ? _enterController.value.clamp(0.0, 1.0)
                : 1.0,
            child: Transform.translate(
              offset: Offset(0, floatY + (widget.animate ? 10 * (1 - enterT) : 0)),
              child: Transform.scale(
                scale: widget.animate ? 0.78 + 0.22 * enterT : 1.0,
                alignment: widget.tailAtTop
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: CustomPaint(
                  painter: SleekSpeechBubblePainter(
                    gradient: widget.gradient,
                    shadowColor: widget.shadowColor,
                    shadowStrength: shadowStrength,
                    tailAtTop: widget.tailAtTop,
                    showTail: widget.showTail,
                    cornerRadius: widget.cornerRadius,
                  ),
                  child: Padding(
                    padding: widget.contentPadding ??
                        (widget.showTail
                            ? (widget.tailAtTop
                                ? const EdgeInsets.fromLTRB(14, 17, 14, 9)
                                : const EdgeInsets.fromLTRB(14, 9, 14, 17))
                            : const EdgeInsets.fromLTRB(14, 10, 14, 10)),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
