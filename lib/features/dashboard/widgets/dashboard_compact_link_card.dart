import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_surface.dart';

/// 홈 보조 카드 — Today's Pick 대비 톤다운된 링크형 글래스.
class DashboardCompactLinkCard extends StatelessWidget {
  final List<Color> tintColors;
  final Widget child;

  const DashboardCompactLinkCard({
    super.key,
    required this.tintColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: GlassSurfaceStyle.cleanElevationShadow(blur: 12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: tintColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class DashboardMetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const DashboardMetaChip({
    super.key,
    required this.label,
    this.icon,
  });

  static const _ink = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: _ink.withValues(alpha: 0.45)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _ink.withValues(alpha: 0.55),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCompactLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DashboardCompactLink({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class DashboardSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const DashboardSectionLabel({
    super.key,
    required this.icon,
    required this.label,
  });

  static const _inkSoft = Color(0x800F172A);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _inkSoft),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: _inkSoft,
          ),
        ),
      ],
    );
  }
}
