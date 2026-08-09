import 'scenario.dart';

/// chapter_no 기준으로 묶인 시나리오 커리큘럼 단위.
class ScenarioChapter {
  final int chapterNo;
  final String chapterName;
  final String chapterImage;
  final List<Scenario> scenarios;

  const ScenarioChapter({
    required this.chapterNo,
    required this.chapterName,
    required this.chapterImage,
    required this.scenarios,
  });

  /// 하위 시나리오 중 하나라도 신규이면 챕터 NEW 표시.
  bool get hasNewContent => scenarios.any((s) => s.isNewContent);

  /// `chapter_no` → 시나리오 목록.
  static Map<int, List<Scenario>> groupByChapterNo(List<Scenario> scenarios) {
    final grouped = <int, List<Scenario>>{};
    for (final scenario in scenarios) {
      grouped.putIfAbsent(scenario.chapterNo, () => []).add(scenario);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.id.compareTo(b.id));
    }
    return grouped;
  }

  /// 챕터 번호 오름차순 리스트.
  static List<ScenarioChapter> fromScenarios(List<Scenario> scenarios) {
    if (scenarios.isEmpty) return [];

    final grouped = groupByChapterNo(scenarios);
    final chapterNos = grouped.keys.toList()..sort();

    return [
      for (final chapterNo in chapterNos)
        ScenarioChapter(
          chapterNo: chapterNo,
          chapterName: _chapterNameFor(grouped[chapterNo]!),
          chapterImage: _chapterImageFor(grouped[chapterNo]!),
          scenarios: grouped[chapterNo]!,
        ),
    ];
  }

  static String _chapterNameFor(List<Scenario> scenarios) {
    for (final s in scenarios) {
      if (s.chapterName.trim().isNotEmpty) return s.chapterName.trim();
    }
    for (final s in scenarios) {
      if (s.flightStage.trim().isNotEmpty) return s.flightStage.trim();
    }
    return '시나리오';
  }

  static String _chapterImageFor(List<Scenario> scenarios) {
    for (final s in scenarios) {
      if (s.chapterImage.trim().isNotEmpty) return s.chapterImage.trim();
    }
    return '';
  }
}
