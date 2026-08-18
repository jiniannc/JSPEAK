/// Sentences / Words 시트의 챕터 메타 (category = 챕터명).
class ContentChapter {
  final int chapterNo;
  final String name;
  final String chapterImage;
  final String language;

  const ContentChapter({
    required this.chapterNo,
    required this.name,
    this.chapterImage = '',
    required this.language,
  });

  String get displayTitle => 'Chapter $chapterNo. $name';
}
