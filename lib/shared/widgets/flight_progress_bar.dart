import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/language_palette.dart';

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
  static const _animationDuration = Duration(milliseconds: 600);

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
