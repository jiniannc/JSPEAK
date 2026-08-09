import 'package:flutter/material.dart';

import '../../app/dictionary_providers.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../features/dashboard/dashboard_palette.dart';

/// EN / JP / CN 컴팩트 알약형 언어 선택 (학습·기내 사전 공통).
class CompactLanguageSwitcher extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;
  final Color accent;

  /// 헤더 등 배경과 seamless하게 붙일 때 — 외곽 글래스·그림자·테두리 최소화.
  final bool seamless;

  const CompactLanguageSwitcher({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
    required this.accent,
    this.seamless = false,
  });

  static const outerPadding = 3.0;

  static int get _languageCount => kDictionaryLanguages.length;

  /// 트랙 바깥쪽까지 포함한 전체 너비 (헤더 trailing 슬롯 계산용).
  static double get outerWidth =>
      segmentWidth * _languageCount + outerPadding * 2;

  static const slideDuration = Duration(milliseconds: 200);
  static const trackHeight = 32.0;
  static const segmentWidth = 56.0;

  int get _selectedIndex {
    final index = kDictionaryLanguages.indexOf(selectedLanguage);
    return index < 0 ? 0 : index;
  }

  double get _indicatorLeft => _selectedIndex * segmentWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;
    final count = kDictionaryLanguages.length;
    final trackWidth = segmentWidth * count;

    return DecoratedBox(
      decoration: seamless
          ? BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(22),
            )
          : palette.glassCardDecoration(
              radius: 22,
              fillAlpha: 0.72,
              borderAlpha: 0.55,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Padding(
        padding: const EdgeInsets.all(outerPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: trackWidth,
            height: trackHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: slideDuration,
                  curve: Curves.easeOutCubic,
                  left: _indicatorLeft,
                  top: 0,
                  width: segmentWidth,
                  height: trackHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      _LanguageSegment(
                        lang: kDictionaryLanguages[i],
                        isSelected: _selectedIndex == i,
                        accent: accent,
                        onTap: () => onSelected(kDictionaryLanguages[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSegment extends StatelessWidget {
  final String lang;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _LanguageSegment({
    required this.lang,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CompactLanguageSwitcher.segmentWidth,
      height: CompactLanguageSwitcher.trackHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  languageEmoji[lang] ?? '',
                  style: const TextStyle(fontSize: 12, height: 1),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: CompactLanguageSwitcher.slideDuration,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: isSelected
                          ? Colors.white
                          : DashboardPalette.textMuted,
                    ),
                    child: Text(
                      _shortLanguageLabel(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _shortLanguageLabel(String lang) {
  switch (lang) {
    case 'English':
      return 'EN';
    case 'Japanese':
      return 'JP';
    case 'Chinese':
      return 'CN';
    default:
      return languageLabel(lang);
  }
}
