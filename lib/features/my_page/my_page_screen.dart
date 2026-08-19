import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/learning_hub_language_provider.dart';
import '../../app/learning_providers.dart';
import '../../app/my_page_report_providers.dart';
import '../../app/my_page_stats_providers.dart';
import '../../app/providers.dart';
import '../../app/title_badge_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/title_badge.dart';
import '../shell/floating_island_nav_bar.dart';
import '../shell/main_shell_tab_header.dart';
import 'widgets/badge_unlock_dialog.dart';
import 'widgets/interactive_passport_booklet.dart';
import 'widgets/my_page_section_header.dart';
import '../dictionary/widgets/bookmark_vault_modal.dart';

/// 마이페이지 — 학습 리포트 · 보관함 · 앱 데이터 관리.
class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  bool _celebrationShowing = false;

  void _handleBadgeUnlockState(
    TitleBadgeUnlockState? previous,
    TitleBadgeUnlockState next,
  ) {
    if (_celebrationShowing) return;
    if (next.pendingCelebrations.isEmpty) return;

    final badgeId = next.pendingCelebrations.first;
    final badges = ref.read(titleBadgesProvider);
    TitleBadge? badge;
    for (final b in badges) {
      if (b.id == badgeId) {
        badge = b;
        break;
      }
    }

    if (badge == null) {
      ref.read(titleBadgeUnlockProvider.notifier).acknowledgeCelebration(
            badgeId,
          );
      return;
    }

    _celebrationShowing = true;
    final unlockedBadge = badge;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showBadgeUnlockDialog(context, unlockedBadge);
      if (mounted) {
        ref
            .read(titleBadgeUnlockProvider.notifier)
            .acknowledgeCelebration(badgeId);
      }
      _celebrationShowing = false;
    });
  }

  Future<void> _syncContent() async {
    final syncing = ref.read(contentProvider).value?.syncing ?? false;
    if (syncing) return;

    await ref.read(contentProvider.notifier).sync();
    if (!mounted) return;
    final error = ref.read(contentProvider).value?.syncError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 실패: $error')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('최신 기내 표현 데이터가 동기화되었습니다!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    ref.invalidate(myPagePassportReportProvider);
  }

  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('v${AppConfig.appVersion} — 최신 버전입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TitleBadgeUnlockState>(
      titleBadgeUnlockProvider,
      _handleBadgeUnlockState,
    );

    final metrics = Active5Layout.of(context);
    final language = ref.watch(learningHubLanguageProvider);
    final passportReport = ref.watch(myPagePassportReportProvider);
    final favoriteCount = ref.watch(dictionaryFavoriteCountProvider);
    final reviewCount = ref.watch(reviewNeededSentenceCountProvider);
    final contentState = ref.watch(contentProvider).value;
    final syncing = contentState?.syncing ?? false;

    return DeviceScaffold(
      safeAreaBottom: false,
      safeAreaTop: false,
      backgroundColor: Colors.transparent,
      body: MainShellTabBody(
        child: AnimatedLanguageScope(
          language: language,
          builder: (context, palette) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding.left,
              0,
              metrics.pagePadding.right,
              28 + FloatingIslandNavBar.scrollBottomPadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (passportReport == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  InteractivePassportBooklet(
                    report: passportReport,
                    selectedLanguage: language,
                    accent: palette.primary,
                    onLanguageSelected: (lang) =>
                        selectLearningLanguage(ref, lang),
                  ),
                const SizedBox(height: 28),
                const MyPageSectionHeader(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Study Vault',
                  subtitle: '즐겨찾기 표현 및 복습 필요 문장',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _VaultGlassMiniCard(
                        icon: Icons.bookmark_outline_rounded,
                        iconColor: MyPageSectionHeader.iconColor,
                        label: '사전 즐겨찾기',
                        count: favoriteCount,
                        unit: '개',
                        onTap: () {
                          final lang = ref.read(learningHubLanguageProvider);
                          selectLearningLanguage(ref, lang);
                          BookmarkVaultModal.show(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VaultGlassMiniCard(
                        icon: Icons.replay_rounded,
                        iconColor: MyPageSectionHeader.iconColor,
                        label: '복습 필요 문장',
                        count: reviewCount,
                        unit: '문장',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const MyPageSectionHeader(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Data Sync & Updates',
                  subtitle: '앱 버전 및 최신 표현 데이터',
                ),
                const SizedBox(height: 12),
                _SyncGlassCard(
                  syncing: syncing,
                  onSync: _syncContent,
                  onCheckUpdates: _checkForUpdates,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _MyPageGlassStyle {
  static const dividerColor = Color(0xFFE2E8F0);
  static const iconColor = Color(0xFF475569);
  static const badgeBackground = Color(0xFFF1F5F9);
  static const radius = 16.0;

  static const cardShadow = [
    BoxShadow(
      color: Color(0x0C000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static BoxDecoration surfaceDecoration({double radius = _MyPageGlassStyle.radius}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
      );
}

class _MyPageGlassShell extends StatelessWidget {
  final Widget child;

  const _MyPageGlassShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_MyPageGlassStyle.radius),
        boxShadow: _MyPageGlassStyle.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_MyPageGlassStyle.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: _MyPageGlassStyle.surfaceDecoration(),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SyncGlassCard extends StatelessWidget {
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onCheckUpdates;

  const _SyncGlassCard({
    required this.syncing,
    required this.onSync,
    required this.onCheckUpdates,
  });

  static const _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: MyPageSectionHeader.titleColor,
  );

  static const _subtitleStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: MyPageSectionHeader.subtitleColor,
  );

  @override
  Widget build(BuildContext context) {
    return _MyPageGlassShell(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _MyPageGlassStyle.iconColor,
                    ),
                  )
                : const Icon(
                    Icons.cloud_sync_outlined,
                    size: 22,
                    color: _MyPageGlassStyle.iconColor,
                  ),
            title: const Text('최신 표현 데이터 동기화', style: _titleStyle),
            subtitle: Text(
              syncing ? '동기화 중...' : '구글 시트 최신 콘텐츠를 받아옵니다',
              style: _subtitleStyle,
            ),
            trailing: syncing
                ? null
                : Icon(
                    Icons.chevron_right_rounded,
                    color: MyPageSectionHeader.subtitleColor.withValues(alpha: 0.7),
                  ),
            onTap: syncing ? null : onSync,
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: _MyPageGlassStyle.dividerColor.withValues(alpha: 0.5),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: const Icon(
              Icons.system_update_alt_outlined,
              size: 22,
              color: _MyPageGlassStyle.iconColor,
            ),
            title: const Text('앱 버전 정보', style: _titleStyle),
            subtitle: const Text('업데이트 확인', style: _subtitleStyle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _MyPageGlassStyle.badgeBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v${AppConfig.appVersion}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _MyPageGlassStyle.iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MyPageSectionHeader.subtitleColor.withValues(alpha: 0.7),
                ),
              ],
            ),
            onTap: onCheckUpdates,
          ),
        ],
      ),
    );
  }
}

class _VaultGlassMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final String unit;
  final VoidCallback? onTap;

  const _VaultGlassMiniCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = _MyPageGlassShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MyPageSectionHeader.subtitleColor,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: MyPageSectionHeader.titleColor),
                children: [
                  TextSpan(
                    text: '$count',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MyPageSectionHeader.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_MyPageGlassStyle.radius),
        child: card,
      ),
    );
  }
}
