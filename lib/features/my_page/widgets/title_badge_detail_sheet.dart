import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models/title_badge.dart';
import 'title_badge_hero_fx.dart';
import 'title_badge_tile.dart';

/// 뱃지 타일 탭 시 화면 중앙에 뜨는 Glassmorphic 오버레이 상세 팝업.
Future<void> showTitleBadgeDetailDialog(BuildContext context, TitleBadge badge) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _TitleBadgeDetailDialog(badge: badge);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}

class _TitleBadgeDetailDialog extends StatefulWidget {
  final TitleBadge badge;

  const _TitleBadgeDetailDialog({required this.badge});

  @override
  State<_TitleBadgeDetailDialog> createState() =>
      _TitleBadgeDetailDialogState();
}

class _TitleBadgeDetailDialogState extends State<_TitleBadgeDetailDialog> {
  static const _horizontalPadding = 48.0; // 좌우 패딩 24 × 2

  String _formatUnlockedAt(DateTime? date) {
    if (date == null) return '';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d 획득';
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final stampWidth = badge.stampWidthForHeight(kTitleBadgePopupStampHeight);
    final dialogMaxWidth = math.max(400.0, stampWidth + _horizontalPadding);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogMaxWidth),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.none,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 글래스 배경만 BackdropFilter — 애니메이션 위젯은 형제 레이어로 분리
                  // (BackdropFilter 자식에 두면 Web에서 FX repaint가 멈추는 이슈 방지)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TitleBadgeHeroFx(
                          badge: badge,
                          height: kTitleBadgePopupStampHeight,
                          enableEntranceBounce: badge.isUnlocked,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: BadgeGoldTheme.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (badge.isUnlocked) ...[
                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: BadgeGoldTheme.ink.withValues(alpha: 0.62),
                            ),
                          ),
                          if (badge.unlockedAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _formatUnlockedAt(badge.unlockedAt),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: BadgeGoldTheme.amberDeep
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            '어떻게 획득하나요?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: BadgeGoldTheme.amberDeep
                                  .withValues(alpha: 0.95),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: BadgeGoldTheme.ink.withValues(alpha: 0.62),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _BadgeProgressBar(percent: badge.progressPercent),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BadgeGoldTheme.ink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeProgressBar extends StatelessWidget {
  final double percent;

  const _BadgeProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final ratio = (percent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '달성 진도율',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: BadgeGoldTheme.ink.withValues(alpha: 0.45),
              ),
            ),
            Text(
              '${percent.round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: BadgeGoldTheme.amberDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: BadgeGoldTheme.paperEdge),
                FractionallySizedBox(
                  widthFactor: ratio,
                  alignment: Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          BadgeGoldTheme.amber,
                          BadgeGoldTheme.champagne,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
