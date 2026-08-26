import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_surface.dart';

/// 마이페이지 섹션 카드 내부 제목 — 한국어 메인 + 영어 보조.
class MyPageSectionHeader extends StatelessWidget {
  final IconData icon;
  final String koreanTitle;
  final String englishTitle;
  final String? description;
  final Widget? trailing;

  const MyPageSectionHeader({
    super.key,
    required this.icon,
    required this.koreanTitle,
    required this.englishTitle,
    this.description,
    this.trailing,
  });

  /// @deprecated 호환용 — `GlassSurfaceStyle` 사용.
  static const iconColor = GlassSurfaceStyle.iconColor;
  static const titleColor = GlassSurfaceStyle.titleColor;
  static const subtitleColor = GlassSurfaceStyle.subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: GlassSurfaceStyle.badgeBackground.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: GlassSurfaceStyle.dividerColor.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                koreanTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                englishTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  letterSpacing: 0.55,
                  color: subtitleColor.withValues(alpha: 0.92),
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                    color: subtitleColor.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
