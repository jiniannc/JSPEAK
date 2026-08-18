import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/language_palette.dart';
import '../../../data/models/scenario.dart';
import '../../../data/models/scenario_chapter.dart';
import '../../../shared/widgets/chapter_thumbnail.dart';
import '../../../shared/widgets/true_glass_panel.dart';

// ── True glass palette ───────────────────────────────────────

abstract final class _GlassPalette {
  static const titleInk = Color(0xFF1E293B);
  static const tagBg = Color(0xFFF1F5F9);
  static const tagInk = Color(0xFF64748B);
  static const reviewInk = Color(0xFF475569);
  static const newCoral = Color(0xFFFF5252);
  static const ctaSlate = Color(0xFF1E293B);
  static const treeLine = Color(0xFFCBD5E1);

  /// tilePadding.left(12) + leading(40) + titleGap(16)
  static const chapterTitleInset = 68.0;

  /// 썸네일 중앙 — 트리 연결선 x
  static const treeLineInset = 31.0;
}

enum _GlassPanelTier { chapter, nested }

/// BackdropFilter 기반 글래스 패널 (챕터 / 하위 2단).
class _TrueGlassPanel extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final _GlassPanelTier tier;
  final Widget child;

  const _TrueGlassPanel({
    required this.radius,
    required this.child,
    this.padding,
    this.margin,
    this.tier = _GlassPanelTier.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return TrueGlassPanel(
      radius: radius,
      padding: padding,
      margin: margin,
      nested: tier == _GlassPanelTier.nested,
      child: child,
    );
  }
}

/// 하위 시나리오 트리 — 들여쓰기 + 세로 가이드라인.
class _ChapterScenarioTree extends StatelessWidget {
  final List<Widget> children;

  const _ChapterScenarioTree({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 10, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _GlassPalette.treeLineInset,
            top: 4,
            bottom: 8,
            child: Container(
              width: 1.5,
              color: _GlassPalette.treeLine.withValues(alpha: 0.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: _GlassPalette.chapterTitleInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// 코랄 오렌지 'NEW' — 은은한 호흡(Breathing) 애니메이션.
class ScenarioNewBadge extends StatefulWidget {
  const ScenarioNewBadge({super.key});

  @override
  State<ScenarioNewBadge> createState() => _ScenarioNewBadgeState();
}

class _ScenarioNewBadgeState extends State<ScenarioNewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _breath = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: SizedBox(
          width: 34,
          height: 12,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final t = _breath.value;
              final glow = 0.2 + 0.45 * t;
              return Opacity(
                opacity: 0.78 + 0.22 * t,
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4 + 0.15 * t,
                    color: _GlassPalette.newCoral,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: _GlassPalette.newCoral.withValues(alpha: glow),
                        blurRadius: 4 + 6 * t,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 챕터 썸네일 — [ChapterThumbnail] 래퍼.
class ScenarioChapterThumbnail extends StatelessWidget {
  final String assetPath;

  const ScenarioChapterThumbnail({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return ChapterThumbnail(assetPath: assetPath);
  }
}

/// 챕터별 아코디언 카드.
class ScenarioChapterExpansionCard extends StatelessWidget {
  final ScenarioChapter chapter;
  final int completedCount;
  final bool Function(String scenarioId) isCompleted;
  final ValueChanged<Scenario> onScenarioTap;

  const ScenarioChapterExpansionCard({
    super.key,
    required this.chapter,
    required this.completedCount,
    required this.isCompleted,
    required this.onScenarioTap,
  });

  bool get _isCleared {
    final total = chapter.scenarios.length;
    return total > 0 && completedCount >= total;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.languagePalette ?? LanguagePalette.english;
    final total = chapter.scenarios.length;
    final isCleared = _isCleared;

    return _TrueGlassPanel(
      radius: 16,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: palette.primary.withValues(alpha: 0.05),
          highlightColor: palette.primary.withValues(alpha: 0.03),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          childrenPadding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          leading: ScenarioChapterThumbnail(assetPath: chapter.chapterImage),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  'Chapter ${chapter.chapterNo}. ${chapter.chapterName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _GlassPalette.titleInk,
                    letterSpacing: -0.25,
                    height: 1.25,
                  ),
                ),
              ),
              if (chapter.hasNewContent) const ScenarioNewBadge(),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChapterStatusBadge(
                completed: completedCount,
                total: total,
                isCleared: isCleared,
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: _GlassPalette.tagInk,
              ),
            ],
          ),
          children: [
            _ChapterScenarioTree(
              children: [
                for (var i = 0; i < chapter.scenarios.length; i++)
                  _ScenarioChapterSubItem(
                    index: i + 1,
                    scenario: chapter.scenarios[i],
                    isCompleted: isCompleted(chapter.scenarios[i].id),
                    onTap: () => onScenarioTap(chapter.scenarios[i]),
                    isLast: i == chapter.scenarios.length - 1,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterStatusBadge extends StatelessWidget {
  final int completed;
  final int total;
  final bool isCleared;

  const _ChapterStatusBadge({
    required this.completed,
    required this.total,
    required this.isCleared,
  });

  @override
  Widget build(BuildContext context) {
    if (isCleared) {
      return const _MetallicPassBadge();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        '$completed/$total',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: _GlassPalette.tagInk,
          height: 1,
        ),
      ),
    );
  }
}

/// 챕터 클리어 — 폴리싱 메탈릭 실버 PASS (최초 1회 글리터 + 글리치).
class _MetallicPassBadge extends StatefulWidget {
  const _MetallicPassBadge();

  @override
  State<_MetallicPassBadge> createState() => _MetallicPassBadgeState();
}

class _MetallicPassBadgeState extends State<_MetallicPassBadge>
    with SingleTickerProviderStateMixin {
  static const _metalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFE2E8F0),
      Color(0xFFCBD5E1),
      Color(0xFF94A3B8),
    ],
  );

  static const _engravedInk = Color(0xFF334155);

  late final AnimationController _controller;
  late final Animation<double> _shimmer;
  late final Animation<double> _glitch;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _shimmer = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.62, curve: Curves.easeInOut),
    );
    _glitch = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.88, curve: Curves.linear),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _glitchOffset(double t) {
    if (t <= 0) return 0;
    final damp = 1 - t;
    return math.sin(t * math.pi * 10) * damp * 0.9;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final glitchX = _glitchOffset(_glitch.value);
          final shimmerVal = _shimmer.value;
          final showShimmer = shimmerVal > 0.02 && shimmerVal < 0.98;

          return Container(
            height: 22,
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: _metalGradient,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.hardEdge,
              children: [
                Transform.translate(
                  offset: Offset(glitchX, 0),
                  transformHitTests: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'PASS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: _engravedInk,
                          height: 1,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: _engravedInk,
                      ),
                    ],
                  ),
                ),
                if (showShimmer)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment(shimmerVal * 2.4 - 1.4, -0.6),
                            end: Alignment(shimmerVal * 2.4 - 0.9, 0.6),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: 0.65 * (1 - shimmerVal),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.38, 0.5, 0.62],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String? _scenarioMetaLine(Scenario scenario) {
  final parts = <String>[];
  if (scenario.level.trim().isNotEmpty) parts.add(scenario.level.trim());
  if (scenario.lines.isNotEmpty) parts.add('${scenario.lines.length}문장');
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

class _ScenarioChapterSubItem extends StatelessWidget {
  final int index;
  final Scenario scenario;
  final bool isCompleted;
  final VoidCallback onTap;
  final bool isLast;

  const _ScenarioChapterSubItem({
    required this.index,
    required this.scenario,
    required this.isCompleted,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final metaLine = _scenarioMetaLine(scenario);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: _TrueGlassPanel(
          tier: _GlassPanelTier.nested,
          radius: 10,
          margin: EdgeInsets.only(bottom: isLast ? 0 : 5),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$index. ${scenario.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCompleted
                                  ? _GlassPalette.titleInk.withValues(alpha: 0.58)
                                  : _GlassPalette.titleInk,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (scenario.isNewContent) const ScenarioNewBadge(),
                      ],
                    ),
                    if (metaLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _GlassPalette.tagInk.withValues(
                            alpha: isCompleted ? 0.72 : 1,
                          ),
                          height: 1.15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ScenarioCtaButton(isCompleted: isCompleted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioCtaButton extends StatelessWidget {
  final bool isCompleted;

  const _ScenarioCtaButton({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCompleted ? _GlassPalette.tagBg : _GlassPalette.ctaSlate,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          isCompleted ? '복습' : '도전 ▶',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: isCompleted ? _GlassPalette.reviewInk : Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}
