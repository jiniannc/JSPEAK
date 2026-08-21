import 'package:flutter/material.dart';

/// 말풍선 **우측 상단** peeking — 이미지 최하단이 말풍선 상단 테두리에 맞닿음.
class ScenarioBubbleAvatar extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color accentColor;
  /// 정답 확정 등으로 축소된 상태 — 크기와 함께 색감도 살짝 흐려짐.
  final bool muted;

  const ScenarioBubbleAvatar({
    super.key,
    required this.assetPath,
    required this.size,
    required this.accentColor,
    this.muted = false,
  });

  // 💡 정답 전환 시 너무 확 작아지는 느낌을 줄이기 위해 80 -> 100으로 완화.
  static const compactSize = 100.0;
  static const heroSize = 136.0;

  static const peekInsetRight = 22.0;
  /// 승객 말풍선 최대 폭 비율 (화면 너비 대비).
  static const passengerMaxWidthFactor = 0.70;
  /// 승무원 말풍선 최대 폭 비율 — IntrinsicWidth로 내용만큼만, 필요 시까지 확장.
  static const crewMaxWidthFactor = 0.88;

  static double sizeFor(bool isHero) => isHero ? heroSize : compactSize;

  /// 채도 매트릭스 — 1=원색, 0=흑백 (0.55 근처면 살짝 흐려진 느낌).
  static List<double> _saturationMatrix(double saturation) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final invSat = 1 - saturation;
    final r = invSat * lumR;
    final g = invSat * lumG;
    final b = invSat * lumB;
    return [
      r + saturation, g, b, 0, 0,
      r, g + saturation, b, 0, 0,
      r, g, b + saturation, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (size * 3.75).round().clamp(200, 480);
    final targetT = muted ? 0.0 : 1.0;

    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.sentiment_satisfied_alt_rounded,
        size: size * 0.72,
        color: accentColor.withValues(alpha: 0.45),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: targetT, end: targetT),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final opacity = 0.84 + 0.16 * t;
          final saturation = 0.5 + 0.5 * t;
          return Opacity(
            opacity: opacity,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(_saturationMatrix(saturation)),
              child: child,
            ),
          );
        },
        child: image,
      ),
    );
  }
}
