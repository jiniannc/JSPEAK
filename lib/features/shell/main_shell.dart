import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_providers.dart';
import '../../app/shell_providers.dart';
import 'floating_island_nav_bar.dart';
import 'main_shell_tab_header.dart';
import 'title_badge_unlock_banner.dart';

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
    if (isReselect && index == kDictionaryShellTabIndex) {
      resetDictionaryHome(ref);
    }
    ref.read(shellTabIndexProvider.notifier).setIndex(index);
    navigationShell.goBranch(
      index,
      initialLocation: isReselect,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = navigationShell.currentIndex;

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
          const TitleBadgeUnlockBannerHost(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingIslandNavBar(
              selectedIndex: tabIndex,
              onSelected: (index) => _onTabSelected(ref, index),
              items: _items,
            ),
          ),
        ],
      ),
    );
  }
}
