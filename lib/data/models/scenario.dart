import 'scenario_line.dart';

/// scenario_id로 묶인 대화 시나리오.
class Scenario {
  /// 시트 헤더 행이 데이터로 파싱되는 것을 방지하기 위한 컬럼명 집합.
  static const _sheetHeaderKeys = {
    'scenario_id',
    'title',
    'flight_stage',
    'text_ko',
    'text_target',
    'speaker',
    'order',
    'level',
    'language',
    'pronunciation',
    'blank_frame',
    'chapter_no',
    'chapter_name',
    'chapter_image',
    'avatar_image',
    'audio',
    'audio_start',
    'audio_end',
    'new',
  };

  final String id;
  final String language;
  /// order 1 행의 title 컬럼 (없으면 flightStage → id 순 fallback).
  final String title;
  final String flightStage;
  final String level;
  final int chapterNo;
  final String chapterName;
  final String chapterImage;
  final bool isNewContent;
  final List<ScenarioLine> lines;

  const Scenario({
    required this.id,
    required this.language,
    required this.title,
    required this.flightStage,
    required this.level,
    this.chapterNo = 1,
    this.chapterName = '',
    this.chapterImage = '',
    this.isNewContent = false,
    required this.lines,
  });

  /// 엑셀/시트 헤더 행이 시나리오로 잘못 그룹화되었는지 판별.
  bool get isSheetHeaderRow {
    final idKey = id.trim().toLowerCase();
    final titleKey = title.trim().toLowerCase();
    return _sheetHeaderKeys.contains(idKey) ||
        _sheetHeaderKeys.contains(titleKey);
  }

  static bool isSheetHeaderToken(String value) =>
      _sheetHeaderKeys.contains(value.trim().toLowerCase());

  static String _firstAvatarFromLines(List<ScenarioLine> lines) {
    for (final line in lines) {
      if (line.avatarImage.isNotEmpty) return line.avatarImage;
    }
    return '';
  }

  /// order 1 행 title 우선, 없으면 첫 비어 있지 않은 title.
  static String titleFromLines(List<ScenarioLine> lines) {
    for (final line in lines) {
      if (line.order == 1 && line.title.trim().isNotEmpty) {
        return line.title.trim();
      }
    }
    for (final line in lines) {
      if (line.title.trim().isNotEmpty) return line.title.trim();
    }
    return '';
  }

  /// 시나리오 대표 설명 (첫 승객 대사 한국어 또는 첫 줄).
  String get subtitle {
    for (final line in lines) {
      if (line.isPassenger && line.textKo.isNotEmpty) return line.textKo;
    }
    return lines.isNotEmpty ? lines.first.textKo : '';
  }

  /// order 1 행 메타 (챕터·신규 플래그 포함).
  static ScenarioLine metaLineFrom(List<ScenarioLine> lines) {
    for (final line in lines) {
      if (line.order == 1) return line;
    }
    return lines.first;
  }

  /// 시트 행 목록을 시나리오 단위로 그룹화.
  static List<Scenario> groupLines(List<ScenarioLine> lines) {
    final byId = <String, List<ScenarioLine>>{};
    for (final line in lines) {
      if (line.scenarioId.isEmpty) continue;
      byId.putIfAbsent(line.scenarioId, () => []).add(line);
    }

    final scenarios = <Scenario>[];
    for (final entry in byId.entries) {
      if (isSheetHeaderToken(entry.key)) continue;

      final sorted = List<ScenarioLine>.from(entry.value)
        ..sort((a, b) => a.order.compareTo(b.order));
      if (sorted.isEmpty) continue;

      final meta = metaLineFrom(sorted);
      final sheetTitle = titleFromLines(sorted);
      final scenario = Scenario(
        id: entry.key,
        language: meta.language,
        title: sheetTitle.isNotEmpty
            ? sheetTitle
            : (meta.flightStage.isNotEmpty ? meta.flightStage : entry.key),
        flightStage: meta.flightStage,
        level: meta.level,
        chapterNo: meta.chapterNo,
        chapterName: meta.chapterName,
        chapterImage: meta.chapterImage.isNotEmpty
            ? meta.chapterImage
            : _firstAvatarFromLines(sorted),
        isNewContent: sorted.any((line) => line.isNewContent),
        lines: sorted,
      );
      if (scenario.isSheetHeaderRow) continue;

      scenarios.add(scenario);
    }

    scenarios.sort((a, b) {
      final chapter = a.chapterNo.compareTo(b.chapterNo);
      if (chapter != 0) return chapter;
      return a.id.compareTo(b.id);
    });
    return scenarios;
  }
}
