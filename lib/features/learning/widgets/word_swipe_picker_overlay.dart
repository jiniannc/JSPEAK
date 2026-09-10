import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/swipe_progress_providers.dart';
import '../../../data/datasources/local/swipe_progress_local_datasource.dart';
import '../../dashboard/dashboard_palette.dart';
import 'hub_mode_picker_shared.dart';
import 'learning_hub_chapter_card.dart';
import 'mode_guide_cards.dart';

/// 단어 스와이프 진입 — 문장·시나리오와 동일한 선택 오버레이.
void openWordSwipePicker(
  BuildContext context, {
  required WidgetRef ref,
  required String language,
  required String category,
  required int wordCount,
  GlobalKey? popupAnchorKey,
}) {
  if (wordCount <= 0) return;

  final resolved = popupAnchorKey == null
      ? null
      : popupAnchorFor(context, anchorKey: popupAnchorKey);
  if (resolved == null) {
    if (!context.mounted) return;
    openWordSwipeFromHub(
      context,
      language: language,
      category: category,
    );
    return;
  }

  final parent = context;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Consumer(
      builder: (context, ref, _) {
        final stats = ref.watch(swipeProgressProvider).stats;
        final progress = stats.forCategory(language, category);
        return _WordSwipePickerOverlay(
          anchor: resolved.anchor,
          anchorSize: resolved.size,
          wordCount: wordCount,
          progress: progress,
          onDismiss: () {
            if (entry.mounted) entry.remove();
          },
          onStart: () {
            if (entry.mounted) entry.remove();
            if (!parent.mounted) return;
            openWordSwipeFromHub(
              parent,
              language: language,
              category: category,
            );
          },
        );
      },
    ),
  );
  resolved.overlay.insert(entry);
}

class _WordSwipePickerOverlay extends StatefulWidget {
  const _WordSwipePickerOverlay({
    required this.anchor,
    required this.anchorSize,
    required this.wordCount,
    required this.progress,
    required this.onDismiss,
    required this.onStart,
  });

  final Offset anchor;
  final Size anchorSize;
  final int wordCount;
  final SwipeCategoryProgress progress;
  final VoidCallback onDismiss;
  final VoidCallback onStart;

  @override
  State<_WordSwipePickerOverlay> createState() =>
      _WordSwipePickerOverlayState();
}

class _WordSwipePickerOverlayState extends State<_WordSwipePickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _dimOpacity;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _scale;

  bool? _opensBelow;
  Animation<double>? _slideY;
  Animation<double>? _tiltX;
  Animation<double>? _liftShadow;

  static const _wordAccent = Color(0xFFE67E22);

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
    const popupWidth = HubPickerLayout.preferredPopupWidth;
    const estimatedHeight = 108.0;
    final bottomObstruction = HubPickerLayout.bottomObstruction(context);
    final safeTop = pad.top + HubPickerLayout.screenMargin;
    final safeBottom = math.max(
      safeTop + 120,
      size.height - bottomObstruction - HubPickerLayout.screenMargin,
    );
    final anchorTop = widget.anchor.dy;
    final anchorBottom = widget.anchor.dy + widget.anchorSize.height;
    final spaceAbove =
        math.max(0.0, anchorTop - safeTop - HubPickerLayout.anchorGap);
    final spaceBelow = math.max(
      0.0,
      safeBottom - anchorBottom - HubPickerLayout.anchorGap,
    );
    final showBelow = spaceBelow >= estimatedHeight;
    final availableHeight = math.max(
      96.0,
      math.min(
        estimatedHeight,
        math.min(
          showBelow ? spaceBelow : spaceAbove,
          math.max(96.0, safeBottom - safeTop),
        ),
      ),
    );

    var left = widget.anchor.dx + widget.anchorSize.width / 2 - popupWidth / 2;
    left = left.clamp(
      HubPickerLayout.screenMargin,
      math.max(
        HubPickerLayout.screenMargin,
        size.width - popupWidth - HubPickerLayout.screenMargin,
      ),
    );

    final popupTop = showBelow
        ? (anchorBottom + HubPickerLayout.anchorGap)
            .clamp(safeTop, safeBottom - 80)
        : (anchorTop - HubPickerLayout.anchorGap - availableHeight).clamp(
            safeTop,
            anchorTop - HubPickerLayout.anchorGap,
          );

    _ensureDirectionalMotion(showBelow);
    final panelAlignment =
        showBelow ? Alignment.topCenter : Alignment.bottomCenter;

    final completed = LearningHubChapterCard.isWordModeComplete(
      widget.wordCount,
      widget.progress,
    );
    final known = widget.progress.knownCount;
    final total = widget.wordCount;

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
                  ..translateByDouble(0, _slideY!.value, 0, 1)
                  ..rotateX(_tiltX!.value)
                  ..scaleByDouble(_scale.value, _scale.value, 1, 1),
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
                          color: _wordAccent.withValues(
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
              child: _WordSwipePickerPanel(
                completed: completed,
                known: known,
                total: total,
                onStart: widget.onStart,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WordSwipePickerPanel extends StatelessWidget {
  const _WordSwipePickerPanel({
    required this.completed,
    required this.known,
    required this.total,
    required this.onStart,
  });

  final bool completed;
  final int known;
  final int total;
  final VoidCallback onStart;

  static const _wordAccent = Color(0xFFE67E22);

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HubModePickerHeader(
                  icon: Icons.style_rounded,
                  title: '단어 스와이프',
                  accent: _wordAccent,
                  guideBuilder: (dismiss) =>
                      WordSwipeModeGuideCard(onDismiss: dismiss),
                ),
                InkWell(
                  onTap: onStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '시작하기',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: DashboardPalette.navy,
                            ),
                          ),
                        ),
                        if (completed)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, right: 6),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: DashboardPalette.teal.withValues(alpha: 0.88),
                            ),
                          ),
                        _WordSwipeProgressRing(known: known, total: total),
                      ],
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

class _WordSwipeProgressRing extends StatelessWidget {
  const _WordSwipeProgressRing({
    required this.known,
    required this.total,
  });

  final int known;
  final int total;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const stroke = 3.5;
    const track = Color(0xFFE2E8F0);
    final ratio = total <= 0 ? 0.0 : (known / total).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _WordSwipeProgressRingPainter(
              ratio: ratio,
              trackColor: track,
              strokeWidth: stroke,
            ),
          ),
          Text(
            total <= 0 ? '' : '$known',
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

class _WordSwipeProgressRingPainter extends CustomPainter {
  const _WordSwipeProgressRingPainter({
    required this.ratio,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double ratio;
  final Color trackColor;
  final double strokeWidth;

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
    const colors = [Color(0xFFE67E22), Color(0xFFF59E0B)];
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
  bool shouldRepaint(covariant _WordSwipeProgressRingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}
