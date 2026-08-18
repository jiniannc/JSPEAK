import 'scenario.dart';
import 'scenario_line.dart';
import 'sentence.dart';
import 'vocabulary_entry.dart';
import 'content_chapter.dart';
import 'learning_hub_chapter.dart';
import '../../core/utils/search_text_match.dart';

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

  /// 해당 언어에 데이터가 있는 카테고리를 [chapter_no] 순으로 반환.
  List<String> categoriesFor(String language) {
    final chapterByCategory = _chapterNumbersForSentences(language);
    final categories = chapterByCategory.keys.toList()
      ..sort(
        (a, b) => _compareCategories(a, b, chapterByCategory),
      );
    return categories;
  }

  List<Sentence> sentencesFor(String language, String category) {
    return sentences
        .where((s) => s.language == language && s.category == category)
        .toList();
  }

  /// 언어별 문장 챕터 메타 ([chapter_no] 순).
  List<ContentChapter> sentenceChaptersFor(String language) {
    final chapters = [
      for (final category in categoriesFor(language))
        chapterForSentenceCategory(language, category),
    ]..sort((a, b) => _compareChapters(a, b));
    return chapters;
  }

  ContentChapter chapterForSentenceCategory(String language, String category) {
    final rows = sentencesFor(language, category);
    if (rows.isEmpty) {
      return ContentChapter(chapterNo: 1, name: category, language: language);
    }
    final chapterNo = rows
        .map((row) => row.chapterNo)
        .reduce((a, b) => a < b ? a : b);
    final imageRow = rows.firstWhere(
      (row) => row.chapterImage.isNotEmpty,
      orElse: () => rows.first,
    );
    return ContentChapter(
      chapterNo: chapterNo,
      name: category,
      chapterImage: imageRow.chapterImage,
      language: language,
    );
  }

  /// 해당 언어에 단어가 있는 카테고리를 [chapter_no] 순으로 반환.
  List<String> categoriesForWords(String language) {
    final chapterByCategory = _chapterNumbersForWords(language);
    final categories = chapterByCategory.keys.toList()
      ..sort(
        (a, b) => _compareCategories(a, b, chapterByCategory),
      );
    return categories;
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

  /// 언어별 단어 챕터 메타 ([chapter_no] 순).
  List<ContentChapter> wordChaptersFor(String language) {
    final chapters = [
      for (final category in categoriesForWords(language))
        chapterForWordCategory(language, category),
    ]..sort((a, b) => _compareChapters(a, b));
    return chapters;
  }

  ContentChapter chapterForWordCategory(String language, String category) {
    final rows = wordsFor(language, category);
    if (rows.isEmpty) {
      return ContentChapter(chapterNo: 1, name: category, language: language);
    }
    final chapterNo = rows
        .map((row) => row.chapterNo)
        .reduce((a, b) => a < b ? a : b);
    final imageRow = rows.firstWhere(
      (row) => (row.chapterImage ?? '').isNotEmpty,
      orElse: () => rows.first,
    );
    return ContentChapter(
      chapterNo: chapterNo,
      name: category,
      chapterImage: imageRow.chapterImage ?? '',
      language: language,
    );
  }

  /// 학습 허브 — 비행 단계별 통합 챕터 ([chapter_no] 순).
  List<LearningHubChapter> learningHubChaptersFor(String language) {
    final merged = <String, LearningHubChapter>{};

    void note({
      required int chapterNo,
      required String name,
      String hook = '',
      String chapterImage = '',
    }) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      final key = '$chapterNo|$trimmed';
      final existing = merged[key];
      if (existing == null) {
        merged[key] = LearningHubChapter(
          chapterNo: chapterNo,
          name: trimmed,
          language: language,
          hook: hook,
          chapterImage: chapterImage,
        );
        return;
      }
      merged[key] = LearningHubChapter(
        chapterNo: existing.chapterNo,
        name: existing.name,
        language: language,
        hook: existing.hook.isNotEmpty ? existing.hook : hook,
        chapterImage: existing.chapterImage.isNotEmpty
            ? existing.chapterImage
            : chapterImage,
      );
    }

    for (final sentence in sentences) {
      if (sentence.language != language) continue;
      note(
        chapterNo: sentence.chapterNo,
        name: sentence.category,
        hook: sentence.chapterHook,
        chapterImage: sentence.chapterImage,
      );
    }

    for (final word in words) {
      if (word.language != language) continue;
      final category = word.category?.trim() ?? '';
      if (category.isEmpty) continue;
      note(
        chapterNo: word.chapterNo,
        name: category,
        chapterImage: word.chapterImage ?? '',
      );
    }

    for (final scenario in scenariosFor(language)) {
      final name = scenario.chapterName.trim().isNotEmpty
          ? scenario.chapterName.trim()
          : scenario.flightStage.trim();
      if (name.isEmpty) continue;
      note(
        chapterNo: scenario.chapterNo,
        name: name,
        chapterImage: scenario.chapterImage,
      );
    }

    for (final category in categoriesFor(language)) {
      final hook = chapterHookFor(language, category);
      final meta = chapterForSentenceCategory(language, category);
      if (hook.isEmpty && meta.chapterImage.isEmpty) continue;
      note(
        chapterNo: meta.chapterNo,
        name: category,
        hook: hook,
        chapterImage: meta.chapterImage,
      );
    }

    final chapters = merged.values.toList()
      ..sort((a, b) {
        final byNo = a.chapterNo.compareTo(b.chapterNo);
        if (byNo != 0) return byNo;
        return a.name.compareTo(b.name);
      });
    return chapters;
  }

  /// 챕터 카드용 hook — 카테고리 첫 non-empty [chapter_hook].
  String chapterHookFor(String language, String category) {
    for (final sentence in sentences) {
      if (sentence.language != language) continue;
      if (sentence.category != category) continue;
      if (sentence.chapterHook.trim().isNotEmpty) {
        return sentence.chapterHook.trim();
      }
    }
    return '';
  }

  /// 학습 허브 챕터에 속하는 시나리오 (chapter_no · 이름 · flight_stage 매칭).
  List<Scenario> scenariosForHubChapter(
    String language,
    LearningHubChapter chapter,
  ) {
    final name = chapter.name;
    return scenariosFor(language)
        .where((scenario) {
          if (scenario.isSheetHeaderRow) return false;
          if (scenario.chapterNo == chapter.chapterNo) return true;
          if (scenario.chapterName.trim() == name) return true;
          if (scenario.flightStage.trim() == name) return true;
          return false;
        })
        .toList();
  }

  /// [currentCategory] 다음 단어 카테고리. 없으면 null.
  String? nextWordCategory(String language, String currentCategory) {
    final cats = categoriesForWords(language);
    final i = cats.indexOf(currentCategory);
    if (i < 0 || i + 1 >= cats.length) return null;
    return cats[i + 1];
  }

  int _compareCategories(
    String a,
    String b,
    Map<String, int> chapterByCategory,
  ) {
    final chapterA = chapterByCategory[a] ?? 999999;
    final chapterB = chapterByCategory[b] ?? 999999;
    final byChapter = chapterA.compareTo(chapterB);
    if (byChapter != 0) return byChapter;

    final indexA = categoryOrder.indexOf(a);
    final indexB = categoryOrder.indexOf(b);
    if (indexA >= 0 && indexB >= 0 && indexA != indexB) {
      return indexA.compareTo(indexB);
    }
    if (indexA >= 0 && indexB < 0) return -1;
    if (indexA < 0 && indexB >= 0) return 1;
    return a.compareTo(b);
  }

  int _compareChapters(ContentChapter a, ContentChapter b) {
    final byChapter = a.chapterNo.compareTo(b.chapterNo);
    if (byChapter != 0) return byChapter;
    return a.name.compareTo(b.name);
  }

  Map<String, int> _chapterNumbersForSentences(String language) {
    final chapterByCategory = <String, int>{};
    for (final sentence in sentences) {
      if (sentence.language != language) continue;
      _noteChapterNumber(
        chapterByCategory,
        sentence.category,
        sentence.chapterNo,
      );
    }
    return chapterByCategory;
  }

  Map<String, int> _chapterNumbersForWords(String language) {
    final chapterByCategory = <String, int>{};
    for (final word in words) {
      if (word.language != language) continue;
      final category = word.category?.trim() ?? '';
      if (category.isEmpty) continue;
      _noteChapterNumber(chapterByCategory, category, word.chapterNo);
    }
    return chapterByCategory;
  }

  void _noteChapterNumber(
    Map<String, int> chapterByCategory,
    String category,
    int chapterNo,
  ) {
    final safeNo = chapterNo <= 0 ? 1 : chapterNo;
    final existing = chapterByCategory[category];
    if (existing == null || safeNo < existing) {
      chapterByCategory[category] = safeNo;
    }
  }

  /// 문장·발음·한국어 대상 부분 일치 검색 (공백 무시).
  List<Sentence> search(String query, {String? language}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return sentences.where((s) {
      if (language != null && language != 'All' && s.language != language) {
        return false;
      }
      return SearchTextMatch.sentenceFieldMatches(s.sentence, q) ||
          SearchTextMatch.sentenceFieldMatches(s.pronunciation, q) ||
          SearchTextMatch.sentenceFieldMatches(s.korean, q);
    }).toList();
  }

  /// Words 시트 — 단어·뜻·발음·동의어 우선, 설명은 보조 검색.
  List<VocabularyEntry> searchWords(String query, {String? language}) {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final primary = <VocabularyEntry>[];
    final secondary = <VocabularyEntry>[];

    for (final w in words) {
      if (language != null && language != 'All' && w.language != language) {
        continue;
      }
      if (w.term.trim().isEmpty) continue;

      switch (SearchTextMatch.vocabularyMatchTier(w, q)) {
        case SearchMatchTier.primary:
          primary.add(w);
        case SearchMatchTier.secondary:
          secondary.add(w);
        case SearchMatchTier.none:
          break;
      }
    }

    return [...primary, ...secondary];
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
