import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_surface.dart';
import 'my_page_section_header.dart';

/// 마이페이지 섹션 — frosted glass 카드 + 내부 제목.
class MyPageSectionCard extends StatelessWidget {
  final IconData icon;
  final String koreanTitle;
  final String englishTitle;
  final String? description;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double contentGap;

  const MyPageSectionCard({
    super.key,
    required this.icon,
    required this.koreanTitle,
    required this.englishTitle,
    this.description,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.contentGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      opacity: 0.68,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyPageSectionHeader(
              icon: icon,
              koreanTitle: koreanTitle,
              englishTitle: englishTitle,
              description: description,
              trailing: trailing,
            ),
            SizedBox(height: contentGap),
            child,
          ],
        ),
      ),
    );
  }
}
