/// 시트 `chapter_image` 값을 Flutter [Image.asset] 경로로 정규화.
///
/// 시트 CMS는 여전히 `.png` 파일명을 보낼 수 있다. 번들 에셋은 WebP이므로
/// 확장자는 `.webp`로 맞춘다.
///
/// - `boarding.png` → `assets/images/boarding.webp`
/// - `ch_boarding.png` / `sent_ch_boarding.png` → `assets/images/boarding.webp`
/// - `assets/images/ch_boarding.png` → `assets/images/boarding.webp`
/// - `learninghub icons/boarding.png` (레거시) → `assets/images/boarding.webp`
/// - 한글 설명 등 비이미지 텍스트 → 빈 문자열 (폴백 아이콘)
String resolveChapterAssetPath(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  trimmed = trimmed.replaceAll('\\', '/');

  while (trimmed.startsWith('assets/assets/')) {
    trimmed = trimmed.substring('assets/'.length);
  }

  // 레거시 서브폴더 → images/ 루트
  trimmed = trimmed.replaceAll(RegExp(r'learninghub\s+icons/', caseSensitive: false), '');
  trimmed = trimmed.replaceAll('learninghub%20icons/', '');

  String? basename;
  if (trimmed.startsWith('assets/images/')) {
    basename = trimmed.substring('assets/images/'.length);
  } else if (trimmed.startsWith('assets/')) {
    final rest = trimmed.substring('assets/'.length);
    basename = rest.startsWith('images/') ? rest.substring('images/'.length) : rest;
  } else if (trimmed.startsWith('images/')) {
    basename = trimmed.substring('images/'.length);
  } else if (RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(trimmed)) {
    basename = trimmed.replaceAll(RegExp(r'^/+'), '');
  } else {
    return '';
  }

  basename = _normalizeChapterImageBasename(basename);
  if (basename.isEmpty) return '';
  return 'assets/images/$basename';
}

/// Sheets often use language-prefixed names (`ch_boarding`, `sent_ch_meal`) while
/// bundled assets use the plain category filename (`boarding.webp`, `meal.webp`).
String _normalizeChapterImageBasename(String filename) {
  var name = filename.trim().replaceAll('\\', '/');
  if (name.contains('/')) {
    name = name.split('/').last;
  }

  final lower = name.toLowerCase();
  for (final prefix in const ['sent_ch_', 'word_ch_', 'ch_']) {
    if (lower.startsWith(prefix)) {
      name = name.substring(prefix.length);
      break;
    }
  }

  name = name.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.webp');

  // 시트 `ch_etc` → etc.webp (번들에는 irre.webp만 존재).
  final baseLower = name.toLowerCase();
  if (baseLower == 'etc.webp' || baseLower == 'etc') {
    return 'irre.webp';
  }

  return name;
}
