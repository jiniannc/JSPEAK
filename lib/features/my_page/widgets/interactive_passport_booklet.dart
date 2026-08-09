import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aviation_title_stamp.dart';
import '../../../app/my_page_report_providers.dart';
import 'my_page_section_header.dart';

// ── Passport palette ─────────────────────────────────────────

abstract final class _PassportPalette {
  static const paper = Color(0xFFF8F5EF);
  static const paperEdge = Color(0xFFE2DED5);
  static const paperStack = Color(0xFFEDE8DF);
  static const paperTabIdle = Color(0xFFEDE8DF);
  static const slate = Color(0xFF64748B);
  static const inkNavy = Color(0xFF1E3A8A);
  static const inkRed = Color(0xFF991B1B);
  static const inkOrange = Color(0xFFC2410C);
  static const ghostLine = Color(0xFFB8B2A8);

  static const bookletHeight = 410.0;
  static const pagePaddingH = 20.0;
  static const pagePaddingV = 16.0;

  static double rotationForIndex(int index) {
    const rotations = [-0.08, 0.10, -0.06, 0.11, -0.09, 0.07, -0.10, 0.08];
    return rotations[index % rotations.length];
  }
}

enum _InkStampShape { doubleCircle, doubleRect, circleSeal }

/// 손가락으로 넘기는 CREW PASSPORT 책자형 여권.
class InteractivePassportBooklet extends StatefulWidget {
  final MyPagePassportReport report;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final Color accent;

  const InteractivePassportBooklet({
    super.key,
    required this.report,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.accent,
  });

  @override
  State<InteractivePassportBooklet> createState() =>
      _InteractivePassportBookletState();
}

class _InteractivePassportBookletState extends State<InteractivePassportBooklet> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.report.languageMission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MyPageSectionHeader(
          icon: Icons.badge_outlined,
          title: 'CREW LEARNING PASSPORT',
          subtitle: '학습 미션 달성 스탬프 및 자격 칭호',
        ),
        const SizedBox(height: 12),
        _PassportBookletView(
          mission: mission,
          report: widget.report,
          currentPage: _currentPage,
          pageController: _pageController,
          selectedLanguage: widget.selectedLanguage,
          onLanguageSelected: widget.onLanguageSelected,
          onPageChanged: (i) => setState(() => _currentPage = i),
          onTabSelected: _goToPage,
        ),
      ],
    );
  }
}

// ── Passport booklet ─────────────────────────────────────────

class _PassportBookletView extends StatelessWidget {
  final MyPageLanguageMissionProgress mission;
  final MyPagePassportReport report;
  final int currentPage;
  final PageController pageController;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTabSelected;

  const _PassportBookletView({
    required this.mission,
    required this.report,
    required this.currentPage,
    required this.pageController,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.onPageChanged,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _PassportPalette.bookletHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopIndexTabs(
            currentPage: currentPage,
            onPageSelected: onTabSelected,
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const _PaperStackLayers(),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _PassportPalette.paper,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: _PassportPalette.paperEdge,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      clipBehavior: Clip.hardEdge,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(3),
                        bottomRight: Radius.circular(3),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PassportPaperBorderPainter(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PassportOfficialHeader(
                                    selectedLanguage: selectedLanguage,
                                    onLanguageSelected: onLanguageSelected,
                                  ),
                                  Expanded(
                                    child: PageView(
                                      controller: pageController,
                                      onPageChanged: onPageChanged,
                                      children: [
                                        _TitleStampsPage(
                                          badges: report.titleBadges,
                                        ),
                                        _SentenceStampsPage(mission: mission),
                                        _ScenarioPassportPage(mission: mission),
                                        _WordSwipePassportPage(mission: mission),
                                      ],
                                    ),
                                  ),
                                  _PassportPageDots(currentPage: currentPage),
                                ],
                              ),
                            ),
                          ),
                          const _SpineCreaseOverlay(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperStackLayers extends StatelessWidget {
  const _PaperStackLayers();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 3,
          top: 3,
          right: -1,
          bottom: -1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _PassportPalette.paperStack.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 1.5,
          top: 1.5,
          right: 0.5,
          bottom: 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _PassportPalette.paperStack.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpineCreaseOverlay extends StatelessWidget {
  const _SpineCreaseOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SpineCreasePainter(),
        ),
      ),
    );
  }
}

class _SpineCreasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final rect = Rect.fromLTWH(centerX - 8, 0, 16, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Top index tabs ───────────────────────────────────────────

class _TopIndexTabs extends StatelessWidget {
  static const _labels = ['칭호', '문장', '시나리오', '단어'];

  final int currentPage;
  final ValueChanged<int> onPageSelected;

  const _TopIndexTabs({
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_labels.length, (i) {
        final active = currentPage == i;
        final isFirst = i == 0;
        final isLast = i == _labels.length - 1;
        final tabRadius = Radius.circular(isFirst || isLast ? 4 : 5);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
            child: GestureDetector(
              onTap: () => onPageSelected(i),
              behavior: HitTestBehavior.opaque,
              child: Transform.translate(
                offset: Offset(0, active ? 1 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: tabRadius,
                    topRight: tabRadius,
                  ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      active ? 8 : 6,
                      4,
                      active ? 9 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? _PassportPalette.paper
                          : _PassportPalette.paperTabIdle,
                      border: Border.all(
                        color: _PassportPalette.paperEdge,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${i + 1}. ${_labels[i]}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: -0.2,
                        color: active
                            ? _PassportPalette.inkNavy
                            : _PassportPalette.slate.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PassportPageDots extends StatelessWidget {
  final int currentPage;

  const _PassportPageDots({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 8,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final active = i == currentPage;
              return Container(
                width: active ? 16 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: active
                      ? _PassportPalette.inkNavy.withValues(alpha: 0.55)
                      : _PassportPalette.ghostLine.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PassportOfficialHeader extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;

  const _PassportOfficialHeader({
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
      child: Row(
        children: [
          const Flexible(
            child: Text(
              'PASSPORT / VISAS',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: _PassportPalette.slate,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _LanguageToggle(
            selectedLanguage: selectedLanguage,
            onSelected: onLanguageSelected,
          ),
        ],
      ),
    );
  }
}

// ── PAGE 1: 칭호 잉크 도장 ───────────────────────────────────

class _TitleStampsPage extends StatelessWidget {
  final List<PassportTitleBadge> badges;

  const _TitleStampsPage({required this.badges});

  @override
  Widget build(BuildContext context) {
    final split = (badges.length / 2).ceil();
    final leftBadges = badges.sublist(0, split);
    final rightBadges = badges.sublist(split);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PassportPalette.pagePaddingH,
        _PassportPalette.pagePaddingV,
        _PassportPalette.pagePaddingH,
        _PassportPalette.pagePaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'OFFICIAL CREW TITLE STAMPS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _PassportPalette.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _TitleStampHalfGrid(
                      badges: leftBadges,
                      startIndex: 0,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _TitleStampHalfGrid(
                      badges: rightBadges,
                      startIndex: split,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleStampHalfGrid extends StatelessWidget {
  final List<PassportTitleBadge> badges;
  final int startIndex;

  const _TitleStampHalfGrid({
    required this.badges,
    required this.startIndex,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        const crossSpacing = 8.0;
        const mainSpacing = 10.0;
        const horizontalPad = 6.0;
        const rotationPad = 10.0;
        final cellWidth = ((constraints.maxWidth -
                    horizontalPad * 2 -
                    crossSpacing) /
                2)
            .clamp(40.0, double.infinity);
        final stampSize = (cellWidth - 2).clamp(68.0, 96.0);

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(
            horizontalPad,
            8,
            horizontalPad,
            12,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: stampSize + rotationPad * 2,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: crossSpacing,
          ),
          itemCount: badges.length,
          itemBuilder: (context, i) {
            return Center(
              child: _TitleInkStampSlot(
                badge: badges[i],
                index: startIndex + i,
                size: stampSize,
              ),
            );
          },
        );
      },
    );
  }
}

class _TitleInkStampSlot extends StatelessWidget {
  final PassportTitleBadge badge;
  final int index;
  final double size;

  const _TitleInkStampSlot({
    required this.badge,
    required this.index,
    this.size = 112,
  });

  void _onTap(BuildContext context) {
    if (badge.unlocked) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(badge.lockHint),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (badge.unlocked) {
      return AviationTitleStamp(badge: badge, index: index, size: size);
    }

    return GestureDetector(
      onTap: () => _onTap(context),
      child: AviationLockedStamp(badge: badge, index: index, size: size),
    );
  }
}

// ── PAGE 2: 문장 스탬프 ──────────────────────────────────────

class _SentenceStampsPage extends StatelessWidget {
  final MyPageLanguageMissionProgress mission;

  const _SentenceStampsPage({required this.mission});

  @override
  Widget build(BuildContext context) {
    final summary = mission.stampSummary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PassportPalette.pagePaddingH,
        _PassportPalette.pagePaddingV,
        _PassportPalette.pagePaddingH,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SENTENCE TRAINING STAMPS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _PassportPalette.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${mission.stampTotalEarned} / ${mission.stampTotalPossible} acquired',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _PassportPalette.slate.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InkStampBoardColumn(
                    emoji: '📖',
                    label: 'LISTEN',
                    earned: summary.readCount,
                    total: summary.total,
                    ink: _PassportPalette.inkNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InkStampBoardColumn(
                    emoji: '🎙️',
                    label: 'SPEAK',
                    earned: summary.attemptedCount,
                    total: summary.total,
                    ink: _PassportPalette.inkRed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InkStampBoardColumn(
                    emoji: '🔥',
                    label: 'MASTER',
                    earned: summary.masteredCount,
                    total: summary.total,
                    ink: _PassportPalette.inkOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InkStampBoardColumn extends StatelessWidget {
  final String emoji;
  final String label;
  final int earned;
  final int total;
  final Color ink;

  const _InkStampBoardColumn({
    required this.emoji,
    required this.label,
    required this.earned,
    required this.total,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final slots = total.clamp(0, 9);

    return Column(
      children: [
        Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: ink.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$earned/$total',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _PassportPalette.slate,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: slots == 0
              ? const SizedBox.shrink()
              : GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: slots,
                  itemBuilder: (context, index) {
                    if (index < earned) {
                      return _PassportInkStamp(
                        index: index,
                        shape: _InkStampShape.circleSeal,
                        ink: ink,
                        fillOpacity: 0.1,
                        strokeWidth: 1.5,
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: ink.withValues(alpha: 0.9),
                          ),
                        ),
                      );
                    }
                    return _PassportDashedStamp(
                      shape: _InkStampShape.circleSeal,
                      color: _PassportPalette.ghostLine.withValues(alpha: 0.5),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── PAGE 3: 시나리오 ─────────────────────────────────────────

class _ScenarioPassportPage extends StatelessWidget {
  final MyPageLanguageMissionProgress mission;

  const _ScenarioPassportPage({required this.mission});

  @override
  Widget build(BuildContext context) {
    final total = mission.scenarioTotal;
    final done = mission.scenarioCompleted;
    final slots = total.clamp(0, 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PassportPalette.pagePaddingH,
        _PassportPalette.pagePaddingV,
        _PassportPalette.pagePaddingH,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SCENARIO ENTRY STAMPS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _PassportPalette.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cleared: $done / $total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _PassportPalette.slate.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemCount: slots,
              itemBuilder: (context, index) {
                final stamped = index < done;
                if (stamped) {
                  return _PassportInkStamp(
                    index: index,
                    shape: _InkStampShape.doubleRect,
                    ink: _PassportPalette.inkNavy,
                    fillOpacity: 0.09,
                    strokeWidth: 1.5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flight_land_rounded,
                          size: 14,
                          color: _PassportPalette.inkNavy.withValues(alpha: 0.85),
                        ),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: _PassportPalette.inkNavy.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _PassportDashedStamp(
                  shape: _InkStampShape.doubleRect,
                  color: _PassportPalette.ghostLine.withValues(alpha: 0.45),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 8,
                        color: _PassportPalette.ghostLine.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── PAGE 4: 단어 ─────────────────────────────────────────────

class _WordSwipePassportPage extends StatelessWidget {
  final MyPageLanguageMissionProgress mission;

  const _WordSwipePassportPage({required this.mission});

  @override
  Widget build(BuildContext context) {
    const ink = _PassportPalette.inkRed;
    final ratio = mission.swipeTotal == 0
        ? 0.0
        : mission.swipeKnown / mission.swipeTotal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _PassportPalette.pagePaddingH,
        _PassportPalette.pagePaddingV,
        _PassportPalette.pagePaddingH,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VOCABULARY MASTER SEAL',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _PassportPalette.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Memorized: ${mission.swipeKnown} / ${mission.swipeTotal}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _PassportPalette.slate.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          Center(
            child: Transform.rotate(
              angle: -0.05,
              child: SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _InkStampShapePainter(
                    shape: _InkStampShape.doubleCircle,
                    ink: ink,
                    fillOpacity: ratio.clamp(0.06, 0.14),
                    strokeWidth: 2.5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🔤', style: TextStyle(fontSize: 26, color: ink.withValues(alpha: 0.85))),
                      const SizedBox(height: 4),
                      Text(
                        'VOCAB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: ink.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ink.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 6,
            decoration: BoxDecoration(
              border: Border.all(color: _PassportPalette.paperEdge),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.02, 1.0),
              child: ColoredBox(color: ink.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid stamp cells ─────────────────────────────────────────

class _PassportInkStamp extends StatelessWidget {
  final int index;
  final _InkStampShape shape;
  final Color ink;
  final double fillOpacity;
  final double strokeWidth;
  final Widget? child;

  const _PassportInkStamp({
    required this.index,
    required this.shape,
    required this.ink,
    required this.fillOpacity,
    required this.strokeWidth,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.88;
        return Center(
          child: Transform.rotate(
            angle: _PassportPalette.rotationForIndex(index),
            child: SizedBox(
              width: side,
              height: side,
              child: CustomPaint(
                painter: _InkStampShapePainter(
                  shape: shape,
                  ink: ink,
                  fillOpacity: fillOpacity,
                  strokeWidth: strokeWidth,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PassportDashedStamp extends StatelessWidget {
  final _InkStampShape shape;
  final Color color;
  final Widget? child;

  const _PassportDashedStamp({
    required this.shape,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.88;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _DashedStampOutlinePainter(
                shape: shape,
                color: color,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ── Custom painters ──────────────────────────────────────────

class _PassportPaperBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    _drawDashedRect(
      canvas,
      rect,
      const Radius.circular(2),
      _PassportPalette.paperEdge,
      1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InkStampShapePainter extends CustomPainter {
  final _InkStampShape shape;
  final Color ink;
  final double fillOpacity;
  final double strokeWidth;

  _InkStampShapePainter({
    required this.shape,
    required this.ink,
    required this.fillOpacity,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = ink.withValues(alpha: fillOpacity);
    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    switch (shape) {
      case _InkStampShape.doubleCircle:
        final outer = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
        canvas.drawOval(outer, Paint()..color = fill);
        canvas.drawOval(outer, stroke);
        final inner = outer.deflate(10);
        canvas.drawOval(inner, stroke..strokeWidth = strokeWidth * 0.75);
      case _InkStampShape.doubleRect:
        final outer = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
          const Radius.circular(4),
        );
        canvas.drawRRect(outer, Paint()..color = fill);
        canvas.drawRRect(outer, stroke);
        final inner = RRect.fromRectAndRadius(
          Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
          const Radius.circular(2),
        );
        canvas.drawRRect(inner, stroke..strokeWidth = strokeWidth * 0.75);
      case _InkStampShape.circleSeal:
        final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
        canvas.drawOval(rect, Paint()..color = fill);
        canvas.drawOval(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _InkStampShapePainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.shape != shape;
}

class _DashedStampOutlinePainter extends CustomPainter {
  final _InkStampShape shape;
  final Color color;

  _DashedStampOutlinePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 4.0;
    if (shape == _InkStampShape.doubleCircle ||
        shape == _InkStampShape.circleSeal) {
      _drawDashedOval(
        canvas,
        Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
        color,
      );
    } else {
      _drawDashedRect(
        canvas,
        Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
        const Radius.circular(4),
        color,
        1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedStampOutlinePainter oldDelegate) => false;
}

void _drawDashedRect(
  Canvas canvas,
  Rect rect,
  Radius radius,
  Color color,
  double strokeWidth,
) {
  const dash = 4.0;
  const gap = 3.0;
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
  _drawDashedPath(canvas, path, paint, dash, gap);
}

void _drawDashedOval(Canvas canvas, Rect rect, Color color) {
  const dash = 4.0;
  const gap = 3.0;
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  final path = Path()..addOval(rect);
  _drawDashedPath(canvas, path, paint, dash, gap);
}

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  double dash,
  double gap,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final next = distance + dash;
      final extract = metric.extractPath(
        distance,
        next.clamp(0, metric.length),
      );
      canvas.drawPath(extract, paint);
      distance = next + gap;
    }
  }
}

class _LanguageToggle extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelected;

  const _LanguageToggle({
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lang in const ['English', 'Japanese', 'Chinese'])
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: GestureDetector(
              onTap: () => onSelected(lang),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selectedLanguage == lang
                      ? _PassportPalette.paper
                      : _PassportPalette.paperTabIdle.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedLanguage == lang
                        ? _PassportPalette.inkNavy.withValues(alpha: 0.35)
                        : _PassportPalette.paperEdge,
                    width: selectedLanguage == lang ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  _shortLangCode(lang),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selectedLanguage == lang
                        ? FontWeight.w900
                        : FontWeight.w600,
                    letterSpacing: 0.2,
                    color: selectedLanguage == lang
                        ? _PassportPalette.inkNavy
                        : _PassportPalette.slate.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _shortLangCode(String language) => switch (language) {
      'Japanese' => 'JP',
      'Chinese' => 'CN',
      _ => 'EN',
    };
