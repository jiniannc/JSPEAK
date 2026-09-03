import 'package:flutter/material.dart';

enum DictionaryItemKind { word, sentence }

/// 즐겨찾기·검색 결과 — 단어/문장 구분은 레이아웃·아이콘으로, 색은 neutral glass 통일.
abstract final class DictionaryItemKindColors {
  static const slate = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const divider = Color(0x140F172A);

  static List<BoxShadow> get elevatedCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 7),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static BoxDecoration elevatedCard({
    required double radius,
    double fillAlpha = 0.94,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevatedCardShadow,
      );

  static BoxDecoration shadowIconButton({required double radius}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration shadowPlayButton({required double radius}) =>
      BoxDecoration(
        color: slate.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: slate.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration shadowField({required double radius}) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration countPill() => BoxDecoration(
        color: slate.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static IconData icon(DictionaryItemKind kind) => switch (kind) {
        DictionaryItemKind.word => Icons.text_fields_rounded,
        DictionaryItemKind.sentence => Icons.format_quote_rounded,
      };

  static Color iconTint(DictionaryItemKind kind) =>
      muted.withValues(alpha: 0.78);

  static Color accent(DictionaryItemKind kind) => muted;

  static Color label(DictionaryItemKind kind) =>
      slate.withValues(alpha: 0.72);

  static Color chipBackground(DictionaryItemKind kind) =>
      slate.withValues(alpha: 0.045);

  static Color chipBorder(DictionaryItemKind kind) =>
      slate.withValues(alpha: 0.08);

  static Color categoryText(DictionaryItemKind kind) =>
      muted.withValues(alpha: 0.88);

  static Color rippleColor(DictionaryItemKind kind) =>
      slate.withValues(alpha: 0.04);
}

/// 카테고리·챕터 출처 — 카드 하단에만 작게 표시.
class DictionarySourceLabel extends StatelessWidget {
  final String label;
  final bool compact;
  final TextAlign textAlign;

  const DictionarySourceLabel({
    super.key,
    required this.label,
    this.compact = false,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Text(
      label.trim(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: compact ? 8 : 9,
        fontWeight: FontWeight.w500,
        color: DictionaryItemKindColors.muted.withValues(alpha: 0.52),
        height: 1.1,
        letterSpacing: -0.1,
      ),
    );
  }
}
