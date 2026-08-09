import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/answer_blank_hints.dart';

void main() {
  group('AnswerBlankHints letterStates', () {
    const correct =
        'Could you please fold the stroller before boarding the plane?';
    const spoken = 'Could you';

    test('structure off: prefix fill at sentence start', () {
      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: spoken,
        language: 'English',
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
      );
      expect(_revealedPrefix(letters, states), startsWith('could you'));
    });

    test('structure on with two leading blanks: fills Could you only', () {
      const frame =
          '____ ____ please fold the stroller before boarding the plane?';
      final keyRuns = AnswerBlankHints.contiguousKeyRuns(
        correct: correct,
        blankFrame: frame,
        language: 'English',
      );
      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: spoken,
        language: 'English',
        blankFrame: frame,
        structureRevealed: true,
        keyRuns: keyRuns,
        blankRunInputs: const ['Could you'],
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
        blankFrame: frame,
      );
      final revealed = _revealedPrefix(letters, states, includeStructure: true);
      expect(revealed, startsWith('could you'));
      expect(revealed, contains('please'));
    });

    test('partial typo does not scatter letters across slots', () {
      const frame =
          '____ ____ please fold the stroller before boarding the plane?';
      final keyRuns = AnswerBlankHints.contiguousKeyRuns(
        correct: correct,
        blankFrame: frame,
        language: 'English',
      );
      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: 'Cou',
        language: 'English',
        blankFrame: frame,
        structureRevealed: true,
        keyRuns: keyRuns,
        blankRunInputs: const ['Cou'],
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
        blankFrame: frame,
      );

      final couldSlots = <String>[];
      for (var i = 0; i < letters.length; i++) {
        if (letters[i].isGap) break;
        if (states[i].kind == BlankRevealKind.correct) {
          couldSlots.add(states[i].shown!);
        } else {
          couldSlots.add('_');
        }
      }
      expect(couldSlots.join(), 'cou__');
    });

    test('blank fill: typed text in first run only', () {
      const frame =
          '____ ____ please fold the stroller before boarding the plane?';
      final keyRuns = AnswerBlankHints.contiguousKeyRuns(
        correct: correct,
        blankFrame: frame,
        language: 'English',
      );
      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: '',
        language: 'English',
        blankFrame: frame,
        structureRevealed: true,
        keyRuns: keyRuns,
        blankRunInputs: const ['Could you'],
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
        blankFrame: frame,
      );

      var correctCount = 0;
      for (var i = 0; i < letters.length; i++) {
        if (states[i].kind == BlankRevealKind.correct) correctCount++;
      }
      expect(correctCount, 8);
    });

    test('CJK layout spec uses fullwidth placeholder and wider slots', () {
      const fontSize = 16.5;
      final cjkSpec = BlankLayoutSpec.forLanguage('Japanese', fontSize);
      final enSpec = BlankLayoutSpec.forLanguage('English', fontSize);
      expect(cjkSpec.blankPlaceholder, '＿');
      expect(enSpec.blankPlaceholder, '_');
      expect(cjkSpec.minSlotWidth, greaterThan(enSpec.minSlotWidth));
      expect(cjkSpec.letterGap, greaterThan(enSpec.letterGap));
      expect(cjkSpec.maxSlotWidth, greaterThan(enSpec.maxSlotWidth));
    });
  });
}

String _revealedPrefix(
  List<BlankLetter> letters,
  List<BlankLetterState> states, {
  bool includeStructure = false,
}) {
  final revealed = StringBuffer();
  for (var i = 0; i < letters.length; i++) {
    if (letters[i].isGap) {
      revealed.write(' ');
      continue;
    }
    final s = states[i];
    if (s.kind == BlankRevealKind.correct) {
      revealed.write(s.shown);
    } else if (includeStructure && s.kind == BlankRevealKind.structure) {
      revealed.write(letters[i].char);
    } else {
      revealed.write('_');
    }
  }
  return revealed.toString();
}
