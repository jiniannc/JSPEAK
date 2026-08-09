import 'package:flutter/material.dart';

import '../../../app/dictionary_providers.dart';
import '../../../core/constants/labels.dart';
import '../../../core/theme/language_palette.dart';

/// 상단 [English / Japanese / Chinese] 원터치 언어 탭바.
class LanguageTabBar extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry margin;

  const LanguageTabBar({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final lang in kDictionaryLanguages)
            Expanded(
              child: _LanguageTab(
                label: languageLabel(lang),
                emoji: languageEmoji[lang] ?? '',
                selected: selectedLanguage == lang,
                selectedColor: palette.tabSelected,
                unselectedColor: palette.tabUnselected,
                onTap: () => onSelected(lang),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageTab extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _LanguageTab({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
