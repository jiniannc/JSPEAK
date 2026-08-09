import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/scenario.dart';
import 'learning_hub_language_provider.dart';
import 'providers.dart';

/// 홈 NEW UPDATE 카드에 표시할 신규 시나리오 스냅샷.
class NewUpdateScenarioSnapshot {
  final Scenario? featured;
  final int totalNewCount;

  const NewUpdateScenarioSnapshot({
    this.featured,
    this.totalNewCount = 0,
  });

  bool get hasUpdates => featured != null && totalNewCount > 0;

  int get additionalCount =>
      totalNewCount > 1 ? totalNewCount - 1 : 0;
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
    final byChapter = b.chapterNo.compareTo(a.chapterNo);
    if (byChapter != 0) return byChapter;
    return b.id.compareTo(a.id);
  });

  return NewUpdateScenarioSnapshot(
    featured: newScenarios.first,
    totalNewCount: newScenarios.length,
  );
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

String scenarioMetaLine(Scenario scenario, {int additionalCount = 0}) {
  final level = scenarioLevelLabel(scenario.level);
  final lineCount = scenario.lines.length;
  final base = '$level · ${lineCount}문장';
  if (additionalCount <= 0) return base;
  return '$base · 외 $additionalCount개 더보기';
}
