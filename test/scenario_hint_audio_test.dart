import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/scenario_hint_audio.dart';
import 'package:jspeak/data/models/scenario_line.dart';
import 'package:jspeak/data/models/sentence.dart';

void main() {
  group('resolveScenarioHintAudio', () {
    const line = ScenarioLine(
      scenarioId: 'en_test',
      order: 2,
      speaker: 'Crew',
      textKo: 'ko',
      textTarget: 'Let me check if there are any available seats.',
      language: 'English',
    );

    test('prefers scenario line audio over sentence dictionary', () {
      final hint = resolveScenarioHintAudio(
        line: line.copyWith(
          audioUrl: Sentence.resolveAudioUrl('line-audio-id'),
        ),
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '좌석 안내',
            sentence: line.textTarget,
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('dict-audio-id'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips.single.playbackUrl, contains('line-audio-id'));
      expect(hint.clips.single.playbackUrl, isNot(contains('dict-audio-id')));
    });

    test('falls back to matching sentence audio by text_target', () {
      final hint = resolveScenarioHintAudio(
        line: line,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '좌석 안내',
            sentence: 'Let me check if there are any available seats.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('dict-audio-id'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips.single.playbackUrl, contains('dict-audio-id'));
      expect(hint.clips.single.segment.isPartial, isFalse);
    });

    test('auto-trims when sentence text wraps target with extras', () {
      final hint = resolveScenarioHintAudio(
        line: line,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '좌석 안내',
            sentence:
                'Thank you. Let me check if there are any available seats. Hello.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('dict-audio-id'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips.single.playbackUrl, contains('dict-audio-id'));
      expect(hint.clips.single.segment.isPartial, isTrue);
    });

    test('uses shorter sentence audio when it is prefix of text_target', () {
      const extendedLine = ScenarioLine(
        scenarioId: 'en_test',
        order: 2,
        speaker: 'Crew',
        textKo: 'ko',
        textTarget: 'Let me check if the item is in stock. Thank you.',
        language: 'English',
      );

      final hint = resolveScenarioHintAudio(
        line: extendedLine,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '유상 판매',
            sentence: 'Let me check if the item is in stock.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('dict-audio-id'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips.single.playbackUrl, contains('dict-audio-id'));
      expect(hint.clips.single.karaokeTokenCount, 9);
    });

    test('skips unmatched prefix and plays suffix dictionary clips only', () {
      const combinedLine = ScenarioLine(
        scenarioId: 'en_test',
        order: 2,
        speaker: 'Crew',
        textKo: 'ko',
        textTarget:
            'Sure, no problem. Let me check if the item is in stock. Thank you.',
        language: 'English',
      );

      final hint = resolveScenarioHintAudio(
        line: combinedLine,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '유상 판매',
            sentence: 'Let me check if the item is in stock.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('audio-part-1'),
            stars: 1,
            important: false,
          ),
          Sentence(
            id: 's2',
            language: 'English',
            category: '유상 판매',
            sentence: 'Thank you.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('audio-part-2'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.isMulti, isTrue);
      expect(hint.clips, hasLength(2));
      expect(hint.clips[0].karaokeTokenStart, 3);
      expect(hint.clips[0].playbackUrl, contains('audio-part-1'));
      expect(hint.clips[1].karaokeTokenStart, 12);
      expect(hint.clips[1].playbackUrl, contains('audio-part-2'));
    });

    test('plays suffix-only sentence audio when prefix is not in dictionary', () {
      const combinedLine = ScenarioLine(
        scenarioId: 'en_test',
        order: 2,
        speaker: 'Crew',
        textKo: 'ko',
        textTarget: 'Sure, no problem. Thank you.',
        language: 'English',
      );

      final hint = resolveScenarioHintAudio(
        line: combinedLine,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '유상 판매',
            sentence: 'Thank you.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('audio-suffix'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips, hasLength(1));
      expect(hint.clips.single.playbackUrl, contains('audio-suffix'));
      expect(hint.clips.single.karaokeTokenStart, 3);
      expect(hint.clips.single.karaokeTokenCount, 2);
    });

    test('matches dictionary sentences with relaxed language casing', () {
      final hint = resolveScenarioHintAudio(
        line: line,
        sentences: [
          Sentence(
            id: 's1',
            language: 'english',
            category: '좌석 안내',
            sentence: 'Let me check if there are any available seats.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('dict-audio-id'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.clips.single.playbackUrl, contains('dict-audio-id'));
    });

    test('chains multiple sentence audios for one bubble', () {
      const combinedLine = ScenarioLine(
        scenarioId: 'en_test',
        order: 2,
        speaker: 'Crew',
        textKo: 'ko',
        textTarget: 'Let me check if the item is in stock. Thank you.',
        language: 'English',
      );

      final hint = resolveScenarioHintAudio(
        line: combinedLine,
        sentences: [
          Sentence(
            id: 's1',
            language: 'English',
            category: '유상 판매',
            sentence: 'Let me check if the item is in stock.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('audio-part-1'),
            stars: 1,
            important: false,
          ),
          Sentence(
            id: 's2',
            language: 'English',
            category: '유상 판매',
            sentence: 'Thank you.',
            pronunciation: '',
            korean: '',
            audioUrl: Sentence.resolveAudioUrl('audio-part-2'),
            stars: 1,
            important: false,
          ),
        ],
      );

      expect(hint.isMulti, isTrue);
      expect(hint.clips, hasLength(2));
      expect(hint.clips[0].playbackUrl, contains('audio-part-1'));
      expect(hint.clips[1].playbackUrl, contains('audio-part-2'));
      expect(hint.clips[0].karaokeTokenStart, 0);
      expect(hint.clips[1].karaokeTokenStart, 9);
    });

    test('returns empty when no audio is available', () {
      expect(
        resolveScenarioHintAudio(line: line).playbackUrl,
        '',
      );
    });
  });

  group('inferHintAudioSegment', () {
    test('finds target tokens inside a longer sentence', () {
      final segment = inferHintAudioSegment(
        fullText: 'Thank you. Let me check if there are any available seats.',
        targetText: 'Let me check if there are any available seats.',
        language: 'English',
      );

      expect(segment, isNotNull);
      expect(segment!.startRatio, greaterThan(0));
      expect(segment.endRatio, closeTo(1.0, 0.001));
    });
  });
}

extension on ScenarioLine {
  ScenarioLine copyWith({
    String? audioUrl,
    double? audioStartSec,
    double? audioEndSec,
  }) {
    return ScenarioLine(
      scenarioId: scenarioId,
      title: title,
      order: order,
      speaker: speaker,
      textKo: textKo,
      textTarget: textTarget,
      pronunciation: pronunciation,
      blankFrame: blankFrame,
      flightStage: flightStage,
      level: level,
      language: language,
      chapterNo: chapterNo,
      chapterName: chapterName,
      chapterImage: chapterImage,
      avatarImage: avatarImage,
      audioUrl: audioUrl ?? this.audioUrl,
      audioStartSec: audioStartSec ?? this.audioStartSec,
      audioEndSec: audioEndSec ?? this.audioEndSec,
      isNewContent: isNewContent,
    );
  }
}

extension on ScenarioHintAudio {
  String get playbackUrl => clips.firstOrNull?.playbackUrl ?? '';
}
