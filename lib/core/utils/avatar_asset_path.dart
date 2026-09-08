import 'chapter_asset_path.dart';

/// 시트 `avatar_image` 값 → `assets/images/avatar_*.png` 경로.
///
/// - `avatar_normal` → `assets/images/avatar_normal.png`
/// - `avatarm_snacks` → `assets/images/avatarm_snacks.png`
/// - `avatar_normal.png` → `assets/images/avatar_normal.png`
String resolveAvatarAssetPath(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final viaChapter = resolveChapterAssetPath(trimmed);
  if (viaChapter.isNotEmpty) return viaChapter;

  trimmed = trimmed.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
  if (RegExp(r'^avatarm?_').hasMatch(trimmed)) {
    if (!RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false)
        .hasMatch(trimmed)) {
      trimmed = '$trimmed.png';
    }
    return 'assets/images/$trimmed';
  }

  return '';
}
