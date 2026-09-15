import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/learning_providers.dart';
import '../../../app/new_update_scenario_provider.dart';
import '../../../app/providers.dart';
import '../../../data/models/content_bundle.dart';
import '../../../data/models/scenario.dart';
import '../../../features/learning/widgets/chapter_image_preloader.dart';
import '../../../shared/widgets/chapter_hero_image.dart';
import '../dashboard_palette.dart';
import 'dashboard_compact_link_card.dart';

/// 홈 — 신규 시나리오 가로 서브카드 캐러셀.
class NewUpdateScenarioCard extends ConsumerStatefulWidget {
  const NewUpdateScenarioCard({super.key});

  @override
  ConsumerState<NewUpdateScenarioCard> createState() =>
      _NewUpdateScenarioCardState();
}

class _NewUpdateScenarioCardState extends ConsumerState<NewUpdateScenarioCard> {
  static const _visibleCount = 3;
  static const _cardGap = 8.0;
  static const _arrowSize = 20.0;
  static const _arrowLaneWidth = 22.0;
  static const _arrowGap = 4.0;

  final _scrollController = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = false;
  String? _aspectWarmUpKey;
  String? _thumbWarmUpKey;
  String? _thumbScheduleKey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncScrollArrows();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncScrollArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncScrollArrows() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    const tolerance = 1.0;
    final back = position.pixels > position.minScrollExtent + tolerance;
    final forward = position.pixels < position.maxScrollExtent - tolerance;
    if (back == _canScrollBack && forward == _canScrollForward) return;
    setState(() {
      _canScrollBack = back;
      _canScrollForward = forward;
    });
  }

  void _openScenario(Scenario scenario) {
    selectLearningLanguage(ref, scenario.language);
    context.push('/scenarios/train/${scenario.id}', extra: scenario);
  }

  Future<void> _scrollByPage(double pageWidth) async {
    if (!_scrollController.hasClients || pageWidth == 0) return;
    final position = _scrollController.position;
    final target = (position.pixels + pageWidth).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;

    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted) _syncScrollArrows();
  }

  List<String> _imagePaths(
    List<Scenario> scenarios,
    ContentBundle? bundle,
  ) {
    if (bundle == null) return const [];
    return scenarios
        .map((scenario) => newUpdateChapterImageAsset(bundle, scenario))
        .where((path) => path.isNotEmpty)
        .toList();
  }

  Future<void> _resolveAspects(
    List<Scenario> scenarios,
    ContentBundle? bundle,
  ) async {
    final key = scenarios.map((scenario) => scenario.id).join('|');
    if (_aspectWarmUpKey == key) return;
    _aspectWarmUpKey = key;

    final paths = _imagePaths(scenarios, bundle);
    if (paths.isEmpty) return;

    await ChapterImageAspect.resolveAll(paths);
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncScrollArrows();
    });
  }

  Future<void> _precacheThumbs(
    BuildContext context, {
    required List<Scenario> scenarios,
    required ContentBundle? bundle,
    required double subCardWidth,
  }) async {
    final key =
        '${scenarios.map((scenario) => scenario.id).join('|')}@$subCardWidth';
    if (_thumbWarmUpKey == key) return;
    _thumbWarmUpKey = key;

    final paths = _imagePaths(scenarios, bundle);
    if (paths.isEmpty || !context.mounted) return;

    final maxImageHeight = _maxImageHeight(subCardWidth, scenarios, bundle);
    await ChapterImagePreloader.warmUpNewUpdateThumbs(
      context,
      assetPaths: paths,
      displayWidth: subCardWidth,
      displayHeight: maxImageHeight,
    );
  }

  double _maxImageHeight(
    double cardWidth,
    List<Scenario> scenarios,
    ContentBundle? bundle,
  ) {
    var maxImage = 0.0;
    for (final scenario in scenarios) {
      final asset = bundle == null
          ? ''
          : newUpdateChapterImageAsset(bundle, scenario);
      maxImage = math.max(
        maxImage,
        ChapterImageAspect.displayHeight(
          assetPath: asset,
          displayWidth: cardWidth,
        ),
      );
    }
    return maxImage;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(newUpdateScenarioProvider);
    if (!snapshot.hasUpdates) return const SizedBox.shrink();

    final scenarios = snapshot.scenarios;
    final bundle = ref.watch(contentProvider).value?.bundle;
    ref.listen(newUpdateScenarioProvider, (previous, next) {
      if (previous?.count != next.count) {
        _aspectWarmUpKey = null;
        _thumbWarmUpKey = null;
        _thumbScheduleKey = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncScrollArrows();
        });
      }
    });
    ref.listen(contentProvider, (previous, next) {
      if (previous?.value?.bundle != next.value?.bundle) {
        _aspectWarmUpKey = null;
        _thumbWarmUpKey = null;
        _thumbScheduleKey = null;
      }
    });

    unawaited(_resolveAspects(scenarios, bundle));

    return DashboardCompactLinkCard(
      tintColors: [
        const Color(0xFFFAFAF9).withValues(alpha: 0.94),
        const Color(0xFFF5F5F4).withValues(alpha: 0.78),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardSectionLabel(
                  icon: Icons.auto_awesome_rounded,
                  label: 'NEW UPDATE',
                  accent: DashboardPalette.sectionNewUpdate,
                ),
                const SizedBox(width: 8),
                DashboardMetaChip(label: '${snapshot.count}개'),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final showArrows = scenarios.length > _visibleCount;
                final trackWidth = constraints.maxWidth;
                final arrowLanes = showArrows
                    ? _arrowLaneWidth * 2 + _arrowGap * 2
                    : 0.0;
                final gapsSpace = _cardGap * (_visibleCount - 1);
                final subCardWidth =
                    (trackWidth - arrowLanes - gapsSpace) / _visibleCount;
                final pageWidth = subCardWidth + _cardGap;
                final maxImageHeight = _maxImageHeight(
                  subCardWidth,
                  scenarios,
                  bundle,
                );
                final stripHeight = maxImageHeight +
                    _NewUpdateScenarioSubCard.textBlockHeight;

                final thumbKey =
                    '${scenarios.map((scenario) => scenario.id).join('|')}@$subCardWidth';
                if (_thumbWarmUpKey != thumbKey &&
                    _thumbScheduleKey != thumbKey) {
                  _thumbScheduleKey = thumbKey;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    unawaited(
                      _precacheThumbs(
                        context,
                        scenarios: scenarios,
                        bundle: bundle,
                        subCardWidth: subCardWidth,
                      ),
                    );
                  });
                }

                Widget buildSubCard(Scenario scenario) {
                  return _NewUpdateScenarioSubCard(
                    scenario: scenario,
                    bundle: bundle,
                    cardWidth: subCardWidth,
                    cardHeight: stripHeight,
                    imageSlotHeight: maxImageHeight,
                    onTap: () => _openScenario(scenario),
                  );
                }

                final strip = scenarios.length <= _visibleCount
                    ? SizedBox(
                        height: stripHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < scenarios.length; i++) ...[
                              if (i > 0) const SizedBox(width: _cardGap),
                              Expanded(child: buildSubCard(scenarios[i])),
                            ],
                          ],
                        ),
                      )
                    : SizedBox(
                        height: stripHeight,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification ||
                                notification is ScrollEndNotification) {
                              _syncScrollArrows();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            itemCount: scenarios.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: _cardGap),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: subCardWidth,
                                height: stripHeight,
                                child: buildSubCard(scenarios[index]),
                              );
                            },
                          ),
                        ),
                      );

                if (!showArrows) return strip;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CarouselArrow(
                      icon: Icons.chevron_left_rounded,
                      enabled: _canScrollBack,
                      onPressed: () => _scrollByPage(-pageWidth),
                    ),
                    SizedBox(width: _arrowGap),
                    Expanded(child: strip),
                    SizedBox(width: _arrowGap),
                    _CarouselArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canScrollForward,
                      onPressed: () => _scrollByPage(pageWidth),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _CarouselArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = _NewUpdateScenarioCardState._arrowSize;
    return SizedBox(
      width: _NewUpdateScenarioCardState._arrowLaneWidth,
      child: Center(
        child: Material(
          color: DashboardPalette.cardWhite.withValues(
            alpha: enabled ? 0.92 : 0.6,
          ),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: 15,
                color: enabled
                    ? DashboardPalette.sectionNewUpdate
                    : DashboardPalette.textMuted.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewUpdateScenarioSubCard extends StatelessWidget {
  final Scenario scenario;
  final ContentBundle? bundle;
  final double cardWidth;
  final double cardHeight;
  final double imageSlotHeight;
  final VoidCallback onTap;

  const _NewUpdateScenarioSubCard({
    required this.scenario,
    required this.bundle,
    required this.cardWidth,
    required this.cardHeight,
    required this.imageSlotHeight,
    required this.onTap,
  });

  static const textBlockHeight = 96.0;
  static const _newCoral = Color(0xFFFF5252);

  String get _chapterImage => bundle == null
      ? ''
      : newUpdateChapterImageAsset(bundle!, scenario);

  double get _imageHeight => ChapterImageAspect.displayHeight(
        assetPath: _chapterImage,
        displayWidth: cardWidth,
      );

  @override
  Widget build(BuildContext context) {
    final chapterLabel = bundle == null
        ? 'Ch.${scenario.chapterNo}'
        : newUpdateChapterShortLabel(bundle!, scenario);
    final level = scenarioLevelLabel(scenario.level);
    final lineCount = scenario.lines.length;
    final imageHeight = _imageHeight;

    const radius = BorderRadius.all(Radius.circular(12));

    return SizedBox(
      height: cardHeight,
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: DashboardPalette.cardWhite.withValues(alpha: 0.97),
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: imageSlotHeight,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ColoredBox(
                          color: DashboardPalette.jinSpecFill,
                          child: SizedBox(
                            width: cardWidth,
                            height: imageSlotHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ChapterHeroImage(
                                assetPath: _chapterImage,
                                width: cardWidth,
                                height: imageHeight,
                                profile: ChapterImageProfile.thumb,
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: _newCoral,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFFFDFCFB),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  DashboardPalette.borderLight
                                      .withValues(alpha: 0),
                                  DashboardPalette.borderLight
                                      .withValues(alpha: 0.72),
                                  DashboardPalette.borderLight
                                      .withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(9, 8, 9, 7),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 2,
                                        height: 11,
                                        margin:
                                            const EdgeInsets.only(top: 1),
                                        decoration: BoxDecoration(
                                          color: DashboardPalette
                                              .sectionNewUpdate
                                              .withValues(alpha: 0.32),
                                          borderRadius:
                                              BorderRadius.circular(1),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          chapterLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                            letterSpacing: 0.28,
                                            color: DashboardPalette
                                                .sectionNewUpdate
                                                .withValues(alpha: 0.82),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scenario.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.24,
                                      letterSpacing: -0.12,
                                      color: DashboardPalette.navy
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    height: 0.5,
                                    margin:
                                        const EdgeInsets.only(bottom: 6),
                                    color: const Color(0xFFE9E5EE)
                                        .withValues(alpha: 0.85),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ScenarioLevelChip(label: level),
                                        const SizedBox(width: 5),
                                        _SubCardMetaChip(
                                          label: '$lineCount문장',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _SubCardMetaChip extends StatelessWidget {
  final String label;

  const _SubCardMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1F5).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFFD8D2DC).withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            color: DashboardPalette.textMuted.withValues(alpha: 0.88),
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _ScenarioLevelChip extends StatelessWidget {
  final String label;

  const _ScenarioLevelChip({required this.label});

  static Color _accentFor(String level) {
    final normalized = level.trim();
    final lower = normalized.toLowerCase();
    if (normalized.contains('초급') || lower == 'beginner') {
      return const Color(0xFF6F9A82);
    }
    if (normalized.contains('중급') || lower == 'intermediate') {
      return const Color(0xFFA8895C);
    }
    if (normalized.contains('상급') ||
        normalized.contains('고급') ||
        lower == 'advanced') {
      return const Color(0xFFAE7878);
    }
    return const Color(0xFF8A94A6);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(label);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12,
            color: accent.withValues(alpha: 0.92),
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
