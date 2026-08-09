import 'package:flutter/material.dart';

import '../../../core/constants/labels.dart';
import '../../../core/theme/language_palette.dart';
import '../../../features/dashboard/dashboard_palette.dart';

/// 아이콘 + 이름이 정렬된 카테고리 드롭다운.
class CategoryDropdown extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final value = selectedCategory ?? categories.first;

    return Container(
      decoration: BoxDecoration(
        color: palette.glassFill(alpha: 0.55, tint: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.glassBorder(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white.withValues(alpha: 0.96),
          icon: Icon(Icons.expand_more_rounded, color: palette.primary),
          selectedItemBuilder: (context) => [
            for (final cat in categories)
              _CategoryRow(
                category: cat,
                iconColor: palette.primary,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DashboardPalette.navy,
                ),
              ),
          ],
          items: [
            for (final cat in categories)
              DropdownMenuItem(
                value: cat,
                child: _CategoryRow(
                  category: cat,
                  iconColor: palette.primary,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
          onChanged: (cat) {
            if (cat != null) onSelected(cat);
          },
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final Color iconColor;
  final TextStyle? textStyle;

  const _CategoryRow({
    required this.category,
    required this.iconColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon(category), size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
