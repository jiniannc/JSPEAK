import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_palette.dart';

/// 검색 결과 하이라이트 — 인라인 틴트 (한글 띄어쓰기·조사 분리 방지).
abstract final class SearchHighlightStyle {
  static const fill = Color(0x260EA5E9); // #0EA5E9 @ 0.15
  static const text = Color(0xFF0284C7);
}

/// 검색어와 일치하는 구간을 하이라이트한 RichText.
class SearchHighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final Color highlightColor;
  final Color highlightTextColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool pillHighlight;

  const SearchHighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightColor = const Color(0xFFFFF176),
    this.highlightTextColor = const Color(0xFF1A1A1A),
    this.maxLines,
    this.overflow,
    this.pillHighlight = false,
  });

  static List<InlineSpan> buildSpans({
    required String text,
    required String query,
    TextStyle? style,
    Color highlightColor = const Color(0xFFFFF176),
    Color highlightTextColor = const Color(0xFF1A1A1A),
    bool pillHighlight = false,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      final match = text.substring(index, index + q.length);
      if (pillHighlight) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                match,
                style: style?.copyWith(
                      color: highlightTextColor,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ) ??
                    TextStyle(
                      color: highlightTextColor,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match,
            style: (style ?? const TextStyle()).copyWith(
              backgroundColor: highlightColor,
              color: highlightTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      start = index + q.length;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        children: buildSpans(
          text: text,
          query: query,
          style: style ?? DefaultTextStyle.of(context).style,
          highlightColor: highlightColor,
          highlightTextColor: highlightTextColor,
          pillHighlight: pillHighlight,
        ),
      ),
    );
  }
}

/// 글래스 검색 결과용 미리보기 (문장·발음·한국어).
class GlassSearchResultPreview extends StatelessWidget {
  final String sentence;
  final String pronunciation;
  final String korean;
  final String query;
  final Color accent;

  const GlassSearchResultPreview({
    super.key,
    required this.sentence,
    required this.pronunciation,
    required this.korean,
    required this.query,
    required this.accent,
  });

  Color get _pillFill => SearchHighlightStyle.fill;
  Color get _pillText => SearchHighlightStyle.text;

  @override
  Widget build(BuildContext context) {
    const sentenceStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: DashboardPalette.navy,
      height: 1.35,
    );
    const subStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: DashboardPalette.textMuted,
      height: 1.3,
    );
    const koreanStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF94A3B8),
      height: 1.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchHighlightText(
          text: sentence,
          query: query,
          style: sentenceStyle,
          highlightColor: _pillFill,
          highlightTextColor: _pillText,
        ),
        if (pronunciation.isNotEmpty) ...[
          const SizedBox(height: 4),
          SearchHighlightText(
            text: pronunciation,
            query: query,
            style: subStyle,
            highlightColor: _pillFill,
            highlightTextColor: _pillText,
          ),
        ],
        if (korean.isNotEmpty) ...[
          const SizedBox(height: 3),
          SearchHighlightText(
            text: korean,
            query: query,
            style: koreanStyle,
            highlightColor: _pillFill,
            highlightTextColor: _pillText,
          ),
        ],
      ],
    );
  }
}

/// 여러 필드에서 검색어 하이라이트 (레거시 검색 화면).
class SearchResultPreview extends StatelessWidget {
  final String sentence;
  final String pronunciation;
  final String korean;
  final String query;
  final TextStyle? sentenceStyle;
  final TextStyle? subStyle;

  const SearchResultPreview({
    super.key,
    required this.sentence,
    required this.pronunciation,
    required this.korean,
    required this.query,
    this.sentenceStyle,
    this.subStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    final highlight = theme.colorScheme.tertiary.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchHighlightText(
          text: sentence,
          query: query,
          style: sentenceStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          highlightColor: highlight,
          highlightTextColor: palette.onSurface,
        ),
        if (pronunciation.isNotEmpty) ...[
          const SizedBox(height: 6),
          SearchHighlightText(
            text: pronunciation,
            query: query,
            style: subStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: palette.primary,
                ),
            highlightColor: highlight,
            highlightTextColor: palette.primary,
          ),
        ],
        if (korean.isNotEmpty) ...[
          const SizedBox(height: 4),
          SearchHighlightText(
            text: korean,
            query: query,
            style: subStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
            highlightColor: highlight,
            highlightTextColor: Colors.grey.shade800,
          ),
        ],
      ],
    );
  }
}
