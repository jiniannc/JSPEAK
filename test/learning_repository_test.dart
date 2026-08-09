import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/data/datasources/local/learning_local_datasource.dart';
import 'package:jspeak/data/models/content_bundle.dart';
import 'package:jspeak/data/models/sentence.dart';
import 'package:jspeak/data/repositories/learning_repository.dart';

void main() {
  const sentenceA = Sentence(
    id: 'a',
    language: 'English',
    category: '탑승 안내',
    sentence: 'Hello',
    pronunciation: '',
    korean: '안녕',
    audioUrl: '',
    stars: 1,
    important: true,
  );

  const sentenceB = Sentence(
    id: 'b',
    language: 'English',
    category: '식사',
    sentence: 'Water',
    pronunciation: '',
    korean: '물',
    audioUrl: '',
    stars: 0,
    important: false,
  );

  final bundle = ContentBundle(
    sentences: [sentenceA, sentenceB],
    categoryOrder: ['탑승 안내', '식사'],
  );

  late LearningRepository repo;

  setUp(() {
    repo = LearningRepository(local: LearningLocalDataSource());
  });

  test('같은 날짜에는 동일한 추천 문장을 고른다', () {
    final day = DateTime(2026, 7, 9);
    expect(repo.pickDailySentence(bundle, day), repo.pickDailySentence(bundle, day));
  });

  test('필수 문장 풀에서 추천 문장을 고른다', () {
    final picked = repo.pickDailySentence(bundle, DateTime(2026, 7, 9));
    expect(picked?.important, isTrue);
  });

  test('같은 달 오늘의 문장은 중복되지 않는다', () {
    final sentences = List.generate(
      5,
      (i) => Sentence(
        id: 'e$i',
        language: 'English',
        category: '탑승 안내',
        sentence: 'Sentence $i',
        pronunciation: '',
        korean: '문장 $i',
        audioUrl: '',
        stars: 1,
        important: true,
      ),
    );
    final augustBundle = ContentBundle(
      sentences: sentences,
      categoryOrder: ['탑승 안내'],
    );

    final seen = <String>{};
    for (var day = 1; day <= 5; day++) {
      final picked = repo.pickDailySentenceForLanguage(
        augustBundle,
        'English',
        DateTime(2026, 8, day),
      );
      expect(picked, isNotNull);
      expect(seen.contains(picked!.id), isFalse, reason: '$day일 중복');
      seen.add(picked.id);
    }
  });

  test('같은 달 다른 날짜에는 다른 문장이 나온다', () {
    const s1 = Sentence(
      id: 'e1',
      language: 'English',
      category: '탑승 안내',
      sentence: 'One',
      pronunciation: '',
      korean: '하나',
      audioUrl: '',
      stars: 1,
      important: true,
    );
    const s2 = Sentence(
      id: 'e2',
      language: 'English',
      category: '탑승 안내',
      sentence: 'Two',
      pronunciation: '',
      korean: '둘',
      audioUrl: '',
      stars: 1,
      important: true,
    );
    final twoSentenceBundle = ContentBundle(
      sentences: [s1, s2],
      categoryOrder: ['탑승 안내'],
    );

    final day1 = repo.pickDailySentenceForLanguage(
      twoSentenceBundle,
      'English',
      DateTime(2026, 8, 1),
    );
    final day2 = repo.pickDailySentenceForLanguage(
      twoSentenceBundle,
      'English',
      DateTime(2026, 8, 2),
    );

    expect(day1, isNotNull);
    expect(day2, isNotNull);
    expect(day1!.id, isNot(day2!.id));
  });

  test('연습 기록 비율을 계산한다', () {
    const stats = LearningStats(practicedSentenceIds: {'a'});
    expect(repo.progressRatio(stats, bundle), 0.5);
  });

  test('이번 주 스트릭을 월~일 순서로 만든다', () {
    final monday = DateTime(2026, 7, 6);
    final streak = weeklyStreakFor(monday, {'2026-07-06', '2026-07-08'});
    expect(streak, [true, false, true, false, false, false, false]);
  });

  test('이번 달 체크인 횟수를 계산한다', () {
    final anchor = DateTime(2026, 8, 3);
    final count = monthlyCheckInsFor(
      anchor,
      {'2026-08-01', '2026-08-03', '2026-07-31'},
    );
    expect(count, 2);
  });

  test('언어별 오늘의 문장은 해당 언어 풀에서 고른다', () {
    const jp = Sentence(
      id: 'jp1',
      language: 'Japanese',
      category: '탑승',
      sentence: 'こんにちは',
      pronunciation: '',
      korean: '안녕',
      audioUrl: '',
      stars: 1,
      important: true,
    );
    const cn = Sentence(
      id: 'cn1',
      language: 'Chinese',
      category: '탑승',
      sentence: '你好',
      pronunciation: '',
      korean: '안녕',
      audioUrl: '',
      stars: 1,
      important: true,
    );
    final multiLang = ContentBundle(
      sentences: [sentenceA, sentenceB, jp, cn],
      categoryOrder: ['탑승 안내', '식사', '탑승'],
    );
    final day = DateTime(2026, 8, 3);
    final startOfMonth = DateTime(2026, 8, 1);

    expect(
      repo.pickDailySentenceForLanguage(multiLang, 'English', day)?.language,
      'English',
    );
    expect(
      repo.pickDailySentenceForLanguage(multiLang, 'Japanese', day)?.language,
      'Japanese',
    );

    final candidates = repo.pickDailySentenceCandidatesForLanguage(
      multiLang,
      'English',
      startOfMonth,
    );
    expect(candidates, isNotEmpty);
    expect(candidates.every((s) => s.language == 'English'), isTrue);
    expect(candidates.length, lessThanOrEqualTo(2));
    expect(
      candidates.map((s) => s.id).toSet().length,
      candidates.length,
      reason: '후보 목록 안에서 중복 없음',
    );
  });
}
