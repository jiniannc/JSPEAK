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

  /// 정답 확정 후에도 표정이 충분히 보이도록 hero 대비 약 15%만 축소.
  static const compactSize = 116.0;
  static const heroSize = 136.0;
  static const resizeDuration = Duration(milliseconds: 560);
  static const resizeCurve = Curves.easeOutBack;

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
      r + saturation,
      g,
      b,
      0,
      0,
      r,
      g + saturation,
      b,
      0,
      0,
      r,
      g,
      b + saturation,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final targetT = muted ? 0.0 : 1.0;

    final image = Image.asset(
      assetPath,
      // hero/compact 전환 중 decode 크기가 바뀌면 서로 다른 ImageProvider로
      // 취급되어 기존 이미지가 사라진 뒤 다시 나타난다. 항상 같은 고해상도
      // 캐시를 재사용해 한 프레임도 끊기지 않게 한다.
      cacheWidth: 480,
      filterQuality: FilterQuality.medium,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.sentiment_satisfied_alt_rounded,
        size: size * 0.72,
        color: accentColor.withValues(alpha: 0.45),
      ),
    );

    return AnimatedContainer(
      width: size,
      height: size,
      duration: resizeDuration,
      curve: resizeCurve,
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: targetT, end: targetT),
        duration: const Duration(milliseconds: 520),
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
