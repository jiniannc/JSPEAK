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

    test('wrong first word still reveals later correct words', () {
      const correct =
          'Could you please fold your stroller before you get on the plane?';
      const spoken =
          'would you please fold your stroller before you get on the plane';
      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: spoken,
        language: 'English',
      );
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
      );

      var wordIdx = 0;
      var wrongFirstWord = false;
      var laterCorrect = false;
      for (var i = 0; i < letters.length; i++) {
        if (letters[i].isGap) {
          wordIdx++;
          continue;
        }
        if (wordIdx == 0 && states[i].kind == BlankRevealKind.wrong) {
          wrongFirstWord = true;
        }
        if (wordIdx >= 2 && states[i].kind == BlankRevealKind.correct) {
          laterCorrect = true;
        }
      }
      expect(wrongFirstWord, isTrue);
      expect(laterCorrect, isTrue);
    });

    test('skipped middle word still matches later words', () {
      const correct =
          'Could you please fold your stroller before you get on the plane?';
      const spoken =
          'Could you fold your stroller before you get on the plane';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: spoken,
        language: 'English',
      );

      bool wordFullyCorrect(int targetWordIdx) {
        var wordIdx = 0;
        for (var i = 0; i < layout.letters.length; i++) {
          if (layout.letters[i].isGap) {
            wordIdx++;
            continue;
          }
          if (wordIdx != targetWordIdx) continue;
          if (layout.states[i].kind != BlankRevealKind.correct) return false;
        }
        return true;
      }

      bool wordBlank(int targetWordIdx) {
        var wordIdx = 0;
        for (var i = 0; i < layout.letters.length; i++) {
          if (layout.letters[i].isGap) {
            wordIdx++;
            continue;
          }
          if (wordIdx != targetWordIdx) continue;
          if (layout.states[i].kind != BlankRevealKind.blank) return false;
        }
        return true;
      }

      expect(wordFullyCorrect(0), isTrue); // Could
      expect(wordFullyCorrect(1), isTrue); // you
      expect(wordBlank(2), isTrue); // please omitted
      expect(wordFullyCorrect(3), isTrue); // fold
      expect(wordFullyCorrect(4), isTrue); // your
    });

    test('wrong longer word adds overflow slots', () {
      const correct = 'Could you fold the plane?';
      const spoken = 'couldnt you fold the plane';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: spoken,
        language: 'English',
      );
      final baseLetters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
      );
      expect(layout.letters.length, greaterThan(baseLetters.length));

      var wordIdx = 0;
      var overflowCount = 0;
      for (var i = 0; i < layout.letters.length; i++) {
        if (layout.letters[i].isGap) {
          wordIdx++;
          continue;
        }
        if (wordIdx == 0 && layout.letters[i].isOverflow) {
          overflowCount++;
          expect(layout.states[i].kind, BlankRevealKind.wrong);
        }
      }
      expect(overflowCount, 2); // "couldnt" vs "Could" → nt
    });

    test('empty spoken restores base slot count', () {
      const correct = 'Could you fold the plane?';
      final baseLetters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
      );
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: '',
        language: 'English',
      );
      expect(layout.letters.length, baseLetters.length);
    });

    test('classify omitted middle word', () {
      const correct =
          'Could you please fold your stroller before you get on the plane?';
      const spoken =
          'Could you fold your stroller before you get on the plane';
      expect(
        AnswerBlankHints.classifyEnglishSpeakingWrong(
          correct: correct,
          spoken: spoken,
        ),
        EnglishSpeakingWrongKind.omittedWord,
      );
    });

    test('classify incomplete ending', () {
      const correct =
          'Could you please fold your stroller before you get on the plane?';
      const spoken = 'Could you please fold your stroller';
      expect(
        AnswerBlankHints.classifyEnglishSpeakingWrong(
          correct: correct,
          spoken: spoken,
        ),
        EnglishSpeakingWrongKind.incompleteEnding,
      );
    });

    test('classify mispronunciation', () {
      const correct =
          'Could you please fold your stroller before you get on the plane?';
      const spoken =
          'would you please fold your stroller before you get on the plane';
      expect(
        AnswerBlankHints.classifyEnglishSpeakingWrong(
          correct: correct,
          spoken: spoken,
        ),
        EnglishSpeakingWrongKind.mispronunciation,
      );
    });

    test('keyboard typing: correct word does not leak next word prefix', () {
      const correct =
          'Yes, this is security work. Please enter one by one for safety.';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: 'yes',
        language: 'English',
        keyboardTyping: true,
      );

      bool wordHasCorrect(int targetWordIdx) {
        var wordIdx = 0;
        for (var i = 0; i < layout.letters.length; i++) {
          if (layout.letters[i].isGap) {
            wordIdx++;
            continue;
          }
          if (wordIdx != targetWordIdx) continue;
          if (layout.states[i].kind == BlankRevealKind.correct) return true;
        }
        return false;
      }

      expect(wordHasCorrect(0), isTrue);
      expect(wordHasCorrect(1), isFalse);
    });

    test('keyboard typing: wrong chars show red within word', () {
      const correct = 'Yes, this is security work.';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: 'yex',
        language: 'English',
        keyboardTyping: true,
      );

      final wrongChars = <String>[];
      var wordIdx = 0;
      for (var i = 0; i < layout.letters.length; i++) {
        if (layout.letters[i].isGap) {
          wordIdx++;
          continue;
        }
        if (wordIdx == 0 && layout.states[i].kind == BlankRevealKind.wrong) {
          wrongChars.add(layout.states[i].shown!);
        }
      }
      expect(wrongChars, contains('x'));
    });

    test('keyboard typing: wrong word then correct next word after space', () {
      const correct = 'Yes, this is security work.';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: 'yex this',
        language: 'English',
        keyboardTyping: true,
      );

      bool wordFullyCorrect(int targetWordIdx) {
        var wordIdx = 0;
        for (var i = 0; i < layout.letters.length; i++) {
          if (layout.letters[i].isGap) {
            wordIdx++;
            continue;
          }
          if (wordIdx != targetWordIdx) continue;
          if (layout.letters[i].isPunctuation) continue;
          if (layout.states[i].kind != BlankRevealKind.correct) return false;
        }
        return true;
      }

      expect(wordFullyCorrect(1), isTrue);
    });

    test('keyboard typing: char by char prefix fill', () {
      const correct = 'Yes, this is security work.';
      final layout = AnswerBlankHints.layout(
        correct: correct,
        spoken: 'ye',
        language: 'English',
        keyboardTyping: true,
      );

      var correctCount = 0;
      var wordIdx = 0;
      for (var i = 0; i < layout.letters.length; i++) {
        if (layout.letters[i].isGap) {
          wordIdx++;
          continue;
        }
        if (wordIdx == 0 && layout.states[i].kind == BlankRevealKind.correct) {
          correctCount++;
        }
      }
      expect(correctCount, 2);
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

    test('displayLetters keeps trailing sentence punctuation', () {
      const correct = 'Thank you. May I check your boarding pass?';
      final letters = AnswerBlankHints.displayLetters(
        correct,
        language: 'English',
      );
      final chars = [
        for (final l in letters)
          if (!l.isGap) l.char,
      ].join();
      expect(chars, contains('.'));
      expect(chars, endsWith('?'));

      final states = AnswerBlankHints.letterStates(
        correct: correct,
        spoken: '',
        language: 'English',
        blankFrame: '____ ____. ____ I check your boarding pass?',
        structureRevealed: true,
      );
      final punctStates = [
        for (var i = 0; i < letters.length; i++)
          if (letters[i].isPunctuation) states[i],
      ];
      expect(punctStates, isNotEmpty);
      expect(
        punctStates.every((s) => s.kind == BlankRevealKind.structure),
        isTrue,
      );
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
