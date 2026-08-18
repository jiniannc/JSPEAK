/// 시트 `chapter_image` 값을 Flutter [Image.asset] 경로로 정규화.
///
/// - `boarding.png` → `assets/images/boarding.png`
/// - `assets/images/boarding.png` → 그대로
/// - `learninghub icons/boarding.png` (레거시) → `assets/images/boarding.png`
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

  if (trimmed.startsWith('assets/images/')) return trimmed;

  if (trimmed.startsWith('assets/')) {
    final rest = trimmed.substring('assets/'.length);
    if (rest.startsWith('images/')) return trimmed;
    return 'assets/images/$rest';
  }

  if (trimmed.startsWith('images/')) {
    return 'assets/$trimmed';
  }

  if (RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(trimmed)) {
    return 'assets/images/${trimmed.replaceAll(RegExp(r'^/+'), '')}';
  }

  return '';
}
