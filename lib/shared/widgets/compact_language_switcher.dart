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

  // 헤더에서 트랙 바깥에 별도 띠가 보이지 않도록 외곽 패딩 제거.
  static const outerPadding = 0.0;

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

    // DecoratedBox만 둥글게 칠하면 언어 팔레트가 보간되는 프레임에서
    // Android 합성 레이어의 사각 경계가 비칠 수 있다. 외곽부터 명시적으로
    // clip하고, seamless 배경은 언어색이 아닌 중립색으로 고정한다.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: seamless
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(16),
              )
            : palette.glassCardDecoration(
                radius: 16,
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
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
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

String shortLanguageLabel(String lang) {
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

String _shortLanguageLabel(String lang) => shortLanguageLabel(lang);

/// 헤더용 — 선택된 언어만 pill로 보여주고 드롭다운으로 전환.
class CompactLanguageDropdown extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;
  final Color accent;

  const CompactLanguageDropdown({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
    required this.accent,
  });

  static const bookmarkButtonWidth = 32.0;
  static const dividerWidth = 1.0;
  static const dividerSpacing = 8.0;
  static const pillHeight = 32.0;
  static const outerWidth = 76.0;

  static const _pillHorizontalPadding = 10.0;
  static const _menuItemPadding =
      EdgeInsets.symmetric(horizontal: _pillHorizontalPadding);

  /// 헤더 언어 pill · 홈 체크인 배너 등 동일 frosted pill 표면.
  static BoxDecoration pillDecoration({bool isOpen = false}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: isOpen ? 0.58 : 0.42),
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildPillRow({
    required String emoji,
    required String label,
    required Color labelColor,
    bool showChevron = false,
    bool showCheck = false,
  }) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 12, height: 1),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
              color: labelColor,
            ),
          ),
        ),
        if (showChevron)
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: DashboardPalette.textMuted.withValues(alpha: 0.85),
          )
        else if (showCheck)
          Icon(Icons.check_rounded, size: 14, color: labelColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = languageEmoji[selectedLanguage] ?? '';
    final label = shortLanguageLabel(selectedLanguage);
    final menuConstraints = BoxConstraints(
      minWidth: outerWidth,
      maxWidth: outerWidth,
    );

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: menuConstraints,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Colors.white.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      splashRadius: 0.001,
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          for (final lang in kDictionaryLanguages)
            PopupMenuItem<String>(
              value: lang,
              height: pillHeight,
              padding: _menuItemPadding,
              child: _buildPillRow(
                emoji: languageEmoji[lang] ?? '',
                label: shortLanguageLabel(lang),
                labelColor: lang == selectedLanguage
                    ? accent
                    : DashboardPalette.navy,
                showCheck: lang == selectedLanguage,
              ),
            ),
        ];
      },
      child: SizedBox(
        width: outerWidth,
        height: pillHeight,
        child: DecoratedBox(
          decoration: pillDecoration(isOpen: false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pillHorizontalPadding),
            child: _buildPillRow(
              emoji: emoji,
              label: label,
              labelColor: accent,
              showChevron: true,
            ),
          ),
        ),
      ),
    );
  }
}
