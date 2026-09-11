import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/sentence_progress_providers.dart';
import '../../../core/utils/sentence_category_grouping.dart';
import '../../dashboard/dashboard_palette.dart';
import '../../shell/floating_island_nav_bar.dart';
import 'hub_mode_picker_shared.dart';
import 'mode_guide_cards.dart';

/// 문장 스피킹 진입 — 괄호 그룹이 2개 이상이면 시나리오와 동일한 오버레이 피커.
void openSentenceTraining(
  BuildContext context, {
  required WidgetRef ref,
  required String language,
  required String category,
  int? chapterNo,
  GlobalKey? popupAnchorKey,
}) {
  final bundle = ref.read(contentProvider).value?.bundle;
  if (bundle == null) return;

  final groups = bundle.sentenceGroupsFor(
    language,
    category,
    chapterNo: chapterNo,
  );
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 주제에 학습할 문장이 없어요.')),
    );
    return;
  }

  void navigate(String fullCategory) {
    if (!context.mounted) return;
    context.push(
      '/scenarios/sentences/play'
      '?lang=${Uri.encodeComponent(language)}'
      '&category=${Uri.encodeComponent(fullCategory)}',
    );
  }

  if (groups.length == 1) {
    navigate(groups.first.fullCategory);
    return;
  }

  final resolved = popupAnchorKey == null
      ? null
      : popupAnchorFor(context, anchorKey: popupAnchorKey);
  if (resolved == null) {
    navigate(groups.first.fullCategory);
    return;
  }

  final parent = context;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Consumer(
      builder: (context, ref, _) {
        final stats = ref.watch(sentenceProgressProvider).stats;
        final repo = ref.watch(sentenceProgressRepositoryProvider);
        return _SentenceGroupPickerOverlay(
          anchor: resolved.anchor,
          anchorSize: resolved.size,
          groups: groups,
          groupProgress: (fullCategory) {
            final sentences = bundle.sentencesFor(language, fullCategory);
            final summary = repo.categorySummary(
              sentences: sentences,
              stats: stats,
            );
            return (
              mastered: summary.masteredCount,
              total: summary.total,
              allMastered: summary.allMastered,
            );
          },
          onDismiss: () {
            if (entry.mounted) entry.remove();
          },
          onSelect: (group) {
            if (entry.mounted) entry.remove();
            if (!parent.mounted) return;
            navigate(group.fullCategory);
          },
        );
      },
    ),
  );
  resolved.overlay.insert(entry);
}

class _SentenceGroupPickerOverlay extends StatefulWidget {
  final Offset anchor;
  final Size anchorSize;
  final List<SentenceCategoryGroupInfo> groups;
  final ({int mastered, int total, bool allMastered}) Function(String fullCategory)
      groupProgress;
  final VoidCallback onDismiss;
  final ValueChanged<SentenceCategoryGroupInfo> onSelect;

  const _SentenceGroupPickerOverlay({
    required this.anchor,
    required this.anchorSize,
    required this.groups,
    required this.groupProgress,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_SentenceGroupPickerOverlay> createState() =>
      _SentenceGroupPickerOverlayState();
}

class _SentenceGroupPickerOverlayState extends State<_SentenceGroupPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _dimOpacity;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _scale;

  bool? _opensBelow;
  Animation<double>? _slideY;
  Animation<double>? _tiltX;
  Animation<double>? _liftShadow;

  static const _preferredPopupWidth = 292.0;
  static const _screenMargin = 14.0;
  static const _anchorGap = 8.0;
  static const _sentenceAccent = Color(0xFFE11D48);

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _dimOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    _panelOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.15, 1, curve: Curves.easeInCubic),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 45,
      ),
    ]).animate(_entry);

    _entry.forward();
  }

  void _ensureDirectionalMotion(bool opensBelow) {
    if (_opensBelow == opensBelow && _slideY != null) return;
    _opensBelow = opensBelow;

    final slideBegin = opensBelow ? -28.0 : 28.0;
    final tiltBegin = opensBelow ? 0.18 : -0.18;
    final motion = CurvedAnimation(
      parent: _entry,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _slideY = Tween<double>(begin: slideBegin, end: 0).animate(motion);
    _tiltX = Tween<double>(begin: tiltBegin, end: 0).animate(motion);
    _liftShadow = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(
        parent: _entry,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_entry.status == AnimationStatus.reverse ||
        _entry.status == AnimationStatus.dismissed) {
      return;
    }
    await _entry.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final pad = media.padding;
    final popupWidth = math.min(
      _preferredPopupWidth,
      math.max(1.0, size.width - _screenMargin * 2),
    );
    final estimatedHeight = math.min(
      widget.groups.length * 46.0 + 62,
      math.max(120.0, size.height * 0.52),
    );
    final bottomObstruction =
        pad.bottom + FloatingIslandNavBar.reservedHeight(context);
    final safeTop = pad.top + _screenMargin;
    final safeBottom = math.max(
      safeTop + 120,
      size.height - bottomObstruction - _screenMargin,
    );
    final anchorTop = widget.anchor.dy;
    final anchorBottom = widget.anchor.dy + widget.anchorSize.height;
    final spaceAbove = math.max(0.0, anchorTop - safeTop - _anchorGap);
    final spaceBelow = math.max(0.0, safeBottom - anchorBottom - _anchorGap);
    // 일부만 들어가는 경우 아래로 열면 하단 네비게이션 바에 가려진다.
    // 전체 목록 높이를 확보할 수 있을 때에만 아래로 열고, 그 외에는 위로 연다.
    final showBelow = spaceBelow >= estimatedHeight;
    final availableHeight = math.max(
      120.0,
      math.min(
        estimatedHeight,
        math.min(
          showBelow ? spaceBelow : spaceAbove,
          math.max(120.0, safeBottom - safeTop),
        ),
      ),
    );

    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(
      _screenMargin,
      math.max(_screenMargin, size.width - popupWidth - _screenMargin),
    );

    final popupTop = showBelow
        ? (anchorBottom + _anchorGap).clamp(safeTop, safeBottom - 80)
        : (anchorTop - _anchorGap - availableHeight).clamp(
            safeTop,
            anchorTop - _anchorGap,
          );

    _ensureDirectionalMotion(showBelow);
    final panelAlignment =
        showBelow ? Alignment.topCenter : Alignment.bottomCenter;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: FadeTransition(
              opacity: _dimOpacity,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: popupWidth,
          top: popupTop,
          child: AnimatedBuilder(
            animation: _entry,
            builder: (context, child) {
              final lift = _liftShadow!.value;
              return Transform(
                alignment: panelAlignment,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.00115)
                  ..translate(0.0, _slideY!.value)
                  ..rotateX(_tiltX!.value)
                  ..scale(_scale.value, _scale.value, 1.0),
                child: Opacity(
                  opacity: _panelOpacity.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06 + 0.14 * lift,
                          ),
                          blurRadius: 10 + 26 * lift,
                          spreadRadius: -1,
                          offset: Offset(0, 5 + 14 * lift),
                        ),
                        BoxShadow(
                          color: _sentenceAccent.withValues(
                            alpha: 0.04 + 0.08 * lift,
                          ),
                          blurRadius: 18 + 12 * lift,
                          spreadRadius: -4,
                          offset: Offset(0, 8 + 6 * lift),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: SingleChildScrollView(
                  child: _SentenceGroupPickerPanel(
                    groups: widget.groups,
                    groupProgress: widget.groupProgress,
                    onSelect: widget.onSelect,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SentenceGroupPickerPanel extends StatelessWidget {
  final List<SentenceCategoryGroupInfo> groups;
  final ({int mastered, int total, bool allMastered}) Function(String fullCategory)
      groupProgress;
  final ValueChanged<SentenceCategoryGroupInfo> onSelect;

  const _SentenceGroupPickerPanel({
    required this.groups,
    required this.groupProgress,
    required this.onSelect,
  });

  static const _dividerColor = Color(0x120F172A);
  static const _dividerInset = 12.0;
  static const _sentenceAccent = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    final panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubModePickerHeader(
          icon: Icons.view_carousel_rounded,
          title: '문장 주제 선택',
          accent: _sentenceAccent,
          guideBuilder: (dismiss) =>
              BasicSentenceModeGuideCard(onDismiss: dismiss),
        ),
        for (var i = 0; i < groups.length; i++) ...[
          _SentenceGroupPickerRow(
            index: i + 1,
            group: groups[i],
            progress: groupProgress(groups[i].fullCategory),
            onTap: () => onSelect(groups[i]),
          ),
          if (i < groups.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: _dividerInset),
              child: Divider(height: 1, thickness: 1, color: _dividerColor),
            ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: panelBody,
          ),
        ),
      ),
    );
  }
}

class _SentenceGroupPickerRow extends StatelessWidget {
  static const _accent = Color(0xFFE11D48);

  final int index;
  final SentenceCategoryGroupInfo group;
  final ({int mastered, int total, bool allMastered}) progress;
  final VoidCallback onTap;

  const _SentenceGroupPickerRow({
    required this.index,
    required this.group,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$index. ${group.label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: DashboardPalette.navy,
                ),
              ),
            ),
            if (progress.allMastered && progress.total > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: DashboardPalette.teal.withValues(alpha: 0.88),
                ),
              ),
            if (progress.total > 0 && progress.mastered <= 0)
              const HubPickerStartCue(accent: _SentenceGroupPickerRow._accent)
            else
              _SentenceGroupProgressRing(
                mastered: progress.mastered,
                total: progress.total,
              ),
          ],
        ),
      ),
    );
  }
}

/// 시나리오 선택의 최근 점수 링과 동일한 크기·여백의 문장 학습 진척도 링.
class _SentenceGroupProgressRing extends StatelessWidget {
  final int mastered;
  final int total;

  const _SentenceGroupProgressRing({
    required this.mastered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const stroke = 3.5;
    const track = Color(0xFFE2E8F0);
    final ratio = total <= 0 ? 0.0 : (mastered / total).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _SentenceGroupProgressRingPainter(
              ratio: ratio,
              trackColor: track,
              strokeWidth: stroke,
            ),
          ),
          Text(
            total <= 0 ? '' : '$mastered',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              height: 1,
              color: DashboardPalette.navy.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceGroupProgressRingPainter extends CustomPainter {
  final double ratio;
  final Color trackColor;
  final double strokeWidth;

  const _SentenceGroupProgressRingPainter({
    required this.ratio,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    canvas.drawArc(
      rect,
      0,
      fullSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final sweep = fullSweep * ratio;
    if (sweep <= 0.001) return;
    const colors = [Color(0xFFE11D48), Color(0xFFFB7185)];
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: colors,
          startAngle: startAngle,
          endAngle: startAngle + math.max(sweep, 0.001),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SentenceGroupProgressRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}
