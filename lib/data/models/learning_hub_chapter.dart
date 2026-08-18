/// 학습 허브 — 비행 단계(챕터) 단위 카드 데이터.
class LearningHubChapter {
  final int chapterNo;
  final String name;
  final String language;
  final String hook;
  final String chapterImage;

  const LearningHubChapter({
    required this.chapterNo,
    required this.name,
    required this.language,
    this.hook = '',
    this.chapterImage = '',
  });

  String get displayTitle => 'Chapter $chapterNo. $name';
}
