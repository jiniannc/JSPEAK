import 'chapter_asset_path.dart';

/// 카테고리(챕터명) → `assets/images/*.webp` 폴백.
const Map<String, String> learningHubIconByCategory = {
  '탑승 안내': 'assets/images/boarding.webp',
  '좌석 안내': 'assets/images/seat.webp',
  '짐 보관 안내': 'assets/images/carryon.webp',
  '식사 서비스': 'assets/images/meal.webp',
  '유상 판매': 'assets/images/snacks.webp',
  '면세품 판매': 'assets/images/dutyfree.webp',
  '입국 서류': 'assets/images/documents.webp',
  '환자 승객 응대': 'assets/images/patients.webp',
  '안전 업무': 'assets/images/safety.webp',
  '이착륙 및 안전 안내': 'assets/images/safety.webp',
  '비상구열 브리핑': 'assets/images/briefing.webp',
  '개별 브리핑': 'assets/images/briefing.webp',
  '불만 승객 핸들링': 'assets/images/complain.webp',
  '불법 행위 승객 핸들링': 'assets/images/crime.webp',
  '특수 승객 응대': 'assets/images/patients.webp',
  '기타': 'assets/images/irre.webp',
};

const _fallbackIcon = 'assets/images/boarding.webp';

/// Sentences 시트 [chapter_image] 우선, 없으면 카테고리 기본 아이콘.
String resolveHubChapterIcon({
  required String chapterImage,
  required String category,
}) {
  final resolved = resolveChapterAssetPath(chapterImage);
  if (resolved.isNotEmpty) return resolved;
  return learningHubIconForCategory(category);
}

String learningHubIconForCategory(String category) {
  final trimmed = category.trim();
  if (trimmed.isEmpty) return _fallbackIcon;
  return learningHubIconByCategory[trimmed] ?? _fallbackIcon;
}
