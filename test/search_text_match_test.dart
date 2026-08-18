import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/search_text_match.dart';
import 'package:jspeak/data/models/content_bundle.dart';
import 'package:jspeak/data/models/vocabulary_entry.dart';

void main() {
  group('SearchTextMatch', () {
    test('공백 없는 검색어가 공백 있는 뜻과 매칭된다', () {
      expect(
        SearchTextMatch.containsNormalized('보조 배터리', '보조배터리'),
        isTrue,
      );
      expect(
        SearchTextMatch.containsNormalized('portable charger', 'portablecharger'),
        isTrue,
      );
    });

    test('짧은 한글 검색어는 description-only 매칭을 허용하지 않는다', () {
      const entry = VocabularyEntry(
        term: 'return flight',
        meaning: '돌아오는 비행편',
        description: '인도 관련 안내 문구',
      );
      expect(
        SearchTextMatch.vocabularyMatchTier(entry, '인도'),
        SearchMatchTier.none,
      );
    });

    test('짧은 한글 검색어는 뜻·동의어 필드에서는 매칭된다', () {
      const handOver = VocabularyEntry(
        term: 'hand over',
        meaning: '인도하다, 인계하다',
      );
      expect(
        SearchTextMatch.vocabularyMatchTier(handOver, '인도'),
        SearchMatchTier.primary,
      );
    });
  });

  group('ContentBundle.searchWords', () {
    final bundle = ContentBundle(
      sentences: const [],
      categoryOrder: const [],
      words: const [
        VocabularyEntry(
          term: 'return flight',
          meaning: '돌아오는 비행편',
          description: '인도 관련 예시 문장',
          language: 'English',
        ),
        VocabularyEntry(
          term: 'hand over',
          meaning: '인도하다, 인계하다',
          language: 'English',
        ),
        VocabularyEntry(
          term: 'portable charger',
          meaning: '보조 배터리',
          language: 'English',
        ),
      ],
    );

    test('인도 검색 시 뜻에 포함된 단어만 반환한다', () {
      final results = bundle.searchWords('인도', language: 'English');
      expect(results.length, 1);
      expect(results.first.term, 'hand over');
    });

    test('보조배터리 검색 시 보조 배터리 뜻을 찾는다', () {
      final results = bundle.searchWords('보조배터리', language: 'English');
      expect(results.length, 1);
      expect(results.first.term, 'portable charger');
    });
  });
}
