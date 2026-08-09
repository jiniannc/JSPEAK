import 'package:flutter_test/flutter_test.dart';

import 'package:jspeak/core/utils/vocabulary_span_builder.dart';

import 'package:jspeak/core/utils/word_compare.dart';

import 'package:jspeak/core/utils/word_match.dart';

import 'package:jspeak/data/models/vocabulary_entry.dart';



void main() {

  group('WordMatch', () {

    test('복수형 crutches → crutch', () {

      expect(WordMatch.flexibleMatch('crutches', 'crutch'), isTrue);

    });



    test('괄호 crutches(cane) → crutch', () {

      expect(WordMatch.flexibleMatch('crutches(cane)', 'crutch'), isTrue);

    });

  });



  group('VocabularyIndex', () {

    test('emergency exit row 전체가 한 구문으로 매칭된다', () {

      final index = VocabularyIndex.fromEntries(const [

        VocabularyEntry(

          term: 'emergency exit row',

          meaning: '비상구 좌석 열',

        ),

      ]);



      final sentence =

          'This is an emergency exit row, so you must store all carry-on bags.';

      final matches =

          VocabularySpanBuilder.findPhraseMatches(sentence, index.entries);

      expect(matches, hasLength(1));

      expect(matches.first.startIndex, 3);

      expect(matches.first.endIndex, 5);

      expect(matches.first.entry.term, 'emergency exit row');

    });



    test('탭 인덱스가 구문 중간(exit)이어도 조회된다', () {

      final index = VocabularyIndex.fromEntries(const [

        VocabularyEntry(term: 'emergency exit row', meaning: '비상구 좌석 열'),

      ]);

      final words = WordCompare.splitWords(

        'This is an emergency exit row, so',

      );

      expect(

        VocabularySpanBuilder.lookupAt(index, words, 4)?.term,

        'emergency exit row',

      );

    });

  });

}

