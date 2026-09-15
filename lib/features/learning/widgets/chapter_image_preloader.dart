import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/active5_layout.dart';
import '../../../core/utils/learning_hub_icon.dart';
import '../../../data/models/learning_hub_chapter.dart';
import '../../../shared/widgets/chapter_hero_image.dart';
import 'learning_hub_chapter_card.dart';

/// 학습 허브 챕터 hero·thumb PNG 선로드.
abstract final class ChapterImagePreloader {
  static String? _sessionKey;
  static final Set<String> _heroReadyKeys = {};
  static final Set<String> _thumbReadyKeys = {};
  static Future<void>? _warmUpFuture;

  static const _compactThumbHeight = 64.0;
  static const _batchSize = 6;

  static double hubCardWidth(
    BuildContext context, {
    GlobalKey? viewportKey,
  }) {
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;
    final viewportBox =
        viewportKey?.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox != null && viewportBox.hasSize) {
      return math.max(0, viewportBox.size.width - inset * 2);
    }

    final mediaWidth = MediaQuery.sizeOf(context).width;
    final maxDeviceWidth = metrics.isLandscape
        ? Active5Layout.logicalWidthLandscape
        : Active5Layout.logicalWidthPortrait;
    return math.max(0, math.min(mediaWidth, maxDeviceWidth) - inset * 2);
  }

  static String _heroKey(String path, double cardWidth, double dpr) {
    final cacheWidth = ChapterHeroImage.heroCacheWidth(
      displayWidth: cardWidth,
      devicePixelRatio: dpr,
    );
    return '$path@hero@$cacheWidth';
  }

  static String _thumbKey(String path, double thumbWidth, double dpr) {
    final dims = ChapterHeroImage.thumbCacheDimensions(
      displayWidth: thumbWidth,
      displayHeight: _compactThumbHeight,
      devicePixelRatio: dpr,
    );
    return '$path@thumb@${dims.width ?? 0}x${dims.height ?? 0}';
  }

  static bool isHeroReady(
    String path, {
    required double cardWidth,
    required double devicePixelRatio,
  }) {
    if (path.isEmpty) return true;
    return _heroReadyKeys.contains(
      _heroKey(path, cardWidth, devicePixelRatio),
    );
  }

  static bool isChapterReady(
    LearningHubChapter chapter, {
    required double cardWidth,
    required double devicePixelRatio,
  }) {
    final path = resolveHubChapterIcon(
      chapterImage: chapter.chapterImage,
      category: chapter.name,
    );
    return isHeroReady(
      path,
      cardWidth: cardWidth,
      devicePixelRatio: devicePixelRatio,
    );
  }

  static void resetSession() {
    _sessionKey = null;
    _heroReadyKeys.clear();
    _thumbReadyKeys.clear();
    _warmUpFuture = null;
  }

  static Future<void> warmUpChapters(
    BuildContext context, {
    required String language,
    required List<LearningHubChapter> chapters,
    required double cardWidth,
    Iterable<String> priorityChapterKeys = const [],
  }) {
    if (!context.mounted || chapters.isEmpty) {
      return Future.value();
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sessionKey =
        '$language@${cardWidth.toStringAsFixed(1)}@${dpr.toStringAsFixed(2)}';
    if (_sessionKey == sessionKey && _warmUpFuture != null) {
      return _warmUpChaptersWithPriority(
        context,
        chapters: chapters,
        cardWidth: cardWidth,
        devicePixelRatio: dpr,
        priorityChapterKeys: priorityChapterKeys,
      );
    }

    _sessionKey = sessionKey;
    _warmUpFuture = _warmUpChaptersWithPriority(
      context,
      chapters: chapters,
      cardWidth: cardWidth,
      devicePixelRatio: dpr,
      priorityChapterKeys: priorityChapterKeys,
    );
    return _warmUpFuture!;
  }

  static String chapterKey(LearningHubChapter chapter) =>
      '${chapter.chapterNo}|${chapter.name}';

  static Future<void> _warmUpChaptersWithPriority(
    BuildContext context, {
    required List<LearningHubChapter> chapters,
    required double cardWidth,
    required double devicePixelRatio,
    required Iterable<String> priorityChapterKeys,
  }) async {
    if (!context.mounted || chapters.isEmpty) return;

    final priority = priorityChapterKeys.toSet();
    final ordered = [
      for (final chapter in chapters)
        if (priority.contains(chapterKey(chapter))) chapter,
      for (final chapter in chapters)
        if (!priority.contains(chapterKey(chapter))) chapter,
    ];

    await _warmUpChapters(
      context,
      chapters: ordered,
      cardWidth: cardWidth,
      devicePixelRatio: devicePixelRatio,
    );
  }

  static Future<void> precacheNeighbors(
    BuildContext context, {
    required List<LearningHubChapter> chapters,
    required String focusChapterKey,
    required double cardWidth,
  }) async {
    if (!context.mounted || chapters.isEmpty) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final index = chapters.indexWhere(
      (chapter) =>
          '${chapter.chapterNo}|${chapter.name}' == focusChapterKey,
    );
    if (index < 0) return;

    final targets = <LearningHubChapter>{
      chapters[index],
      if (index > 0) chapters[index - 1],
      if (index + 1 < chapters.length) chapters[index + 1],
      if (index + 2 < chapters.length) chapters[index + 2],
    };

    await Future.wait(
      targets.map(
        (chapter) => _precacheChapter(
          context,
          chapter: chapter,
          cardWidth: cardWidth,
          devicePixelRatio: dpr,
        ),
      ),
    );
  }

  static Future<void> _warmUpChapters(
    BuildContext context, {
    required List<LearningHubChapter> chapters,
    required double cardWidth,
    required double devicePixelRatio,
  }) async {
    for (var start = 0; start < chapters.length; start += _batchSize) {
      if (!context.mounted) return;
      final end = math.min(start + _batchSize, chapters.length);
      final batch = chapters.sublist(start, end);
      await Future.wait(
        batch.map(
          (chapter) => _precacheChapter(
            context,
            chapter: chapter,
            cardWidth: cardWidth,
            devicePixelRatio: devicePixelRatio,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  static Future<void> warmUpNewUpdateThumbs(
    BuildContext context, {
    required List<String> assetPaths,
    required double displayWidth,
    required double displayHeight,
  }) async {
    if (!context.mounted || assetPaths.isEmpty || displayWidth <= 0) {
      return;
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final uniquePaths = assetPaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet();

    for (final path in uniquePaths) {
      if (!context.mounted) return;
      try {
        await precacheImage(
          ChapterHeroImage.thumbProvider(
            path,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            devicePixelRatio: dpr,
          ),
          context,
        );
      } catch (_) {
        // errorBuilder 폴백
      }
    }
  }

  static Future<void> _precacheChapter(
    BuildContext context, {
    required LearningHubChapter chapter,
    required double cardWidth,
    required double devicePixelRatio,
  }) async {
    if (!context.mounted) return;

    final path = resolveHubChapterIcon(
      chapterImage: chapter.chapterImage,
      category: chapter.name,
    );
    if (path.isEmpty) return;

    LearningHubChapterCard.aspectRatioCache.putIfAbsent(
      path,
      () => LearningHubChapterCard.fallbackAspectRatio,
    );

    final heroKey = _heroKey(path, cardWidth, devicePixelRatio);
    if (!_heroReadyKeys.contains(heroKey)) {
      try {
        final provider = ChapterHeroImage.heroProvider(
          path,
          displayWidth: cardWidth,
          devicePixelRatio: devicePixelRatio,
        );
        await precacheImage(provider, context);
        _heroReadyKeys.add(heroKey);
      } catch (_) {
        // errorBuilder 폴백 — 카드는 표시
      }
    }

    if (!context.mounted) return;

    final aspect = LearningHubChapterCard.aspectRatioCache[path] ??
        LearningHubChapterCard.fallbackAspectRatio;
    final thumbWidth = _compactThumbHeight * aspect;
    final thumbKey = _thumbKey(path, thumbWidth, devicePixelRatio);
    if (!_thumbReadyKeys.contains(thumbKey)) {
      try {
        await precacheImage(
          ChapterHeroImage.thumbProvider(
            path,
            displayWidth: thumbWidth,
            displayHeight: _compactThumbHeight,
            devicePixelRatio: devicePixelRatio,
          ),
          context,
        );
        _thumbReadyKeys.add(thumbKey);
      } catch (_) {
        // thumb 실패는 hero만으로도 펼침 가능
      }
    }
  }

}
