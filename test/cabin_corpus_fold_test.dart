import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/japanese_to_korean_converter.dart';

import 'fixtures/cabin_japanese_corpus.dart';

/// 기내 방송 172문장 코퍼스 — 한자 읽기 사전 커버리지 회귀.
/// 새 문장 추가 시 이 테스트만 돌리면 미등록 한자를 자동으로 잡는다.
void main() {
  test('모든 코퍼스 문장의 한자에 읽기가 등록되어 있다', () {
    final failures = <String, Set<String>>{};
    for (final sentence in CabinJapaneseCorpus.sentences) {
      final missing = JapaneseToKoreanConverter.missingKanjiIn(sentence);
      if (missing.isNotEmpty) {
        failures[sentence] = missing;
      }
    }

    if (failures.isNotEmpty) {
      final report = StringBuffer('미등록 한자:\n');
      for (final entry in failures.entries) {
        report.writeln('• ${entry.key}');
        report.writeln('  → ${entry.value.join(', ')}');
      }
      fail(report.toString());
    }
  });
}
