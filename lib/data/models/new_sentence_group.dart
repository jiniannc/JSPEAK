/// 홈 NEW UPDATE — new 표시된 문장이 하나라도 있는 `주제 (세부그룹)` 묶음.
class NewSentenceGroup {
  final String language;
  final int chapterNo;

  /// 시트 category 원문 — 문장 스피킹 진입 키.
  final String fullCategory;

  /// 괄호 앞 상위 주제.
  final String baseName;

  /// 괄호 안 세부그룹. 괄호가 없으면 [baseName].
  final String label;
  final String chapterImage;

  /// 그룹 전체 문장 수.
  final int sentenceCount;

  const NewSentenceGroup({
    required this.language,
    required this.chapterNo,
    required this.fullCategory,
    required this.baseName,
    required this.label,
    required this.chapterImage,
    required this.sentenceCount,
  });
}
