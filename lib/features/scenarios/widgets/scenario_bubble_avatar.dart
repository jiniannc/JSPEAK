import 'package:flutter/material.dart';

import '../../../data/models/scenario.dart';

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

  static const _maxCacheWidth = 384;
  static const _cacheMultiplier = 1.75;

  static final Set<String> _precachedPaths = {};

  static double sizeFor(bool isHero) => isHero ? heroSize : compactSize;

  static bool isPrecached(String assetPath) =>
      assetPath.isNotEmpty && _precachedPaths.contains(assetPath);

  static int cacheWidthFor({
    required double displaySize,
    required double devicePixelRatio,
  }) {
    return (displaySize * devicePixelRatio * _cacheMultiplier)
        .round()
        .clamp(1, _maxCacheWidth);
  }

  /// precache·표시 모두 동일 provider — decode 크기가 달라지면 캐시 미스가 난다.
  static ImageProvider imageProvider(
    String assetPath, {
    required double displaySize,
    required double devicePixelRatio,
  }) {
    return ResizeImage(
      AssetImage(assetPath),
      width: cacheWidthFor(
        displaySize: displaySize,
        devicePixelRatio: devicePixelRatio,
      ),
    );
  }

  static Iterable<String> avatarPathsFrom(Iterable<Scenario> scenarios) sync* {
    for (final scenario in scenarios) {
      for (final line in scenario.lines) {
        final path = line.avatarImage;
        if (path.isNotEmpty) yield path;
      }
    }
  }

  static Future<void> precachePaths(
    BuildContext context,
    Iterable<String> paths, {
    double displaySize = heroSize,
  }) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pending = paths.where((p) => p.isNotEmpty && !_precachedPaths.contains(p));
    if (pending.isEmpty) return Future.value();

    return Future.wait(
      pending.map((path) async {
        try {
          await precacheImage(
            imageProvider(
              path,
              displaySize: displaySize,
              devicePixelRatio: dpr,
            ),
            context,
          );
          _precachedPaths.add(path);
        } catch (_) {}
      }),
    );
  }

  static Future<void> precacheScenarios(
    BuildContext context,
    Iterable<Scenario> scenarios,
  ) {
    return precachePaths(context, avatarPathsFrom(scenarios).toSet());
  }

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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = Image(
      image: imageProvider(
        assetPath,
        displaySize: heroSize,
        devicePixelRatio: dpr,
      ),
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

    final sizedImage = AnimatedContainer(
      width: size,
      height: size,
      duration: resizeDuration,
      curve: resizeCurve,
      alignment: Alignment.bottomCenter,
      child: image,
    );

    if (!muted) return sizedImage;

    return AnimatedContainer(
      width: size,
      height: size,
      duration: resizeDuration,
      curve: resizeCurve,
      alignment: Alignment.bottomCenter,
      child: Opacity(
        opacity: 0.84,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturationMatrix(0.5)),
          child: image,
        ),
      ),
    );
  }
}
