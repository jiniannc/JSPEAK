import 'package:flutter/material.dart';

import '../accessibility/app_accessibility.dart';

/// 원형 조작 버튼 — 최소 52dp 터치 + TalkBack/VoiceOver 라벨.
class AccessibleCircleButton extends StatelessWidget {
  final String semanticLabel;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final Color? backgroundColor;
  final double size;

  const AccessibleCircleButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.size = AppAccessibility.minTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size < AppAccessibility.minTouchTarget
        ? AppAccessibility.minTouchTarget
        : size;

    Widget child = Material(
      color: backgroundColor ?? Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: effectiveSize,
          height: effectiveSize,
          child: Semantics(
            button: true,
            enabled: onPressed != null,
            label: semanticLabel,
            child: ExcludeSemantics(
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );

    final hint = tooltip ?? semanticLabel;
    if (hint.isNotEmpty) {
      child = Tooltip(message: hint, child: child);
    }
    return child;
  }
}
