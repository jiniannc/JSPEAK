import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/glass_surface.dart';

/// 인스타그램식 플로팅 아일랜드 하단 네비게이션.
/// 탭으로 이동하거나, 누르고 좌우로 드래그해 손가락을 따라 탭을 선택할 수 있다.
class FloatingIslandNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FloatingIslandNavItem> items;

  const FloatingIslandNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  static const height = 64.0;
  static const horizontalInset = 20.0;
  static const bottomInset = 12.0;
  static const radius = 32.0;

  static const scrollBottomClearance = 90.0;

  /// body 하단에 남겨둘 여백 (바 높이 + 하단 여백).
  static double reservedHeight(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return height + bottomInset + safe * 0.35;
  }

  /// 스크롤 콘텐츠 하단 패딩 — 네비 뒤로 비치되 마지막 카드는 가리지 않음.
  static double scrollBottomPadding(BuildContext context) =>
      scrollBottomClearance;

  @override
  State<FloatingIslandNavBar> createState() => _FloatingIslandNavBarState();
}

class _FloatingIslandNavBarState extends State<FloatingIslandNavBar> {
  late int _visualIndex;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _visualIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant FloatingIslandNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.selectedIndex != widget.selectedIndex) {
      _visualIndex = widget.selectedIndex;
    }
  }

  int _indexFromLocalX(double localX, double width) {
    final count = widget.items.length;
    if (count <= 0 || width <= 0) return 0;
    final segment = width / count;
    return (localX / segment).floor().clamp(0, count - 1);
  }

  void _selectVisual(int index, {required bool haptic}) {
    if (index == _visualIndex) return;
    setState(() => _visualIndex = index);
    if (haptic) HapticFeedback.selectionClick();
  }

  void _commit(int index) {
    setState(() {
      _dragging = false;
      _visualIndex = index;
    });
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final count = widget.items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        FloatingIslandNavBar.horizontalInset,
        0,
        FloatingIslandNavBar.horizontalInset,
        FloatingIslandNavBar.bottomInset + bottomSafe * 0.35,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final segmentW = width / count;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) {
              final i = _indexFromLocalX(d.localPosition.dx, width);
              _selectVisual(i, haptic: true);
            },
            onTapUp: (d) {
              final i = _indexFromLocalX(d.localPosition.dx, width);
              _commit(i);
            },
            onTapCancel: () {
              setState(() {
                _dragging = false;
                _visualIndex = widget.selectedIndex;
              });
            },
            onHorizontalDragStart: (d) {
              setState(() => _dragging = true);
              final i = _indexFromLocalX(d.localPosition.dx, width);
              _selectVisual(i, haptic: true);
            },
            onHorizontalDragUpdate: (d) {
              final i = _indexFromLocalX(d.localPosition.dx, width);
              _selectVisual(i, haptic: true);
            },
            onHorizontalDragEnd: (_) => _commit(_visualIndex),
            onHorizontalDragCancel: () {
              setState(() {
                _dragging = false;
                _visualIndex = widget.selectedIndex;
              });
            },
            child: FloatingIslandGlass(
              radius: FloatingIslandNavBar.radius,
              child: SizedBox(
                height: FloatingIslandNavBar.height,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: segmentW * _visualIndex + 6,
                      top: 6,
                      bottom: 6,
                      width: segmentW - 12,
                      child: _DeepGlassNavChip(),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: _NavItemSlot(
                              item: widget.items[i],
                              selected: i == _visualIndex,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 선택 탭 — 딥 글래스 칩 + 상단 백색 반사선.
class _DeepGlassNavChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: GlassSurfaceStyle.deepDarkGlassButton(
        radius: 24,
        opacity: 0.9,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingIslandNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingIslandNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavItemSlot extends StatelessWidget {
  final FloatingIslandNavItem item;
  final bool selected;

  const _NavItemSlot({
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : GlassSurfaceStyle.outlineText;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            selected ? item.selectedIcon : item.icon,
            key: ValueKey('${item.label}-$selected'),
            size: 24,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: color,
            height: 1.1,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}
