import 'scenario.dart';
import 'scenario_line.dart';
import 'sentence.dart';
import 'vocabulary_entry.dart';

/// 동기화된 전체 콘텐츠. 앱 시작 시 로컬 저장소에서 읽어 메모리에 올린다.
class ContentBundle {
  final List<Sentence> sentences;
  final List<String> categoryOrder;
  final List<VocabularyEntry> words;
  final List<ScenarioLine> scenarioLines;

  const ContentBundle({
    required this.sentences,
    required this.categoryOrder,
    this.words = const [],
    this.scenarioLines = const [],
  });

  static const empty = ContentBundle(sentences: [], categoryOrder: []);

  /// 시나리오 ID 단위로 그룹화된 목록.
  List<Scenario> get scenarios => Scenario.groupLines(scenarioLines);

  List<Scenario> scenariosFor(String language) =>
      scenarios.where((s) => s.language == language).toList();

  bool get isEmpty => sentences.isEmpty;

  /// 시트 등장 순서를 유지한 언어 목록.
  List<String> get languages {
    final seen = <String>{};
    return [
      for (final s in sentences)
        if (seen.add(s.language)) s.language,
    ];
  }

  /// 해당 언어에 데이터가 있는 카테고리를 시트 순서대로 반환.
  List<String> categoriesFor(String language) {
    final present = sentences
        .where((s) => s.language == language)
        .map((s) => s.category)
        .toSet();
    return categoryOrder.where(present.contains).toList();
  }

  List<Sentence> sentencesFor(String language, String category) {
    return sentences
        .where((s) => s.language == language && s.category == category)
        .toList();
  }

  /// 해당 언어에 단어가 있는 카테고리를 시트 순서대로 반환.
  List<String> categoriesForWords(String language) {
    final present = words
        .where((w) => w.language == language)
        .map((w) => w.category)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet();
    final ordered = categoryOrder.where(present.contains).toList();
    // categoryOrder에 없는 카테고리도 뒤에 붙인다.
    for (final c in present) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  /// 언어·카테고리로 단어 필터.
  List<VocabularyEntry> wordsFor(String language, String category) {
    return words
        .where((w) =>
            w.language == language &&
            (w.category ?? '') == category &&
            w.term.trim().isNotEmpty)
        .toList();
  }

  /// [currentCategory] 다음 단어 카테고리. 없으면 null.
  String? nextWordCategory(String language, String currentCategory) {
    final cats = categoriesForWords(language);
    final i = cats.indexOf(currentCategory);
    if (i < 0 || i + 1 >= cats.length) return null;
    return cats[i + 1];
  }

  /// 문장·발음·한국어 대상 부분 일치 검색 (기존 웹과 동일한 규칙).
  List<Sentence> search(String query, {String? language}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return sentences.where((s) {
      if (language != null && language != 'All' && s.language != language) {
        return false;
      }
      return s.sentence.toLowerCase().contains(q) ||
          s.pronunciation.toLowerCase().contains(q) ||
          s.korean.toLowerCase().contains(q);
    }).toList();
  }

  /// Words 시트 — 단어·뜻·발음·설명 대상 부분 일치 검색.
  List<VocabularyEntry> searchWords(String query, {String? language}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return words.where((w) {
      if (language != null && language != 'All' && w.language != language) {
        return false;
      }
      if (w.term.trim().isEmpty) return false;
      return w.term.toLowerCase().contains(q) ||
          w.meaning.toLowerCase().contains(q) ||
          (w.pronunciation ?? '').toLowerCase().contains(q) ||
          (w.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Apps Script getData() 응답 형태(JSON)에서 파싱.
  factory ContentBundle.fromJson(Map<String, dynamic> json) {
    final all = (json['allSentences'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Sentence.fromJson)
        .where((s) => s.sentence.isNotEmpty)
        .toList();
    final order = (json['categoryOrder'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final words = (json['allWords'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VocabularyEntry.fromJson)
        .where((w) => w.term.isNotEmpty)
        .toList();
    final scenarioLines = _parseScenarioLines(json);
    return ContentBundle(
      sentences: all,
      categoryOrder: order,
      words: words,
      scenarioLines: scenarioLines,
    );
  }

  static List<ScenarioLine> _parseScenarioLines(Map<String, dynamic> json) {
    final combined = <ScenarioLine>[];

    void addFromList(List? raw, String language) {
      if (raw == null) return;
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final line = ScenarioLine.fromJson({...item, 'language': language});
        if (line.scenarioId.isNotEmpty &&
            line.textTarget.isNotEmpty &&
            !Scenario.isSheetHeaderToken(line.scenarioId)) {
          combined.add(line);
        }
      }
    }

    addFromList(json['scenariosEn'] as List?, 'English');
    addFromList(json['scenariosJp'] as List?, 'Japanese');
    addFromList(json['scenariosCn'] as List?, 'Chinese');

    // 레거시 단일 배열 형식
    addFromList(json['scenarios'] as List?, '');

    return combined;
  }

  Map<String, dynamic> toJson() => {
        'allSentences': sentences.map((s) => s.toJson()).toList(),
        'categoryOrder': categoryOrder,
        'allWords': words.map((w) => w.toJson()).toList(),
        'scenariosEn': scenarioLines
            .where((l) => l.language == 'English')
            .map((l) => l.toJson())
            .toList(),
        'scenariosJp': scenarioLines
            .where((l) => l.language == 'Japanese')
            .map((l) => l.toJson())
            .toList(),
        'scenariosCn': scenarioLines
            .where((l) => l.language == 'Chinese')
            .map((l) => l.toJson())
            .toList(),
      };
}
