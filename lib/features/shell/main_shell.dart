import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_providers.dart';
import '../../app/learning_hub_language_provider.dart';
import '../../app/learning_providers.dart';
import '../../app/providers.dart';
import '../../app/shell_providers.dart';
import '../../app/title_badge_providers.dart';
import '../learning/widgets/chapter_image_preloader.dart';
import 'floating_island_nav_bar.dart';
import 'main_shell_tab_header.dart';

/// 하단 탭 [홈, 학습, 기내 사전, 마이페이지]를 제공하는 메인 뼈대.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _items = [
    FloatingIslandNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '홈',
    ),
    FloatingIslandNavItem(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      label: '학습',
    ),
    FloatingIslandNavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: '기내 사전',
    ),
    FloatingIslandNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '마이페이지',
    ),
  ];

  void _onTabSelected(WidgetRef ref, int index) {
    final isReselect = index == navigationShell.currentIndex;
    if (index == kLearningShellTabIndex) {
      ref.read(hubDockResyncProvider.notifier).bumpFullReveal();
    }
    if (index == kDictionaryShellTabIndex) {
      final hubLanguage = ref.read(learningHubLanguageProvider);
      if (ref.read(selectedLanguageProvider) != hubLanguage) {
        syncAppLanguage(ref, hubLanguage);
      }
    }
    if (isReselect && index == kDictionaryShellTabIndex) {
      resetDictionaryHome(ref);
    }
    if (index == 0) {
      ref.read(homeEntranceEpochProvider.notifier).bump();
    }
    ref.read(shellTabIndexProvider.notifier).setIndex(index);
    navigationShell.goBranch(
      index,
      initialLocation: isReselect,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(contentProvider, (previous, next) {
      next.whenData((content) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final language = ref.read(learningHubLanguageProvider);
          final chapters = content.bundle.learningHubChaptersFor(language);
          if (chapters.isEmpty) return;
          unawaited(
            ChapterImagePreloader.warmUpChapters(
              context,
              language: language,
              chapters: chapters,
              cardWidth: ChapterImagePreloader.hubCardWidth(context),
              priorityChapterKeys: chapters
                  .take(3)
                  .map(ChapterImagePreloader.chapterKey),
            ),
          );
        });
      });
    });

    final tabIndex = navigationShell.currentIndex;
    final hasPendingTitleUnlock =
        ref.watch(titleBadgeUnlockProvider).pendingCelebrations.isNotEmpty;
    final showMyPageBadge = hasPendingTitleUnlock &&
        tabIndex != MainShellTabHeader.kMyPageTabIndex;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MainShellBackground(tabIndex: tabIndex),
          ),
          navigationShell,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MainShellHeaderOverlay(tabIndex: tabIndex),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingIslandNavBar(
              selectedIndex: tabIndex,
              onSelected: (index) => _onTabSelected(ref, index),
              items: _items,
              badgeTabIndices: showMyPageBadge
                  ? {MainShellTabHeader.kMyPageTabIndex}
                  : const {},
            ),
          ),
        ],
      ),
    );
  }
}
