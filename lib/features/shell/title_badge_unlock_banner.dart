import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_providers.dart';
import '../../app/title_badge_providers.dart';
import '../../data/models/title_badge.dart';
import '../my_page/widgets/title_badge_tile.dart';
import 'main_shell_tab_header.dart';

/// 학습 중 칭호 해제 시 헤더 아래 슬라이드 배너.
class TitleBadgeUnlockBannerHost extends ConsumerStatefulWidget {
  const TitleBadgeUnlockBannerHost({super.key});

  @override
  ConsumerState<TitleBadgeUnlockBannerHost> createState() =>
      _TitleBadgeUnlockBannerHostState();
}

class _TitleBadgeUnlockBannerHostState
    extends ConsumerState<TitleBadgeUnlockBannerHost> {
  static const _displayDuration = Duration(milliseconds: 4200);

  String? _visibleBadgeId;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBanners());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  TitleBadge? _badgeFor(String id) {
    for (final badge in ref.read(titleBadgesProvider)) {
      if (badge.id == id) return badge;
    }
    return null;
  }

  void _syncBanners() {
    if (!mounted) return;
    final tab = ref.read(shellTabIndexProvider);
    // 마이페이지에선 축하 다이얼로그가 담당.
    if (tab == MainShellTabHeader.kMyPageTabIndex) {
      _hideTimer?.cancel();
      if (ref.read(titleBadgeUnlockProvider).pendingBanners.isNotEmpty) {
        ref.read(titleBadgeUnlockProvider.notifier).dismissBanners();
      }
      if (_visibleBadgeId != null) {
        setState(() => _visibleBadgeId = null);
      }
      return;
    }

    final pending = ref.read(titleBadgeUnlockProvider).pendingBanners;
    if (pending.isEmpty) {
      if (_visibleBadgeId != null) {
        setState(() => _visibleBadgeId = null);
      }
      return;
    }

    final nextId = pending.first;
    if (_visibleBadgeId == nextId) return;

    _hideTimer?.cancel();
    setState(() => _visibleBadgeId = nextId);
    HapticFeedback.mediumImpact();
    _hideTimer = Timer(_displayDuration, () {
      if (!mounted) return;
      ref.read(titleBadgeUnlockProvider.notifier).acknowledgeBanner(nextId);
      if (_visibleBadgeId == nextId) {
        setState(() => _visibleBadgeId = null);
      }
    });
  }

  void _dismissVisible() {
    final id = _visibleBadgeId;
    if (id == null) return;
    _hideTimer?.cancel();
    ref.read(titleBadgeUnlockProvider.notifier).acknowledgeBanner(id);
    setState(() => _visibleBadgeId = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(titleBadgeUnlockProvider, (previous, next) => _syncBanners());
    ref.listen(shellTabIndexProvider, (previous, next) => _syncBanners());

    final badgeId = _visibleBadgeId;
    final badge = badgeId == null ? null : _badgeFor(badgeId);
    final top = MainShellTabHeader.reservedHeight(context);

    return Positioned(
      top: top + 6,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: badge == null,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 380),
          curve: badge == null ? Curves.easeInCubic : Curves.easeOutCubic,
          offset: badge == null ? const Offset(0, -1.15) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: badge == null ? 0 : 1,
            child: badge == null
                ? const SizedBox(height: 64)
                : _TitleUnlockBanner(
                    badge: badge,
                    onTap: _dismissVisible,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TitleUnlockBanner extends StatelessWidget {
  const _TitleUnlockBanner({
    required this.badge,
    required this.onTap,
  });

  final TitleBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stampHeight = 44.0;
    final stampWidth = badge.stampWidthForHeight(stampHeight);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: kIsWeb
              ? _bannerBody(stampHeight, stampWidth)
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: _bannerBody(stampHeight, stampWidth),
                ),
        ),
      ),
    );
  }

  Widget _bannerBody(double stampHeight, double stampWidth) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        child: Row(
          children: [
            TitleBadgeImage(
              imagePath: badge.imagePath,
              height: stampHeight,
              width: stampWidth,
              aspectRatio: badge.aspectRatio,
              profile: TitleBadgeImageProfile.grid,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '칭호 획득',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '「${badge.title}」를 획득했습니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
