import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/learning_hub_icon.dart';
import '../data/models/content_bundle.dart';
import '../data/models/new_sentence_group.dart';
import '../data/models/scenario.dart';
import 'learning_hub_language_provider.dart';
import 'providers.dart';

/// 홈 NEW UPDATE 카드 한 칸 — 신규 시나리오 또는 신규 문장 그룹.
sealed class NewUpdateEntry {
  const NewUpdateEntry();

  int get chapterNo;
  String get key;
}

class NewUpdateScenarioEntry extends NewUpdateEntry {
  final Scenario scenario;

  const NewUpdateScenarioEntry(this.scenario);

  @override
  int get chapterNo => scenario.chapterNo;

  @override
  String get key => 'scenario:${scenario.id}';
}

class NewUpdateSentenceEntry extends NewUpdateEntry {
  final NewSentenceGroup group;

  const NewUpdateSentenceEntry(this.group);

  @override
  int get chapterNo => group.chapterNo;

  @override
  String get key => 'sentence:${group.language}|${group.fullCategory}';
}

/// 홈 NEW UPDATE 카드에 표시할 신규 시나리오·문장 그룹 목록.
class NewUpdateScenarioSnapshot {
  final List<NewUpdateEntry> entries;

  const NewUpdateScenarioSnapshot({this.entries = const []});

  bool get hasUpdates => entries.isNotEmpty;

  int get count => entries.length;
}

/// 홈 상단 언어 스위치(`learningHubLanguageProvider`)와 동기화되어,
/// 현재 선택된 언어의 신규 시나리오·문장 그룹만 노출한다.
final newUpdateScenarioProvider = Provider<NewUpdateScenarioSnapshot>((ref) {
  final content = ref.watch(contentProvider).value;
  final language = ref.watch(learningHubLanguageProvider);
  if (content == null || content.bundle.isEmpty) {
    return const NewUpdateScenarioSnapshot();
  }

  final newScenarios = content.bundle.scenarios
      .where((s) =>
          s.isNewContent && !s.isSheetHeaderRow && s.language == language)
      .toList()
    ..sort((a, b) {
      final byChapter = a.chapterNo.compareTo(b.chapterNo);
      if (byChapter != 0) return byChapter;
      return a.id.compareTo(b.id);
    });
  final newSentenceGroups = content.bundle.newSentenceGroupsFor(language);

  final entries = <NewUpdateEntry>[
    for (final g in newSentenceGroups) NewUpdateSentenceEntry(g),
    for (final s in newScenarios) NewUpdateScenarioEntry(s),
  ];
  if (entries.isEmpty) return const NewUpdateScenarioSnapshot();

  // 같은 챕터 안에서는 문장 → 시나리오, 그 외에는 위 목록 순서를 유지한다.
  final order = {for (var i = 0; i < entries.length; i++) entries[i]: i};
  entries.sort((a, b) {
    final byChapter = a.chapterNo.compareTo(b.chapterNo);
    if (byChapter != 0) return byChapter;
    return order[a]!.compareTo(order[b]!);
  });

  return NewUpdateScenarioSnapshot(entries: entries);
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

/// NEW UPDATE 서브카드 — 문장 그룹 챕터 라벨.
String newUpdateSentenceChapterShortLabel(NewSentenceGroup group) {
  if (group.baseName.isEmpty) return 'Ch.${group.chapterNo}';
  return 'Ch.${group.chapterNo} · ${group.baseName}';
}

String newUpdateSentenceImageAsset(NewSentenceGroup group) {
  return resolveHubChapterIcon(
    chapterImage: group.chapterImage,
    category: group.baseName,
  );
}

/// NEW UPDATE 서브카드 썸네일 경로.
String newUpdateEntryImageAsset(ContentBundle bundle, NewUpdateEntry entry) {
  return switch (entry) {
    NewUpdateScenarioEntry(:final scenario) =>
      newUpdateChapterImageAsset(bundle, scenario),
    NewUpdateSentenceEntry(:final group) => newUpdateSentenceImageAsset(group),
  };
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
