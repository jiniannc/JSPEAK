/// 시트 `chapter_image` 값을 Flutter [Image.asset] 경로로 정규화.
///
/// - `assets/images/ch_boarding.png` → 그대로
/// - `ch_boarding.png` → `assets/images/ch_boarding.png`
/// - 한글 설명 등 비이미지 텍스트 → 빈 문자열 (폴백 아이콘)
String resolveChapterAssetPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('assets/')) return trimmed;

  if (RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(trimmed)) {
    return 'assets/images/${trimmed.replaceAll(RegExp(r'^/+'), '')}';
  }

  return '';
}
