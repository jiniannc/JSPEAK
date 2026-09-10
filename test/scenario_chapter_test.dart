import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/data/models/scenario.dart';
import 'package:jspeak/data/models/scenario_chapter.dart';
import 'package:jspeak/data/models/scenario_line.dart';

void main() {
  group('ScenarioLine chapter fields', () {
    test('parses new flag from string true', () {
      final line = ScenarioLine.fromJson({
        'scenario_id': 'en_test',
        'order': 1,
        'speaker': 'Passenger',
        'text_ko': 'ko',
        'text_target': 'en',
        'language': 'English',
        'chapter_no': '2',
        'chapter_name': '기내 식사 서비스',
        'chapter_image': 'assets/images/ch_meal.png',
        'new': 'true',
      });

      expect(line.chapterNo, 2);
      expect(line.chapterName, '기내 식사 서비스');
      expect(line.chapterImage, 'assets/images/meal.png');
      expect(line.isNewContent, isTrue);
    });
  });

  group('ScenarioChapter grouping', () {
    test('groups by chapter_no and detects hasNewContent', () {
      final scenarios = Scenario.groupLines([
        ScenarioLine.fromJson({
          'scenario_id': 'a',
          'title': 'A',
          'order': 1,
          'speaker': 'Passenger',
          'text_ko': 'k',
          'text_target': 't',
          'language': 'English',
          'chapter_no': 1,
          'chapter_name': '탑승 및 좌석 안내',
          'new': true,
        }),
        ScenarioLine.fromJson({
          'scenario_id': 'b',
          'title': 'B',
          'order': 1,
          'speaker': 'Passenger',
          'text_ko': 'k',
          'text_target': 't',
          'language': 'English',
          'chapter_no': 2,
          'chapter_name': '기내 식사',
          'new': false,
        }),
      ]);

      final chapters = ScenarioChapter.fromScenarios(scenarios);
      expect(chapters.length, 2);
      expect(chapters[0].chapterNo, 1);
      expect(chapters[0].hasNewContent, isTrue);
      expect(chapters[1].hasNewContent, isFalse);

      final grouped = ScenarioChapter.groupByChapterNo(scenarios);
      expect(grouped[1]?.length, 1);
      expect(grouped[2]?.length, 1);
    });
  });
}
