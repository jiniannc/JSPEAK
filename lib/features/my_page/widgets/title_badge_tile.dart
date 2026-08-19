import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/title_badge.dart';
import 'title_badge_detail_sheet.dart';

/// 칭호 뱃지 공용 골드 테마 (여권 · 상세 팝업 · 축하 다이얼로그에서 공유).
abstract final class BadgeGoldTheme {
  static const amberDeep = Color(0xFFD97706);
  static const amber = Color(0xFFF59E0B);
  static const champagne = Color(0xFFFCD34D);
  static const paper = Color(0xFFF8F5EF);
  static const paperEdge = Color(0xFFE2DED5);
  static const ink = Color(0xFF1E293B);
  static const ghost = Color(0xFF94A3B8);
}

/// 상세 팝업 · 축하 다이얼로그 공용 스탬프 height.
const kTitleBadgePopupStampHeight = 280.0;

/// 그리드(다운샘플) vs 팝업(레티나 최적 디코딩) 이미지 프로필.
enum TitleBadgeImageProfile {
  /// 3×3 그리드 — cacheWidth/Height 240 + FilterQuality.medium
  grid,
  /// 팝업·축하 다이얼로그 — cacheWidth/Height 600 (레티나 3×) + FilterQuality.medium
  detail,
}

/// 앱 전역 뱃지 PNG 렌더링 — height 기준, 가로는 aspectRatio에 따라 자연 확장.
class TitleBadgeImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double height;
  final double opacity;
  final double aspectRatio;
  final TitleBadgeImageProfile profile;

  const TitleBadgeImage({
    super.key,
    required this.imagePath,
    this.width,
    required this.height,
    this.opacity = 1,
    this.aspectRatio = 1,
    this.profile = TitleBadgeImageProfile.grid,
  });

  static const _gridCacheSize = 240;
  static const _detailCacheSize = 600;

  @override
  Widget build(BuildContext context) {
    final cacheHeight = switch (profile) {
      TitleBadgeImageProfile.grid => _gridCacheSize,
      TitleBadgeImageProfile.detail => _detailCacheSize,
    };
    final ratio = width != null && height > 0
        ? width! / height
        : aspectRatio.clamp(0.01, 10.0);
    final cacheWidth = (cacheHeight * ratio).round();

    return Opacity(
      opacity: opacity,
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.medium,
        isAntiAlias: true,
      ),
    );
  }
}

/// 3D 스탬프 자산 단독 렌더링 — height 기준, 가로형 PNG는 폭 자연 확장.
class TitleBadgeStamp extends StatelessWidget {
  final TitleBadge badge;
  final double height;
  final bool showGlow;
  final bool showLockOverlay;
  final TitleBadgeImageProfile profile;

  const TitleBadgeStamp({
    super.key,
    required this.badge,
    required this.height,
    this.showGlow = true,
    this.showLockOverlay = true,
    this.profile = TitleBadgeImageProfile.grid,
  });

  double get _stampWidth => badge.stampWidthForHeight(height);

  @override
  Widget build(BuildContext context) {
    if (!badge.isUnlocked) {
      return SizedBox(
        width: _stampWidth,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(height, height),
              painter: _StampBezelPainter(
                color: BadgeGoldTheme.paperEdge.withValues(alpha: 0.85),
                dashed: true,
              ),
            ),
            TitleBadgeImage(
              imagePath: badge.imagePath,
              height: height * 0.82,
              aspectRatio: badge.aspectRatio,
              opacity: 0.28,
              profile: profile,
            ),
            if (showLockOverlay)
              Icon(
                Icons.lock_rounded,
                size: height * 0.17,
                color: BadgeGoldTheme.ghost.withValues(alpha: 0.72),
              ),
          ],
        ),
      );
    }

    final image = TitleBadgeImage(
      imagePath: badge.imagePath,
      height: height,
      aspectRatio: badge.aspectRatio,
      profile: profile,
    );

    if (!showGlow) {
      return SizedBox(width: _stampWidth, height: height, child: image);
    }

    return SizedBox(
      width: _stampWidth,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: height * 0.88,
            height: height * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: BadgeGoldTheme.amber.withValues(alpha: 0.25),
                  blurRadius: height * 0.36,
                  spreadRadius: height * 0.08,
                ),
                BoxShadow(
                  color: BadgeGoldTheme.champagne.withValues(alpha: 0.18),
                  blurRadius: height * 0.22,
                  spreadRadius: height * 0.02,
                ),
              ],
            ),
          ),
          image,
        ],
      ),
    );
  }
}

/// 그리드용 뱃지 메달리온 — [TitleBadgeStamp] 래퍼.
class TitleBadgeMedallion extends StatelessWidget {
  final TitleBadge badge;
  final double height;

  const TitleBadgeMedallion({
    super.key,
    required this.badge,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return TitleBadgeStamp(
      badge: badge,
      height: height,
      showGlow: badge.isUnlocked,
    );
  }
}

/// 여권 칭호 그리드의 뱃지 1칸 — 잠금/해제 연출 + 탭 시 상세 팝업.
class TitleBadgeTile extends StatelessWidget {
  final TitleBadge badge;
  final double height;

  const TitleBadgeTile({super.key, required this.badge, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTitleBadgeDetailDialog(context, badge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TitleBadgeMedallion(badge: badge, height: height),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.15,
                fontWeight:
                    badge.isUnlocked ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: -0.1,
                color: badge.isUnlocked
                    ? BadgeGoldTheme.amberDeep
                    : BadgeGoldTheme.ghost,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StampBezelPainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _StampBezelPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    if (!dashed) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    const dash = 3.5;
    const gap = 3.0;
    final circumference = 2 * math.pi * radius;
    final segments = (circumference / (dash + gap)).ceil();

    for (var i = 0; i < segments; i++) {
      final startAngle = (i * (dash + gap) / radius);
      final sweep = dash / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampBezelPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
