import 'package:flutter/material.dart';

/// 로고 아래 3점 로딩 인디케이터.
class SplashThreeDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double spacing;

  const SplashThreeDots({
    super.key,
    required this.color,
    this.dotSize = 7,
    this.spacing = 8,
  });

  @override
  State<SplashThreeDots> createState() => _SplashThreeDotsState();
}

class _SplashThreeDotsState extends State<SplashThreeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 960),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  double _dotScale(int index) {
    final phase = (_pulse.value + index * 0.22) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.55 + 0.45 * Curves.easeInOut.transform(wave);
  }

  double _dotOpacity(int index) {
    final phase = (_pulse.value + index * 0.22) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.35 + 0.65 * Curves.easeInOut.transform(wave);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Opacity(
                opacity: _dotOpacity(i),
                child: Transform.scale(
                  scale: _dotScale(i),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.35),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (i != 2) SizedBox(width: widget.spacing),
            ],
          ],
        );
      },
    );
  }
}
