import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/app/new_update_scenario_provider.dart';
import 'package:jspeak/data/models/scenario.dart';
import 'package:jspeak/data/models/scenario_line.dart';

void main() {
  test('scenarioMetaLine은 추가 신규 개수를 표시한다', () {
    const scenario = Scenario(
      id: 's1',
      language: 'Chinese',
      title: '테스트',
      flightStage: '식사',
      level: '중급',
      lines: [
        ScenarioLine(
          scenarioId: 's1',
          order: 1,
          speaker: 'crew',
          textKo: 'a',
          textTarget: 'b',
          language: 'Chinese',
        ),
        ScenarioLine(
          scenarioId: 's1',
          order: 2,
          speaker: 'passenger',
          textKo: 'c',
          textTarget: 'd',
          language: 'Chinese',
        ),
      ],
    );

    expect(scenarioMetaLine(scenario), '중급 · 2문장');
    expect(
      scenarioMetaLine(scenario, additionalCount: 2),
      '중급 · 2문장 · 외 2개 더보기',
    );
  });

  test('scenarioLanguageShortTag는 언어 코드를 반환한다', () {
    expect(scenarioLanguageShortTag('English'), 'EN');
    expect(scenarioLanguageShortTag('Japanese'), 'JP');
    expect(scenarioLanguageShortTag('Chinese'), 'CN');
  });
}
