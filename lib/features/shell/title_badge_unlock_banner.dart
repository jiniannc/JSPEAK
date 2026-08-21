import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/shell_providers.dart';
import '../../app/title_badge_providers.dart';
import '../../data/models/title_badge.dart';
import '../my_page/widgets/title_badge_tile.dart';
import 'main_shell_tab_header.dart';

/// 학습 중 칭호 해제 시 — 루트 Navigator Overlay 최상단에 슬라이드 배너.
///
/// 전체 화면 학습(단어 스와이프·문장·시나리오)이 MainShell 위에 push되어도
/// 결과 바텀시트와 동시에 배너가 보이도록 OverlayEntry로 표시한다.
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
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBanners());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  TitleBadge? _badgeFor(String id) {
    for (final badge in ref.read(titleBadgesProvider)) {
      if (badge.id == id) return badge;
    }
    return null;
  }

  double _bannerTop(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final pushedOnRoot = rootNavigatorKey.currentState?.canPop() ?? false;
    if (pushedOnRoot) {
      return safeTop + 8;
    }
    return MainShellTabHeader.reservedHeight(context) + 6;
  }

  void _syncBanners() {
    if (!mounted) return;

    final tab = ref.read(shellTabIndexProvider);
    if (tab == MainShellTabHeader.kMyPageTabIndex) {
      _hideTimer?.cancel();
      if (ref.read(titleBadgeUnlockProvider).pendingBanners.isNotEmpty) {
        ref.read(titleBadgeUnlockProvider.notifier).dismissBanners();
      }
      if (_visibleBadgeId != null) {
        setState(() => _visibleBadgeId = null);
        _removeOverlay();
      }
      return;
    }

    final pending = ref.read(titleBadgeUnlockProvider).pendingBanners;
    if (pending.isEmpty) {
      if (_visibleBadgeId != null) {
        setState(() => _visibleBadgeId = null);
        _removeOverlay();
      }
      return;
    }

    final nextId = pending.first;
    if (_visibleBadgeId == nextId && _overlayEntry != null) return;

    _hideTimer?.cancel();
    setState(() => _visibleBadgeId = nextId);
    HapticFeedback.mediumImpact();
    _mountOverlay();

    _hideTimer = Timer(_displayDuration, () {
      if (!mounted) return;
      ref.read(titleBadgeUnlockProvider.notifier).acknowledgeBanner(nextId);
      if (_visibleBadgeId == nextId) {
        setState(() => _visibleBadgeId = null);
        _removeOverlay();
      }
    });
  }

  void _mountOverlay() {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final badgeId = _visibleBadgeId;
    final badge = badgeId == null ? null : _badgeFor(badgeId);
    if (badge == null) {
      _removeOverlay();
      return;
    }

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final top = _bannerTop(overlayContext);
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _TitleUnlockBanner(
              badge: badge,
              onTap: _dismissVisible,
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _dismissVisible() {
    final id = _visibleBadgeId;
    if (id == null) return;
    _hideTimer?.cancel();
    ref.read(titleBadgeUnlockProvider.notifier).acknowledgeBanner(id);
    setState(() => _visibleBadgeId = null);
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(titleBadgeUnlockProvider, (previous, next) => _syncBanners());
    ref.listen(shellTabIndexProvider, (previous, next) => _syncBanners());

    // OverlayEntry만 관리 — 레이아웃 공간은 차지하지 않는다.
    return const SizedBox.shrink();
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
