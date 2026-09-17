import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/learning_hub_icon.dart';
import '../data/models/content_bundle.dart';
import '../data/models/scenario.dart';
import 'learning_hub_language_provider.dart';
import 'providers.dart';

/// 홈 NEW UPDATE 카드에 표시할 신규 시나리오 목록.
class NewUpdateScenarioSnapshot {
  final List<Scenario> scenarios;

  const NewUpdateScenarioSnapshot({this.scenarios = const []});

  bool get hasUpdates => scenarios.isNotEmpty;

  int get count => scenarios.length;
}

/// 홈 상단 언어 스위치(`learningHubLanguageProvider`)와 동기화되어,
/// 현재 선택된 언어의 신규 시나리오만 노출한다.
final newUpdateScenarioProvider = Provider<NewUpdateScenarioSnapshot>((ref) {
  final content = ref.watch(contentProvider).value;
  final language = ref.watch(learningHubLanguageProvider);
  if (content == null || content.bundle.isEmpty) {
    return const NewUpdateScenarioSnapshot();
  }

  final newScenarios = content.bundle.scenarios
      .where((s) =>
          s.isNewContent && !s.isSheetHeaderRow && s.language == language)
      .toList();

  if (newScenarios.isEmpty) {
    return const NewUpdateScenarioSnapshot();
  }

  newScenarios.sort((a, b) {
    final byChapter = a.chapterNo.compareTo(b.chapterNo);
    if (byChapter != 0) return byChapter;
    return a.id.compareTo(b.id);
  });

  return NewUpdateScenarioSnapshot(scenarios: newScenarios);
});

String scenarioLanguageShortTag(String language) => switch (language) {
      'Japanese' => 'JP',
      'Chinese' => 'CN',
      _ => 'EN',
    };

String scenarioLevelLabel(String level) {
  final trimmed = level.trim();
  if (trimmed.isEmpty) return '일반';
  return trimmed;
}

/// NEW UPDATE · 시나리오 목록용 메타 한 줄.
String scenarioMetaLine(Scenario scenario, {int additionalCount = 0}) {
  final parts = <String>[];
  final level = scenario.level.trim();
  if (level.isNotEmpty) parts.add(level);
  if (scenario.lines.isNotEmpty) {
    parts.add('${scenario.lines.length}문장');
  }
  var line = parts.join(' · ');
  if (additionalCount > 0) {
    line = '$line · 외 $additionalCount개 더보기';
  }
  return line;
}

/// NEW UPDATE 서브카드 — sentences 시트 기준 챕터명.
String newUpdateChapterLabel(ContentBundle bundle, Scenario scenario) {
  final hub = bundle.hubChapterForScenario(scenario);
  final name = hub?.name ?? ContentBundle.scenarioHubCategoryName(scenario);
  if (name.isEmpty) return 'Chapter ${scenario.chapterNo}';
  return 'Chapter ${scenario.chapterNo}. $name';
}

/// NEW UPDATE 서브카드 — 짧은 챕터 라벨 (2줄 wrap용).
String newUpdateChapterShortLabel(ContentBundle bundle, Scenario scenario) {
  final hub = bundle.hubChapterForScenario(scenario);
  final name = hub?.name ?? ContentBundle.scenarioHubCategoryName(scenario);
  if (name.isEmpty) return 'Ch.${scenario.chapterNo}';
  return 'Ch.${scenario.chapterNo} · $name';
}

/// NEW UPDATE 서브카드 — sentences 시트 [chapter_image] 우선 썸네일 경로.
String newUpdateChapterImageAsset(ContentBundle bundle, Scenario scenario) {
  final hub = bundle.hubChapterForScenario(scenario);
  final chapterImage = hub?.chapterImage ?? scenario.chapterImage;
  final category =
      hub?.name ?? ContentBundle.scenarioHubCategoryName(scenario);
  return resolveHubChapterIcon(
    chapterImage: chapterImage,
    category: category,
  );
}
