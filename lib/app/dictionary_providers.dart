import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/sentence.dart';
import 'providers.dart';
import 'search_providers.dart';

/// 기내 사전 뷰 모드.
enum DictionaryViewMode { list, wheel }

/// 지원 언어 탭 순서.
const kDictionaryLanguages = ['English', 'Japanese', 'Chinese'];

class DictionaryViewModeController extends Notifier<DictionaryViewMode> {
  @override
  DictionaryViewMode build() => DictionaryViewMode.list;

  void set(DictionaryViewMode mode) => state = mode;
}

final dictionaryViewModeProvider =
    NotifierProvider<DictionaryViewModeController, DictionaryViewMode>(
  DictionaryViewModeController.new,
);

class SelectedLanguageController extends Notifier<String> {
  @override
  String build() => 'English';

  void set(String language) => state = language;
}

final selectedLanguageProvider =
    NotifierProvider<SelectedLanguageController, String>(
  SelectedLanguageController.new,
);

class SelectedCategoryController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String?>(
  SelectedCategoryController.new,
);

/// 콘텐츠와 동기화된 유효 카테고리 (없으면 첫 항목).
final effectiveCategoryProvider = Provider<String?>((ref) {
  final language = ref.watch(selectedLanguageProvider);
  final selected = ref.watch(selectedCategoryProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null) return selected;

  final categories = content.bundle.categoriesFor(language);
  if (categories.isEmpty) return null;
  if (selected != null && categories.contains(selected)) return selected;
  return categories.first;
});

/// 현재 언어의 카테고리 목록.
final dictionaryCategoriesProvider = Provider<List<String>>((ref) {
  final language = ref.watch(selectedLanguageProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null) return [];
  return content.bundle.categoriesFor(language);
});

/// 현재 선택 언어·카테고리의 문장 목록.
final dictionarySentencesProvider = Provider<List<Sentence>>((ref) {
  final language = ref.watch(selectedLanguageProvider);
  final category = ref.watch(effectiveCategoryProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null || category == null) return [];
  return content.bundle.sentencesFor(language, category);
});

/// 언어 변경 시 카테고리를 첫 항목으로 리셋.
void selectDictionaryLanguage(WidgetRef ref, String language) {
  ref.read(selectedLanguageProvider.notifier).set(language);
  ref.read(selectedCategoryProvider.notifier).set(null);
}

void selectDictionaryCategory(WidgetRef ref, String category) {
  ref.read(selectedCategoryProvider.notifier).set(category);
}

/// 헤더 탭 시 기내사전 홈 히어로(검색 전) 상태로 되돌릴 때 사용.
class DictionaryHomeResetSignal extends Notifier<int> {
  @override
  int build() => 0;

  void reset() => state++;
}

final dictionaryHomeResetProvider =
    NotifierProvider<DictionaryHomeResetSignal, int>(
  DictionaryHomeResetSignal.new,
);

void resetDictionaryHome(WidgetRef ref) {
  ref.read(searchProvider.notifier).setQuery('');
  ref.read(dictionaryHomeResetProvider.notifier).reset();
}

/// 즐겨찾기 칩 탭 등 외부에서 검색어를 주입할 때 사용.
class DictionarySearchJumpController extends Notifier<String?> {
  @override
  String? build() => null;

  void apply(String query) => state = query.trim();

  void clear() => state = null;
}

final dictionarySearchJumpProvider =
    NotifierProvider<DictionarySearchJumpController, String?>(
  DictionarySearchJumpController.new,
);
