import 'package:flutter/material.dart';

import '../../shell/floating_island_nav_bar.dart';

/// How it works 안내 — ⓘ 탭 시 표시되는 오버레이.
class ModeGuideOverlayPanel extends StatefulWidget {
  const ModeGuideOverlayPanel({
    super.key,
    required this.anchor,
    required this.anchorSize,
    required this.guide,
    required this.onDismiss,
  });

  final Offset anchor;
  final Size anchorSize;
  final Widget guide;
  final VoidCallback onDismiss;

  @override
  State<ModeGuideOverlayPanel> createState() => _ModeGuideOverlayPanelState();
}

class _ModeGuideOverlayPanelState extends State<ModeGuideOverlayPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_entry.status == AnimationStatus.reverse ||
        _entry.status == AnimationStatus.dismissed) {
      return;
    }
    await _entry.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final popupWidth = (size.width - 28).clamp(280.0, 360.0);
    final maxHeight = size.height * 0.62;
    final bottomObstruction =
        pad.bottom + FloatingIslandNavBar.reservedHeight(context);
    final spaceAbove = widget.anchor.dy - pad.top - 12;
    final spaceBelow = size.height -
        bottomObstruction -
        (widget.anchor.dy + widget.anchorSize.height) -
        12;
    final nearBottom = widget.anchor.dy + widget.anchorSize.height >
        size.height - bottomObstruction - maxHeight * 0.35;
    final showAbove =
        nearBottom || (spaceAbove >= 200 && spaceAbove >= spaceBelow);
    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(14.0, size.width - popupWidth - 14.0);

    final curved = CurvedAnimation(
      parent: _entry,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: FadeTransition(
              opacity: _entry,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: popupWidth,
          top: showAbove
              ? null
              : widget.anchor.dy + widget.anchorSize.height + 8,
          bottom: showAbove ? size.height - widget.anchor.dy + 8 : null,
          child: FadeTransition(
            opacity: _entry,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              alignment:
                  showAbove ? Alignment.bottomCenter : Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(child: widget.guide),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
