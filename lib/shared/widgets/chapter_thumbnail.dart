import 'package:flutter/material.dart';

import '../../core/utils/chapter_asset_path.dart';

/// 챕터 썸네일 — asset 실패 시 미니멀 아이콘 폴백.
class ChapterThumbnail extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;

  const ChapterThumbnail({
    super.key,
    required this.assetPath,
    this.fallbackIcon = Icons.flight_rounded,
  });

  static const _thumbBg = Color(0xFFF8FAFC);
  static const _thumbIcon = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final resolved = resolveChapterAssetPath(assetPath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 40,
        height: 40,
        child: resolved.isEmpty
            ? _fallback()
            : Image.asset(
                resolved,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 40,
      height: 40,
      color: _thumbBg.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: 18,
        color: _thumbIcon,
      ),
    );
  }
}
