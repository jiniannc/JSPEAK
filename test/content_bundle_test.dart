import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/config/audio_playback_url.dart';
import 'package:jspeak/data/models/content_bundle.dart';
import 'package:jspeak/data/models/sentence.dart';

void main() {
  final json = {
    'categoryOrder': ['탑승 안내', '식사 서비스'],
    'allSentences': [
      {
        'language': 'English',
        'category': '탑승 안내',
        'sentence': 'May I see your boarding pass?',
        'pronunciation': '메이 아이 씨 유어 보딩 패스?',
        'korean': '탑승권을 보여주시겠습니까?',
        'audio': 'https://example.com/a.mp3',
        'popular': 2,
        'important': 'Yes',
      },
      {
        'language': 'English',
        'category': '식사 서비스',
        'sentence': 'Chicken or beef?',
        'pronunciation': '치킨 오어 비프?',
        'korean': '치킨과 소고기 중 어느 것으로 드릴까요?',
        'audio': '',
        'popular': '1', // 문자열 숫자도 시트에서 올 수 있음
        'important': 'No',
      },
      {
        'language': 'Japanese',
        'category': '탑승 안내',
        'sentence': '搭乗券を拝見します。',
        'pronunciation': '토-죠-켄오 하이켄시마스',
        'korean': '탑승권을 확인하겠습니다.',
        'audio': '',
        'popular': 0,
        'important': 'No',
      },
    ],
  };

  group('ContentBundle.fromJson', () {
    test('문장·카테고리 순서를 파싱한다', () {
      final bundle = ContentBundle.fromJson(json);
      expect(bundle.sentences.length, 3);
      expect(bundle.categoryOrder, ['탑승 안내', '식사 서비스']);
    });

    test('popular가 문자열이어도 숫자로 파싱한다', () {
      final bundle = ContentBundle.fromJson(json);
      final meal =
          bundle.sentences.firstWhere((s) => s.category == '식사 서비스');
      expect(meal.stars, 1);
    });

    test('important Yes/No를 bool로 파싱한다', () {
      final bundle = ContentBundle.fromJson(json);
      expect(bundle.sentences.first.important, isTrue);
      expect(bundle.sentences.last.important, isFalse);
    });

    test('important true/false도 bool로 파싱한다', () {
      final withBool = ContentBundle.fromJson({
        'categoryOrder': ['탑승 안내'],
        'allSentences': [
          {
            'language': 'English',
            'category': '탑승 안내',
            'sentence': 'Checked',
            'pronunciation': '',
            'korean': '체크됨',
            'audio': '',
            'popular': 0,
            'important': true,
          },
          {
            'language': 'English',
            'category': '탑승 안내',
            'sentence': 'Unchecked',
            'pronunciation': '',
            'korean': '미체크',
            'audio': '',
            'popular': 0,
            'important': false,
          },
        ],
      });
      expect(withBool.sentences.first.important, isTrue);
      expect(withBool.sentences.last.important, isFalse);
    });
  });

  group('탐색', () {
    final bundle = ContentBundle.fromJson(json);

    test('languages는 등장 순서를 유지한다', () {
      expect(bundle.languages, ['English', 'Japanese']);
    });

    test('categoriesFor는 해당 언어에 있는 카테고리만 chapter_no 순으로 반환한다', () {
      expect(bundle.categoriesFor('English'), ['탑승 안내', '식사 서비스']);
      expect(bundle.categoriesFor('Japanese'), ['탑승 안내']);
    });

    test('sentenceChaptersFor는 chapter_no 순으로 정렬한다', () {
      final sorted = ContentBundle.fromJson({
        'categoryOrder': ['유상 판매', '이착륙 및 안전 안내', '탑승 안내'],
        'allSentences': [
          {
            'language': 'English',
            'chapter_no': 7,
            'category': '유상 판매',
            'sentence': 'Duty-free items',
            'pronunciation': '',
            'korean': '면세품',
            'audio': '',
            'popular': 0,
            'important': 'No',
          },
          {
            'language': 'English',
            'chapter_no': 4,
            'category': '이착륙 및 안전 안내',
            'sentence': 'Fasten seatbelt',
            'pronunciation': '',
            'korean': '안전벨트',
            'audio': '',
            'popular': 0,
            'important': 'No',
          },
          {
            'language': 'English',
            'chapter_no': 1,
            'category': '탑승 안내',
            'sentence': 'Boarding pass',
            'pronunciation': '',
            'korean': '탑승권',
            'audio': '',
            'popular': 0,
            'important': 'No',
          },
        ],
      });

      expect(
        sorted.categoriesFor('English'),
        ['탑승 안내', '이착륙 및 안전 안내', '유상 판매'],
      );
      expect(
        sorted.sentenceChaptersFor('English').map((c) => c.chapterNo),
        [1, 4, 7],
      );
    });

    test('categoriesForWords는 chapter_no 순으로 정렬한다', () {
      final sorted = ContentBundle.fromJson({
        'categoryOrder': ['유상 판매', '이착륙 및 안전 안내', '탑승 안내'],
        'allSentences': const [],
        'allWords': [
          {
            'language': 'English',
            'chapter_no': 7,
            'category': '유상 판매',
            'word': 'duty-free',
            'meaning': '면세',
            'popular': 0,
            'important': 'No',
          },
          {
            'language': 'English',
            'chapter_no': 4,
            'category': '이착륙 및 안전 안내',
            'word': 'safety',
            'meaning': '안전',
            'popular': 0,
            'important': 'No',
          },
          {
            'language': 'English',
            'chapter_no': 1,
            'category': '탑승 안내',
            'word': 'boarding',
            'meaning': '탑승',
            'popular': 0,
            'important': 'No',
          },
        ],
      });

      expect(
        sorted.categoriesForWords('English'),
        ['탑승 안내', '이착륙 및 안전 안내', '유상 판매'],
      );
      expect(
        sorted.wordChaptersFor('English').map((c) => c.chapterNo),
        [1, 4, 7],
      );
    });

    test('sentencesFor는 언어·카테고리로 필터링한다', () {
      final result = bundle.sentencesFor('English', '탑승 안내');
      expect(result.length, 1);
      expect(result.first.sentence, 'May I see your boarding pass?');
    });
  });

  group('검색', () {
    final bundle = ContentBundle.fromJson(json);

    test('문장·발음·한국어 모두에서 부분 일치한다', () {
      expect(bundle.search('boarding').length, 1);
      expect(bundle.search('치킨').length, 1); // 발음·한국어 매치
      expect(bundle.search('탑승권').length, 2); // 영어·일본어의 한국어 번역에 포함
    });

    test('대소문자를 무시한다', () {
      expect(bundle.search('CHICKEN').length, 1);
    });

    test('언어 필터가 적용된다', () {
      expect(bundle.search('탑승권', language: 'Japanese').length, 1);
      expect(bundle.search('탑승권', language: 'All').length, 2);
    });

    test('빈 검색어는 빈 결과를 반환한다', () {
      expect(bundle.search('  '), isEmpty);
    });
  });

  group('AudioPlaybackUrl', () {
    test('Drive 파일 ID를 Apps Script 프록시 URL로 변환한다', () {
      expect(
        AudioPlaybackUrl.resolve(
          '1TNZ_eWOxd8K1dSxQcgS0H1m1VzRJxMEG',
          proxyBase: 'https://example.com/exec',
        ),
        'https://example.com/exec?audio=1TNZ_eWOxd8K1dSxQcgS0H1m1VzRJxMEG',
      );
    });
  });

  group('Sentence.resolveAudioUrl', () {
    test('Drive 파일 ID를 다운로드 URL로 변환한다', () {
      expect(
        Sentence.resolveAudioUrl('1TNZ_eWOxd8K1dSxQcgS0H1m1VzRJxMEG'),
        'https://drive.usercontent.google.com/download?id=1TNZ_eWOxd8K1dSxQcgS0H1m1VzRJxMEG&export=download',
      );
    });

    test('기존 http URL은 그대로 유지한다', () {
      const url = 'https://example.com/a.mp3';
      expect(Sentence.resolveAudioUrl(url), url);
    });

    test('빈 값은 빈 문자열을 반환한다', () {
      expect(Sentence.resolveAudioUrl(''), '');
      expect(Sentence.resolveAudioUrl('  '), '');
    });
  });

  group('Sentence 여자/남자 음성', () {
    Sentence parse({String female = '', String male = ''}) => Sentence.fromJson({
          'language': 'English',
          'category': '탑승 안내',
          'sentence': 'Hello',
          'pronunciation': '',
          'korean': '',
          'audio': female,
          'audio_male': male,
          'popular': 0,
          'important': 'No',
        });

    test('audio는 여자, audio_male은 남자 음성으로 파싱한다', () {
      final s = parse(
        female: 'https://example.com/f.mp3',
        male: 'https://example.com/m.mp3',
      );
      expect(s.hasBothVoices, isTrue);
      expect(s.audioUrlFor(VoiceGender.female), 'https://example.com/f.mp3');
      expect(s.audioUrlFor(VoiceGender.male), 'https://example.com/m.mp3');
    });

    test('선택한 음성이 없으면 다른 음성으로 대체한다', () {
      final onlyFemale = parse(female: 'https://example.com/f.mp3');
      expect(onlyFemale.hasBothVoices, isFalse);
      expect(onlyFemale.resolveVoice(VoiceGender.male), VoiceGender.female);
      expect(
        onlyFemale.audioUrlFor(VoiceGender.male),
        'https://example.com/f.mp3',
      );

      final onlyMale = parse(male: 'https://example.com/m.mp3');
      expect(onlyMale.hasAnyAudio, isTrue);
      expect(onlyMale.resolveVoice(VoiceGender.female), VoiceGender.male);
    });

    test('둘 다 없으면 재생할 음성이 없다', () {
      final none = parse();
      expect(none.hasAnyAudio, isFalse);
      expect(none.resolveVoice(VoiceGender.female), isNull);
      expect(none.audioUrlFor(VoiceGender.female), '');
    });

    test('toJson → fromJson 후 남자 음성이 보존된다', () {
      final s = parse(
        female: 'https://example.com/f.mp3',
        male: 'https://example.com/m.mp3',
      );
      final restored = Sentence.fromJson(s.toJson());
      expect(restored.audioUrlMale, 'https://example.com/m.mp3');
    });
  });

  group('ContentBundle.newSentenceGroupsFor', () {
    Map<String, dynamic> row(String category, String text, {bool isNew = false}) => {
          'language': 'English',
          'chapter_no': 2,
          'category': category,
          'sentence': text,
          'pronunciation': '',
          'korean': '',
          'audio': '',
          'popular': 0,
          'important': 'No',
          if (isNew) 'new': true,
        };

    test('new 문장이 있는 괄호 그룹만 묶어서 반환한다', () {
      final bundle = ContentBundle.fromJson({
        'categoryOrder': <String>[],
        'allSentences': [
          row('탑승 (인사)', 'Hello', isNew: true),
          row('탑승 (인사)', 'Welcome aboard'),
          row('탑승 (인사)', 'Good morning', isNew: true),
          row('탑승 (좌석 안내)', 'Your seat is here'),
          row('식사', 'Chicken or beef?', isNew: true),
        ],
      });

      final groups = bundle.newSentenceGroupsFor('English');
      expect(groups.map((g) => g.fullCategory), ['탑승 (인사)', '식사']);

      final greeting = groups.first;
      expect(greeting.baseName, '탑승');
      expect(greeting.label, '인사');
      expect(greeting.chapterNo, 2);
      expect(greeting.sentenceCount, 3);

      expect(groups.last.label, '식사');
      expect(bundle.newSentenceGroupsFor('Japanese'), isEmpty);
    });

    test('시트 new 값(true/Yes/체크박스)을 파싱한다', () {
      expect(Sentence.fromJson(row('a', 'x', isNew: true)).isNewContent, isTrue);
      expect(Sentence.fromJson({...row('a', 'x'), 'new': 'Yes'}).isNewContent, isTrue);
      expect(Sentence.fromJson(row('a', 'x')).isNewContent, isFalse);
    });
  });

  group('Sentence.stableId', () {
    test('같은 내용이면 같은 ID', () {
      final a = Sentence.stableId('English', '탑승 안내', 'Hello');
      final b = Sentence.stableId('English', '탑승 안내', 'Hello');
      expect(a, b);
    });

    test('내용이 다르면 다른 ID', () {
      final a = Sentence.stableId('English', '탑승 안내', 'Hello');
      final b = Sentence.stableId('Japanese', '탑승 안내', 'Hello');
      expect(a, isNot(b));
    });
  });

  group('직렬화 왕복', () {
    test('toJson → fromJson 후 데이터가 보존된다', () {
      final bundle = ContentBundle.fromJson(json);
      final restored = ContentBundle.fromJson(bundle.toJson());
      expect(restored.sentences.length, bundle.sentences.length);
      expect(restored.categoryOrder, bundle.categoryOrder);
      expect(restored.sentences.first.id, bundle.sentences.first.id);
      expect(restored.sentences.first.important, isTrue);
    });
  });
}
