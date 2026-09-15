import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/chapter_asset_path.dart';

/// 챕터 히어로·썸네일 PNG.
///
/// 히어로는 표시 물리 해상도의 2.75배로 디코딩한 뒤 한 번만 축소한다.
/// 원본 비율 보존을 위해 cacheWidth만 지정한다.
class ChapterHeroImage extends StatelessWidget {
  const ChapterHeroImage({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.profile = ChapterImageProfile.hero,
    this.borderRadius,
    this.errorBuilder,
  });

  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;

  final ChapterImageProfile profile;
  final BorderRadius? borderRadius;
  final ImageErrorWidgetBuilder? errorBuilder;

  static const _maxThumbCacheEdge = 512;
  static const _thumbCacheMultiplier = 3.0;
  static const _maxHeroCacheWidth = 1920;
  static const _heroCacheMultiplier = 2.75;

  static int heroCacheWidth({
    required double displayWidth,
    required double devicePixelRatio,
  }) {
    return (displayWidth * devicePixelRatio * _heroCacheMultiplier)
        .round()
        .clamp(1, _maxHeroCacheWidth);
  }

  static ({int? width, int? height}) thumbCacheDimensions({
    required double displayWidth,
    required double displayHeight,
    required double devicePixelRatio,
  }) {
    final safeWidth = displayWidth.isFinite ? displayWidth : displayHeight;
    final safeHeight = displayHeight.isFinite ? displayHeight : displayWidth;
    final longEdge =
        (math.max(safeWidth, safeHeight) *
                devicePixelRatio *
                _thumbCacheMultiplier)
            .round()
            .clamp(1, _maxThumbCacheEdge);

    if (safeWidth >= safeHeight) {
      return (width: longEdge, height: null);
    }
    return (width: null, height: longEdge);
  }

  static ImageProvider assetProvider(String assetPath) {
    final resolved = resolveChapterAssetPath(assetPath);
    return AssetImage(resolved);
  }

  static ImageProvider heroProvider(
    String assetPath, {
    required double displayWidth,
    required double devicePixelRatio,
  }) {
    final resolved = resolveChapterAssetPath(assetPath);
    return ResizeImage(
      AssetImage(resolved),
      width: heroCacheWidth(
        displayWidth: displayWidth,
        devicePixelRatio: devicePixelRatio,
      ),
    );
  }

  static ImageProvider thumbProvider(
    String assetPath, {
    required double displayWidth,
    required double displayHeight,
    required double devicePixelRatio,
  }) {
    final resolved = resolveChapterAssetPath(assetPath);
    final cache = thumbCacheDimensions(
      displayWidth: displayWidth,
      displayHeight: displayHeight,
      devicePixelRatio: devicePixelRatio,
    );
    return ResizeImage(
      AssetImage(resolved),
      width: cache.width,
      height: cache.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveChapterAssetPath(assetPath);
    if (resolved.isEmpty) {
      return _wrapClip(
        _buildError(context, Exception('empty asset'), StackTrace.current),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final isHero = profile == ChapterImageProfile.hero;
    final provider = isHero
        ? heroProvider(
            assetPath,
            displayWidth: width,
            devicePixelRatio: dpr,
          )
        : thumbProvider(
            assetPath,
            displayWidth: width,
            displayHeight: height,
            devicePixelRatio: dpr,
          );

    final image = Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: isHero ? FilterQuality.high : FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return ColoredBox(
          color: const Color(0xFFF1F5F9),
          child: SizedBox(width: width, height: height),
        );
      },
      errorBuilder:
          errorBuilder ??
          (context, error, stackTrace) =>
              _buildError(context, error, stackTrace),
    );

    return _wrapClip(SizedBox(width: width, height: height, child: image));
  }

  Widget _wrapClip(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error, stackTrace ?? StackTrace.empty);
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      alignment: Alignment.center,
      child: Icon(
        Icons.flight_rounded,
        size: profile == ChapterImageProfile.thumb ? 22 : 48,
        color: const Color(0xFF94A3B8),
      ),
    );
  }
}

enum ChapterImageProfile { hero, thumb }

/// 챕터 PNG 실측 비율(width / height) — 레이아웃 높이 산출용.
abstract final class ChapterImageAspect {
  ChapterImageAspect._();

  static const double fallback = 3 / 2;
  static final Map<String, double> cache = {};
  static final Map<String, Future<double>> _inflight = {};

  static String _key(String assetPath) => resolveChapterAssetPath(assetPath);

  static double ratioFor(String assetPath) {
    final key = _key(assetPath);
    if (key.isEmpty) return fallback;
    return cache[key] ?? fallback;
  }

  static double displayHeight({
    required String assetPath,
    required double displayWidth,
  }) {
    if (displayWidth <= 0) return 0;
    return displayWidth / ratioFor(assetPath);
  }

  static Future<double> resolveAsync(String assetPath) {
    final key = _key(assetPath);
    if (key.isEmpty) return Future.value(fallback);

    final cached = cache[key];
    if (cached != null) return Future.value(cached);

    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = _resolveRatio(key);
    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  static Future<double> _resolveRatio(String key) {
    final stream = AssetImage(key).resolve(const ImageConfiguration());
    final completer = Completer<double>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, _) {
        stream.removeListener(listener);
        final h = info.image.height.toDouble();
        final w = info.image.width.toDouble();
        final ratio = h <= 0 ? fallback : w / h;
        cache[key] = ratio;
        if (!completer.isCompleted) completer.complete(ratio);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        cache[key] = fallback;
        if (!completer.isCompleted) completer.complete(fallback);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  static Future<void> resolveAll(Iterable<String> assetPaths) {
    final unique = assetPaths.map(_key).where((key) => key.isNotEmpty).toSet();
    if (unique.isEmpty) return Future.value();
    return Future.wait(
      unique.map((key) => resolveAsync(key)),
    );
  }

  static void ensureResolved(String assetPath, VoidCallback onUpdated) {
    final key = _key(assetPath);
    if (key.isEmpty) return;
    if (cache.containsKey(key)) return;
    resolveAsync(assetPath).then((_) => onUpdated());
  }
}
