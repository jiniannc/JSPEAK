import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/learning_providers.dart';
import '../../../app/new_update_scenario_provider.dart';
import '../../../app/providers.dart';
import '../../../data/models/content_bundle.dart';
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
  static const _arrowLaneWidth = 24.0;
  static const _arrowGap = 6.0;

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

  void _openEntry(NewUpdateEntry entry) {
    switch (entry) {
      case NewUpdateScenarioEntry(:final scenario):
        selectLearningLanguage(ref, scenario.language);
        context.push('/scenarios/train/${scenario.id}', extra: scenario);
      case NewUpdateSentenceEntry(:final group):
        selectLearningLanguage(ref, group.language);
        context.push(
          '/scenarios/sentences/play'
          '?lang=${Uri.encodeComponent(group.language)}'
          '&category=${Uri.encodeComponent(group.fullCategory)}',
        );
    }
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
    List<NewUpdateEntry> entries,
    ContentBundle? bundle,
  ) {
    if (bundle == null) return const [];
    return entries
        .map((entry) => newUpdateEntryImageAsset(bundle, entry))
        .where((path) => path.isNotEmpty)
        .toList();
  }

  static String _entriesKey(List<NewUpdateEntry> entries) =>
      entries.map((entry) => entry.key).join('|');

  Future<void> _resolveAspects(
    List<NewUpdateEntry> entries,
    ContentBundle? bundle,
  ) async {
    final key = _entriesKey(entries);
    if (_aspectWarmUpKey == key) return;
    _aspectWarmUpKey = key;

    final paths = _imagePaths(entries, bundle);
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
    required List<NewUpdateEntry> entries,
    required ContentBundle? bundle,
    required double subCardWidth,
  }) async {
    final key = '${_entriesKey(entries)}@$subCardWidth';
    if (_thumbWarmUpKey == key) return;
    _thumbWarmUpKey = key;

    final paths = _imagePaths(entries, bundle);
    if (paths.isEmpty || !context.mounted) return;

    final maxImageHeight = _maxImageHeight(subCardWidth, entries, bundle);
    await ChapterImagePreloader.warmUpNewUpdateThumbs(
      context,
      assetPaths: paths,
      displayWidth: subCardWidth,
      displayHeight: maxImageHeight,
    );
  }

  double _maxImageHeight(
    double cardWidth,
    List<NewUpdateEntry> entries,
    ContentBundle? bundle,
  ) {
    var maxImage = 0.0;
    for (final entry in entries) {
      final asset =
          bundle == null ? '' : newUpdateEntryImageAsset(bundle, entry);
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

    final entries = snapshot.entries;
    final bundle = ref.watch(contentProvider).value?.bundle;
    ref.listen(newUpdateScenarioProvider, (previous, next) {
      if (_entriesKey(previous?.entries ?? const []) !=
          _entriesKey(next.entries)) {
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

    unawaited(_resolveAspects(entries, bundle));

    return DashboardCompactLinkCard(
      tintColors: [
        const Color(0xFFFAFAF9).withValues(alpha: 0.94),
        const Color(0xFFF5F5F4).withValues(alpha: 0.78),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
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
                final showArrows = entries.length > _visibleCount;
                final trackWidth = constraints.maxWidth;
                final arrowLanes = showArrows
                    ? _arrowLaneWidth * 2 + _arrowGap * 2
                    : 0.0;
                // 카드 크기·높이는 항상 '3열' 기준으로 고정 (1~2장이어도 왼쪽에 같은 폭).
                final gapsSpace = _cardGap * (_visibleCount - 1);
                final subCardWidth =
                    (trackWidth - arrowLanes - gapsSpace) / _visibleCount;
                final pageWidth = subCardWidth + _cardGap;
                final maxImageHeight = _maxImageHeight(
                  subCardWidth,
                  entries,
                  bundle,
                );
                final stripHeight = maxImageHeight +
                    _NewUpdateSubCard.textBlockHeight;

                final thumbKey = '${_entriesKey(entries)}@$subCardWidth';
                if (_thumbWarmUpKey != thumbKey &&
                    _thumbScheduleKey != thumbKey) {
                  _thumbScheduleKey = thumbKey;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    unawaited(
                      _precacheThumbs(
                        context,
                        entries: entries,
                        bundle: bundle,
                        subCardWidth: subCardWidth,
                      ),
                    );
                  });
                }

                Widget buildSubCard(NewUpdateEntry entry) {
                  return _NewUpdateSubCard(
                    entry: entry,
                    bundle: bundle,
                    cardWidth: subCardWidth,
                    cardHeight: stripHeight,
                    imageSlotHeight: maxImageHeight,
                    onTap: () => _openEntry(entry),
                  );
                }

                final strip = entries.length <= _visibleCount
                    ? SizedBox(
                        height: stripHeight,
                        width: trackWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            for (var i = 0; i < entries.length; i++) ...[
                              if (i > 0) const SizedBox(width: _cardGap),
                              SizedBox(
                                width: subCardWidth,
                                child: buildSubCard(entries[i]),
                              ),
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
                            itemCount: entries.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: _cardGap),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                width: subCardWidth,
                                height: stripHeight,
                                child: buildSubCard(entries[index]),
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
    final lane = _NewUpdateScenarioCardState._arrowLaneWidth;
    final isLeft = icon == Icons.chevron_left_rounded;
    return SizedBox(
      width: lane,
      child: Center(
        child: Material(
          color: DashboardPalette.cardWhite.withValues(
            alpha: enabled ? 0.92 : 0.6,
          ),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Transform.translate(
                  offset: Offset(isLeft ? 0.5 : -0.5, 0),
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
        ),
      ),
    );
  }
}

class _NewUpdateSubCard extends StatelessWidget {
  final NewUpdateEntry entry;
  final ContentBundle? bundle;
  final double cardWidth;
  final double cardHeight;
  final double imageSlotHeight;
  final VoidCallback onTap;

  const _NewUpdateSubCard({
    required this.entry,
    required this.bundle,
    required this.cardWidth,
    required this.cardHeight,
    required this.imageSlotHeight,
    required this.onTap,
  });

  static const textBlockHeight = 96.0;
  static const _newCoral = Color(0xFFFF5252);
  static const _sentenceAccent = Color(0xFFE11D48);

  String get _chapterImage =>
      bundle == null ? '' : newUpdateEntryImageAsset(bundle!, entry);

  double get _imageHeight => ChapterImageAspect.displayHeight(
        assetPath: _chapterImage,
        displayWidth: cardWidth,
      );

  String get _chapterLabel => switch (entry) {
        NewUpdateScenarioEntry(:final scenario) => bundle == null
            ? 'Ch.${scenario.chapterNo}'
            : newUpdateChapterShortLabel(bundle!, scenario),
        NewUpdateSentenceEntry(:final group) =>
          newUpdateSentenceChapterShortLabel(group),
      };

  String get _title => switch (entry) {
        NewUpdateScenarioEntry(:final scenario) => scenario.title,
        NewUpdateSentenceEntry(:final group) => group.label,
      };

  List<Widget> get _chips => switch (entry) {
        NewUpdateScenarioEntry(:final scenario) => [
            _ScenarioLevelChip(label: scenarioLevelLabel(scenario.level)),
            const SizedBox(width: 5),
            _SubCardMetaChip(label: '${scenario.lines.length}문장'),
          ],
        NewUpdateSentenceEntry(:final group) => [
            _SubCardMetaChip(label: '${group.sentenceCount}문장'),
          ],
      };

  String get _modeLabel => switch (entry) {
        NewUpdateScenarioEntry() => '롤플레잉',
        NewUpdateSentenceEntry() => '스피킹',
      };

  Color get _modeColor => switch (entry) {
        NewUpdateScenarioEntry() => DashboardPalette.teal,
        NewUpdateSentenceEntry() => _sentenceAccent,
      };

  @override
  Widget build(BuildContext context) {
    final chapterLabel = _chapterLabel;
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _ImageTag(
                                label: 'NEW',
                                textColor: _newCoral,
                                fillColor: Color(0xEBFFFFFF),
                                letterSpacing: 0.4,
                              ),
                              const SizedBox(width: 3),
                              _ImageTag(
                                label: _modeLabel,
                                textColor: Colors.white,
                                fillColor:
                                    _modeColor.withValues(alpha: 0.92),
                              ),
                            ],
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
                                    _title,
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
                                      children: _chips,
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

/// 썸네일 좌상단 소형 태그 (NEW · 학습 모드).
class _ImageTag extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color fillColor;
  final double letterSpacing;

  const _ImageTag({
    required this.label,
    required this.textColor,
    required this.fillColor,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: letterSpacing,
            color: textColor,
            height: 1,
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
