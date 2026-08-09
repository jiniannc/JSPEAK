import '../../core/utils/chapter_asset_path.dart';

/// 시나리오 대화 한 줄 (시트 행).
class ScenarioLine {
  final String scenarioId;
  final String title;
  final int order;
  final String speaker;
  final String textKo;
  final String textTarget;
  final String pronunciation;
  final String blankFrame;
  final String flightStage;
  final String level;
  final String language;
  final int chapterNo;
  final String chapterName;
  final String chapterImage;
  final bool isNewContent;

  const ScenarioLine({
    required this.scenarioId,
    this.title = '',
    required this.order,
    required this.speaker,
    required this.textKo,
    required this.textTarget,
    this.pronunciation = '',
    this.blankFrame = '',
    this.flightStage = '',
    this.level = '',
    required this.language,
    this.chapterNo = 1,
    this.chapterName = '',
    this.chapterImage = '',
    this.isNewContent = false,
  });

  bool get isPassenger =>
      speaker.toLowerCase() == 'passenger' || speaker == '승객';

  bool get isCrew => speaker.toLowerCase() == 'crew' || speaker == '승무원';

  factory ScenarioLine.fromJson(Map<String, dynamic> json) {
    return ScenarioLine(
      scenarioId: json['scenario_id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      order: int.tryParse(json['order']?.toString() ?? '') ?? 0,
      speaker: json['speaker']?.toString() ?? '',
      textKo: json['text_ko']?.toString() ?? '',
      textTarget: json['text_target']?.toString() ?? '',
      pronunciation: json['pronunciation']?.toString() ?? '',
      blankFrame: json['blank_frame']?.toString() ?? '',
      flightStage: json['flight_stage']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      language: json['language']?.toString() ?? 'English',
      chapterNo: int.tryParse(json['chapter_no']?.toString() ?? '') ?? 1,
      chapterName: json['chapter_name']?.toString().trim() ?? '',
      chapterImage: resolveChapterAssetPath(
        json['chapter_image']?.toString() ?? '',
      ),
      isNewContent: _parseNewFlag(json['new']),
    );
  }

  static bool _parseNewFlag(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        if (title.isNotEmpty) 'title': title,
        'order': order,
        'speaker': speaker,
        'text_ko': textKo,
        'text_target': textTarget,
        'pronunciation': pronunciation,
        'blank_frame': blankFrame,
        'flight_stage': flightStage,
        'level': level,
        'language': language,
        'chapter_no': chapterNo,
        if (chapterName.isNotEmpty) 'chapter_name': chapterName,
        if (chapterImage.isNotEmpty) 'chapter_image': chapterImage,
        if (isNewContent) 'new': true,
      };
}
