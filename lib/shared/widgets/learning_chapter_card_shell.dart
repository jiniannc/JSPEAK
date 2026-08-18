import 'package:flutter/material.dart';

import '../../data/models/content_chapter.dart';
import '../../features/dashboard/dashboard_palette.dart';
import 'chapter_thumbnail.dart';
import 'true_glass_panel.dart';

/// 시나리오 챕터 카드와 동일한 글래스 셸 + Chapter N. 제목 헤더.
class LearningChapterCardShell extends StatelessWidget {
  final ContentChapter chapter;
  final Widget content;
  final Widget? headerTrailing;
  final VoidCallback? onTap;
  final IconData thumbnailFallback;

  const LearningChapterCardShell({
    super.key,
    required this.chapter,
    required this.content,
    this.headerTrailing,
    this.onTap,
    this.thumbnailFallback = Icons.menu_book_rounded,
  });

  static const _titleInk = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChapterThumbnail(
              assetPath: chapter.chapterImage,
              fallbackIcon: thumbnailFallback,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _titleInk,
                  letterSpacing: -0.25,
                  height: 1.25,
                ),
              ),
            ),
            if (headerTrailing != null) ...[
              const SizedBox(width: 6),
              headerTrailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        content,
      ],
    );

    return TrueGlassPanel(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: body,
              ),
            ),
    );
  }
}

/// 마스터 상태 배지 (기존 카드 구성 유지용).
class LearningChapterMasterBadge extends StatelessWidget {
  const LearningChapterMasterBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'MASTER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          color: Color(0xFFF57F17),
        ),
      ),
    );
  }
}

/// 서브타이틀 텍스트 스타일 통일.
class LearningChapterSubtitle extends StatelessWidget {
  final String text;
  final bool mastered;

  const LearningChapterSubtitle({
    super.key,
    required this.text,
    this.mastered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: mastered ? const Color(0xFFF57F17) : DashboardPalette.textMuted,
      ),
    );
  }
}
