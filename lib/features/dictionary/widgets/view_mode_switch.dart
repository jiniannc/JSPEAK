import 'package:flutter/material.dart';

import '../../../app/dictionary_providers.dart';
import '../../../core/theme/language_palette.dart';

/// 리스트 / 3D 휠 뷰 모드 전환 버튼.
class ViewModeSwitch extends StatelessWidget {
  final DictionaryViewMode mode;
  final ValueChanged<DictionaryViewMode> onChanged;

  const ViewModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;

    return Container(
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.view_list_rounded,
            tooltip: '리스트 모드',
            selected: mode == DictionaryViewMode.list,
            accent: palette.accent,
            onTap: () => onChanged(DictionaryViewMode.list),
          ),
          _ModeButton(
            icon: Icons.view_carousel_rounded,
            tooltip: '3D 휠 학습 모드',
            selected: mode == DictionaryViewMode.wheel,
            accent: palette.accent,
            onTap: () => onChanged(DictionaryViewMode.wheel),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : accent.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
