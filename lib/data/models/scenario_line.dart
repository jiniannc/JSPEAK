import '../../core/utils/avatar_asset_path.dart';
import '../../core/utils/chapter_asset_path.dart';
import 'sentence.dart';

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
  /// 챕터 썸네일(레거시·메타). 시나리오 시트 D열은 [avatarImage]로 대체됨.
  final String chapterImage;
  /// 말풍선 좌상단 캐릭터 (`avatar_normal` → assets/images/avatar_normal.png).
  final String avatarImage;
  /// 승무원 대사 녹음 (Drive ID 또는 URL). 없으면 문장 사전 audio로 매칭.
  final String audioUrl;
  /// 녹음 파일에서 가라오케 시작 시각(초). 없으면 자동 추정.
  final double? audioStartSec;
  /// 녹음 파일에서 가라오케 종료 시각(초). 없으면 파일 끝까지.
  final double? audioEndSec;
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
    this.avatarImage = '',
    this.audioUrl = '',
    this.audioStartSec,
    this.audioEndSec,
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
      avatarImage: resolveAvatarAssetPath(
        json['avatar_image']?.toString() ?? '',
      ),
      audioUrl: Sentence.resolveAudioUrl(json['audio']?.toString() ?? ''),
      audioStartSec: _parseOptionalDouble(json['audio_start']),
      audioEndSec: _parseOptionalDouble(json['audio_end']),
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

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
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
        if (avatarImage.isNotEmpty) 'avatar_image': avatarImage,
        if (audioUrl.isNotEmpty) 'audio': audioUrl,
        if (audioStartSec != null) 'audio_start': audioStartSec,
        if (audioEndSec != null) 'audio_end': audioEndSec,
        if (isNewContent) 'new': true,
      };
}
