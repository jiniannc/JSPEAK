import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// Active 5용 AppBar (높이·아이콘·제목 크기).
PreferredSizeWidget active5AppBar({
  required BuildContext context,
  required Widget title,
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = true,
}) {
  return AppBar(
    toolbarHeight: Active5Layout.appBarHeight,
    leading: leading,
    centerTitle: centerTitle,
    titleSpacing: centerTitle ? null : 0,
    title: title,
    actions: actions,
    actionsPadding: const EdgeInsets.only(right: 8),
  );
}

/// Active 5 최소 터치 영역(52dp)을 보장하는 아이콘 버튼.
class Active5IconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const Active5IconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 28),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(
          Active5Layout.minTouchTarget,
          Active5Layout.minTouchTarget,
        ),
      ),
    );
  }
}
