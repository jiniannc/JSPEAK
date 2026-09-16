import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learning_hub_language_provider.dart';
import '../../app/learning_providers.dart';
import '../../app/my_page_report_providers.dart';
import '../../app/my_page_stats_providers.dart';
import '../../app/providers.dart';
import '../../app/shell_providers.dart';
import '../../app/title_badge_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/title_badge.dart';
import '../../shared/widgets/glass_surface.dart';
import '../shell/floating_island_nav_bar.dart';
import '../shell/main_shell_tab_header.dart';
import 'widgets/badge_unlock_dialog.dart';
import 'widgets/interactive_passport_booklet.dart';
import 'widgets/my_page_section_card.dart';
import '../dictionary/widgets/bookmark_vault_modal.dart';

/// 마이페이지 — 학습 리포트 · 보관함 · 앱 데이터 관리.
class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  bool _celebrationShowing = false;
  bool _celebrationQueued = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowCelebration());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isMyPageTabVisible =>
      ref.read(shellTabIndexProvider) == MainShellTabHeader.kMyPageTabIndex;

  void _tryShowCelebration() {
    if (!mounted) return;
    _handleBadgeUnlockState(null, ref.read(titleBadgeUnlockProvider));
  }

  void _handleBadgeUnlockState(
    TitleBadgeUnlockState? previous,
    TitleBadgeUnlockState next,
  ) {
    if (_celebrationShowing) return;
    if (next.pendingCelebrations.isEmpty) {
      _celebrationQueued = false;
      return;
    }

    if (!_isMyPageTabVisible) {
      _celebrationQueued = true;
      return;
    }

    _celebrationQueued = false;
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
    ref.listen<int>(shellTabIndexProvider, (previous, next) {
      if (next == MainShellTabHeader.kMyPageTabIndex &&
          (_celebrationQueued ||
              ref.read(titleBadgeUnlockProvider).pendingCelebrations.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryShowCelebration();
        });
      }
    });
    ref.listen<int>(myPageEntranceEpochProvider, (previous, next) {
      if (previous == next || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });

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
            controller: _scrollController,
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
                  MyPageSectionCard(
                    icon: Icons.badge_outlined,
                    koreanTitle: '나의 학습 여권',
                    englishTitle: 'Crew Learning Passport',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PassportLanguageToggle(
                          selectedLanguage: language,
                          onSelected: (lang) =>
                              selectLearningLanguage(ref, lang),
                        ),
                        const SizedBox(width: 10),
                        const TitleBadgeDebugUnlockSwitch(),
                      ],
                    ),
                    contentGap: 14,
                    child: InteractivePassportBooklet(
                      report: passportReport,
                      selectedLanguage: language,
                      accent: palette.primary,
                    ),
                  ),
                const SizedBox(height: 20),
                MyPageSectionCard(
                  icon: Icons.inventory_2_outlined,
                  koreanTitle: '학습 보관함',
                  englishTitle: 'My Study Vault',
                  contentGap: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: _VaultInnerTile(
                          icon: Icons.bookmark_outline_rounded,
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: _VaultInnerTile(
                          icon: Icons.replay_rounded,
                          label: '복습 필요 문장',
                          count: reviewCount,
                          unit: '문장',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                MyPageSectionCard(
                  icon: Icons.cloud_sync_outlined,
                  koreanTitle: '콘텐츠 업데이트 및 동기화',
                  englishTitle: 'Data Sync & Updates',
                  contentGap: 0,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: _SyncActionList(
                    syncing: syncing,
                    onSync: _syncContent,
                    onCheckUpdates: _checkForUpdates,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _MyPageInnerTileStyle {
  static const radius = 12.0;

  static BoxDecoration decoration() => BoxDecoration(
        color: GlassSurfaceStyle.badgeBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.42),
        ),
      );
}

class _SyncActionList extends StatelessWidget {
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onCheckUpdates;

  const _SyncActionList({
    required this.syncing,
    required this.onSync,
    required this.onCheckUpdates,
  });

  static const _titleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: GlassSurfaceStyle.titleColor,
  );

  static const _subtitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: GlassSurfaceStyle.subtitleColor,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 4,
          ),
          leading: syncing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: GlassSurfaceStyle.iconColor,
                  ),
                )
              : const Icon(
                  Icons.cloud_sync_outlined,
                  size: 22,
                  color: GlassSurfaceStyle.iconColor,
                ),
          title: const Text('최신 데이터 동기화', style: _titleStyle),
          subtitle: Text(
            syncing ? '동기화 중...' : '최신 콘텐츠를 업데이트 합니다',
            style: _subtitleStyle,
          ),
          trailing: syncing
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: GlassSurfaceStyle.subtitleColor.withValues(alpha: 0.7),
                ),
          onTap: syncing ? null : onSync,
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.45),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 4,
          ),
          leading: const Icon(
            Icons.download_outlined,
            size: 22,
            color: GlassSurfaceStyle.iconColor,
          ),
          title: const Text('오디오 전체 다운로드', style: _titleStyle),
          subtitle: const Text(
            '비행 전 녹음 파일을 기기에 저장합니다',
            style: _subtitleStyle,
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: GlassSurfaceStyle.subtitleColor.withValues(alpha: 0.7),
          ),
          onTap: () => context.push('/settings'),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.45),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 4,
          ),
          leading: const Icon(
            Icons.system_update_alt_outlined,
            size: 22,
            color: GlassSurfaceStyle.iconColor,
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
                  color: GlassSurfaceStyle.badgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v${AppConfig.appVersion}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: GlassSurfaceStyle.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: GlassSurfaceStyle.subtitleColor.withValues(alpha: 0.7),
              ),
            ],
          ),
          onTap: onCheckUpdates,
        ),
      ],
    );
  }
}

class _VaultInnerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final String unit;
  final VoidCallback? onTap;

  const _VaultInnerTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: _MyPageInnerTileStyle.decoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GlassSurfaceStyle.iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GlassSurfaceStyle.subtitleColor,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: GlassSurfaceStyle.titleColor),
              children: [
                TextSpan(
                  text: '$count',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GlassSurfaceStyle.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_MyPageInnerTileStyle.radius),
        child: tile,
      ),
    );
  }
}
