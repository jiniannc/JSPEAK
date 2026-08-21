import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/language_palette.dart';

/// 학습 허브 상단 — 단일 트랙 3색 fill + 유리 질감 비행기 인디케이터.
class HubTripleModeProgressTrack extends StatelessWidget {
  final double wordProgress;
  final double sentenceProgress;
  final double scenarioProgress;

  const HubTripleModeProgressTrack({
    super.key,
    required this.wordProgress,
    required this.sentenceProgress,
    required this.scenarioProgress,
  });

  static const double trackHeight = HubGrooveProgressTrack.trackHeight;
  static const double indicatorWidth = 48.0;
  static const double indicatorHeight = 28.0;
  /// 비행기 하단이 트랙 위쪽과 겹치는 정도.
  static const double indicatorTrackOverlap = 8.0;
  /// 상하 비행 애니메이션 여유.
  static const double indicatorFloatClearance = 3.0;
  static const double indicatorLeftNudge = -8.0;
  static const double trackBandHeight =
      indicatorHeight + trackHeight - indicatorTrackOverlap + indicatorFloatClearance;
  static const double countGap = 10.0;
  static const double countHeight = HubGrooveProgressTrack.countHeight;
  static const double legendGap = 5.0;
  static const double legendHeight = 11.0;

  /// 단어 스와이프 결과 도넛 링과 같은 네온 그라데이션 팔레트.
  static const wordGradient = [Color(0xFFFBBF24), Color(0xFFF59E0B)];
  static const sentenceGradient = [Color(0xFF38BDF8), Color(0xFF0284C7)];
  static const scenarioGradient = [Color(0xFF10B981), Color(0xFF06B6D4)];

  static Color get wordColor => wordGradient.last;
  static Color get sentenceColor => sentenceGradient.last;
  static Color get scenarioColor => scenarioGradient.last;

  static const totalBlockHeight =
      trackBandHeight + countGap + countHeight + legendGap + legendHeight;

  double get _overallProgress =>
      ((wordProgress + sentenceProgress + scenarioProgress) / 3).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final palette = context.requireLanguagePalette;
    final surface = Color.lerp(palette.canvas, Colors.white, 0.35)!;
    final groove = Color.lerp(surface, const Color(0xFF64748B), 0.14)!;

    final word = wordProgress.clamp(0.0, 1.0);
    final sentence = sentenceProgress.clamp(0.0, 1.0);
    final scenario = scenarioProgress.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: trackBandHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _overallProgress),
                duration: HubGrooveProgressTrack._animationDuration,
                curve: Curves.easeOutCubic,
                builder: (context, animatedOverall, _) {
                  final wordW = width * word / 3;
                  final sentenceW = width * sentence / 3;
                  final scenarioW = width * scenario / 3;
                  // 전체 진행률(0~1)에 따라 트랙 위를 선형 이동 — clamp 구간 없이 일관.
                  final travel = math.max(0.0, width - indicatorWidth);
                  final indicatorLeft = (animatedOverall * travel + indicatorLeftNudge)
                      .clamp(indicatorLeftNudge, travel)
                      .toDouble();

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: trackHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            HubGrooveProgressTrack._trackRadius,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: groove,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.10),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              _UnifiedModeFill(
                                wordWidth: wordW,
                                sentenceWidth: sentenceW,
                                scenarioWidth: scenarioW,
                                wordGradient: wordGradient,
                                sentenceGradient: sentenceGradient,
                                scenarioGradient: scenarioGradient,
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: trackHeight * 0.45,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.16),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: indicatorLeft,
                        bottom: trackHeight - indicatorTrackOverlap,
                        width: indicatorWidth,
                        height: indicatorHeight,
                        child: const IgnorePointer(
                          child: _PlaneSvgIndicator(),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: countGap),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
              color: Color.lerp(
                palette.canvas,
                const Color(0xFF64748B),
                0.78,
              )!,
            ),
            children: [
              const TextSpan(text: '학습 진도율'),
              TextSpan(text: ' · ${(_overallProgress * 100).round()}%'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: legendGap),
        _TripleModeLegend(
          wordProgress: wordProgress,
          sentenceProgress: sentenceProgress,
          scenarioProgress: scenarioProgress,
        ),
      ],
    );
  }
}

/// `assets/images/plane.svg` — 프로그레스 인디케이터.
/// 웹에서는 SvgPicture + ColorFilter 조합이 투명해질 수 있어 fill 색을 그대로 쓴다.
class _PlaneSvgIndicator extends StatefulWidget {
  const _PlaneSvgIndicator();

  @override
  State<_PlaneSvgIndicator> createState() => _PlaneSvgIndicatorState();
}

class _PlaneSvgIndicatorState extends State<_PlaneSvgIndicator>
    with SingleTickerProviderStateMixin {
  static const assetPath = 'assets/images/plane.svg';

  late final AnimationController _flight;
  late final Animation<double> _bobY;
  late final Animation<double> _glideX;

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    final motion = CurvedAnimation(
      parent: _flight,
      curve: Curves.easeInOutSine,
    );
    _bobY = Tween<double>(begin: 1.2, end: -2.0).animate(motion);
    _glideX = Tween<double>(begin: -0.6, end: 0.9).animate(motion);
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = HubTripleModeProgressTrack.indicatorWidth;
    final h = HubTripleModeProgressTrack.indicatorHeight;

    Widget plane({double opacity = 1.0}) {
      return Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          assetPath,
          width: w,
          height: h,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          allowDrawingOutsideViewBox: true,
          clipBehavior: Clip.none,
        ),
      );
    }

    final body = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 2),
          child: plane(opacity: 0.14),
        ),
        plane(),
      ],
    );

    return AnimatedBuilder(
      animation: _flight,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_glideX.value, _bobY.value),
          child: child,
        );
      },
      child: body,
    );
  }
}

/// 단일 트랙 — 단어→문장→롤플레이 순으로 이어지는 3색 네온 fill.
class _UnifiedModeFill extends StatelessWidget {
  final double wordWidth;
  final double sentenceWidth;
  final double scenarioWidth;
  final List<Color> wordGradient;
  final List<Color> sentenceGradient;
  final List<Color> scenarioGradient;

  const _UnifiedModeFill({
    required this.wordWidth,
    required this.sentenceWidth,
    required this.scenarioWidth,
    required this.wordGradient,
    required this.sentenceGradient,
    required this.scenarioGradient,
  });

  @override
  Widget build(BuildContext context) {
    var offset = 0.0;
    final children = <Widget>[];

    void addSegment(double width, List<Color> gradientColors) {
      if (width <= 0.5) return;
      final start = offset;
      offset += width;
      final glow = gradientColors.last;
      children.add(
        Positioned(
          left: start,
          top: 0,
          bottom: 0,
          width: width,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.42),
                      blurRadius: 5,
                      spreadRadius: -0.5,
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: gradientColors,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.45,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.38),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addSegment(wordWidth, wordGradient);
    addSegment(sentenceWidth, sentenceGradient);
    addSegment(scenarioWidth, scenarioGradient);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: children,
    );
  }
}

class _TripleModeLegend extends StatelessWidget {
  final double wordProgress;
  final double sentenceProgress;
  final double scenarioProgress;

  const _TripleModeLegend({
    required this.wordProgress,
    required this.sentenceProgress,
    required this.scenarioProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: HubTripleModeProgressTrack.wordColor,
          label: '단어 ${(wordProgress * 100).round()}%',
        ),
        _LegendItem(
          color: HubTripleModeProgressTrack.sentenceColor,
          label: '문장 ${(sentenceProgress * 100).round()}%',
        ),
        _LegendItem(
          color: HubTripleModeProgressTrack.scenarioColor,
          label: '롤플레이 ${(scenarioProgress * 100).round()}%',
          isLast: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLast;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.38),
                  blurRadius: 3,
                  spreadRadius: -0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// 학습 허브 상단 진행률 — 움푹 파인 슬림 트랙 위에 비비드 원컬러 fill,
/// 리퀴드글래스 투명 렌즈가 진행 위치를 가리키는 인디케이터.
class HubGrooveProgressTrack extends StatelessWidget {
  final int current;
  final int total;

  const HubGrooveProgressTrack({
    super.key,
    required this.current,
    required this.total,
  });

  static const double trackHeight = 10.0;
  static const double outerHeight = 32.0;
  static const double lensWidth = 54.0;
  static const double lensHeight = 26.0;
  static const double countGap = 7.0;
  static const double countHeight = 14.0;
  static const double _trackRadius = 99.0;
  static const Duration _animationDuration = Duration(milliseconds: 600);

  /// 프로그레스 바 + 카운트 텍스트까지 포함한 고정 블록 높이.
  static const totalBlockHeight =
      outerHeight + countGap + countHeight;

  double get _progress {
    if (total <= 0) return 0;
    return (current / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.requireLanguagePalette;
    final surface = Color.lerp(palette.canvas, Colors.white, 0.35)!;
    final groove = Color.lerp(surface, const Color(0xFF64748B), 0.14)!;
    final accent = palette.primary;

    return SizedBox(
      height: outerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final travel = math.max(0.0, width - lensWidth);

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, _) {
              final lensLeft = travel * animatedProgress;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (outerHeight - trackHeight) / 2,
                    height: trackHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_trackRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: groove,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: animatedProgress,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: trackHeight * 0.42,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: lensLeft,
                    top: (outerHeight - lensHeight) / 2,
                    width: lensWidth,
                    height: lensHeight,
                    child: _LiquidGlassLens(
                      accent: accent,
                      progress: animatedProgress,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 트랙 위를 미끄러지는 리퀴드글래스 렌즈 — 블러 + 하이라이트 + 얇은
/// 테두리로 유리 두께감을 표현한다.
class _LiquidGlassLens extends StatelessWidget {
  final Color accent;
  final double progress;

  const _LiquidGlassLens({
    required this.accent,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HubGrooveProgressTrack.lensHeight / 2);

    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: kIsWeb ? 0.62 : 0.48),
          Colors.white.withValues(alpha: kIsWeb ? 0.28 : 0.16),
          accent.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.52, 1.0],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.78),
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 12,
          spreadRadius: -4,
        ),
      ],
    );

    final lensBody = Stack(
      fit: StackFit.expand,
      children: [
        // 렌즈 아래 fill이 살짝 굴절된 것처럼 보이게 하는 내부 색 띠.
        Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.72,
            heightFactor: 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.0),
                    accent.withValues(alpha: 0.55 + progress * 0.15),
                    accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: HubGrooveProgressTrack.lensWidth * 0.12,
          right: HubGrooveProgressTrack.lensWidth * 0.12,
          top: HubGrooveProgressTrack.lensHeight * 0.10,
          height: HubGrooveProgressTrack.lensHeight * 0.34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.82),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (kIsWeb) {
      return DecoratedBox(decoration: decoration, child: lensBody);
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: decoration.copyWith(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: lensBody,
        ),
      ),
    );
  }
}
