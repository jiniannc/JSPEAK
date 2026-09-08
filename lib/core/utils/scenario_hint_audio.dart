import '../../core/config/audio_playback_url.dart';
import '../../data/models/scenario_line.dart';
import '../../data/models/sentence.dart';
import 'scenario_answer_compare.dart';
import 'word_compare.dart';

/// 녹음 파일 안에서 가라오케에 쓸 구간 (앞·뒤 여분 자동 추정).
class HintAudioSegment {
  final double? startRatio;
  final double? endRatio;
  final double? startSec;
  final double? endSec;

  const HintAudioSegment({
    this.startRatio,
    this.endRatio,
    this.startSec,
    this.endSec,
  });

  static const full = HintAudioSegment();

  bool get isPartial {
    if (startSec != null && startSec! > 0) return true;
    if (endSec != null && endSec! > 0) return true;
    if (startRatio != null && startRatio! > 0) return true;
    if (endRatio != null && endRatio! < 1) return true;
    return false;
  }

  (Duration start, Duration end) resolveBounds(Duration total) {
    if (total.inMilliseconds <= 0) {
      return (Duration.zero, Duration.zero);
    }

    if (startSec != null || endSec != null) {
      final startMs =
          ((startSec ?? 0) * 1000).round().clamp(0, total.inMilliseconds);
      final endMs = endSec != null && endSec! > 0
          ? (endSec! * 1000).round().clamp(startMs, total.inMilliseconds)
          : total.inMilliseconds;
      return (Duration(milliseconds: startMs), Duration(milliseconds: endMs));
    }

    final startRatioClamped = (startRatio ?? 0).clamp(0.0, 1.0);
    final endRatioClamped = (endRatio ?? 1).clamp(startRatioClamped, 1.0);
    return (
      Duration(
        milliseconds: (total.inMilliseconds * startRatioClamped).round(),
      ),
      Duration(
        milliseconds: (total.inMilliseconds * endRatioClamped).round(),
      ),
    );
  }
}

/// 재생할 녹음 한 덩어리.
class HintAudioClip {
  final String playbackUrl;
  final HintAudioSegment segment;
  /// [ScenarioLine.textTarget] 토큰 기준 가라오케 시작 인덱스.
  final int karaokeTokenStart;
  /// 이 클립에서 따라갈 토큰 수.
  final int karaokeTokenCount;

  const HintAudioClip({
    required this.playbackUrl,
    this.segment = HintAudioSegment.full,
    this.karaokeTokenStart = 0,
    required this.karaokeTokenCount,
  });
}

class ScenarioHintAudio {
  final List<HintAudioClip> clips;

  const ScenarioHintAudio({this.clips = const []});

  static const empty = ScenarioHintAudio();

  bool get isAvailable => clips.isNotEmpty;

  bool get isMulti => clips.length > 1;
}

/// 시나리오 1차 힌트용 녹음 — 시나리오 audio → sentences(연속·부분) 자동 매칭.
ScenarioHintAudio resolveScenarioHintAudio({
  required ScenarioLine line,
  Iterable<Sentence> sentences = const [],
}) {
  final manualSegment = _manualSegment(line);

  if (line.audioUrl.isNotEmpty) {
    final direct = AudioPlaybackUrl.resolve(line.audioUrl);
    if (direct.isNotEmpty) {
      final targetTokens =
          WordCompare.splitTokens(line.textTarget, language: line.language);
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: direct,
            segment: manualSegment ?? HintAudioSegment.full,
            karaokeTokenCount: targetTokens.length,
          ),
        ],
      );
    }
  }

  final target = ScenarioAnswerCompare.normalize(
    line.textTarget,
    language: line.language,
  );
  if (target.isEmpty) return ScenarioHintAudio.empty;

  final chained = resolveDictionaryHintClips(
    line: line,
    sentences: sentences,
  );
  if (chained != null && chained.isNotEmpty) {
    return ScenarioHintAudio(clips: chained);
  }

  for (final sentence in sentences) {
    if (!_languageMatches(sentence.language, line.language) ||
        sentence.audioUrl.isEmpty) {
      continue;
    }

    final url = AudioPlaybackUrl.resolve(sentence.audioUrl);
    if (url.isEmpty) continue;

    final candidate = ScenarioAnswerCompare.normalize(
      sentence.sentence,
      language: line.language,
    );
    final targetTokens =
        WordCompare.splitTokens(line.textTarget, language: line.language);

    if (candidate == target) {
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: url,
            segment: manualSegment ?? HintAudioSegment.full,
            karaokeTokenCount: targetTokens.length,
          ),
        ],
      );
    }

    final inferred = inferHintAudioSegment(
      fullText: sentence.sentence,
      targetText: line.textTarget,
      language: line.language,
    );
    if (inferred != null) {
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: url,
            segment: manualSegment ?? inferred,
            karaokeTokenCount: targetTokens.length,
          ),
        ],
      );
    }

    final inTarget = inferHintAudioSegment(
      fullText: line.textTarget,
      targetText: sentence.sentence,
      language: line.language,
    );
    if (inTarget != null) {
      final sentenceTokens = WordCompare.splitTokens(
        sentence.sentence,
        language: line.language,
      );
      final startIdx = _tokenStartIndexForSegment(
        line.textTarget,
        inTarget,
        line.language,
      );
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: url,
            segment: manualSegment ?? HintAudioSegment.full,
            karaokeTokenStart: startIdx,
            karaokeTokenCount: sentenceTokens.length,
          ),
        ],
      );
    }

    if (sentenceIsPrefixOfTarget(
      sentenceText: sentence.sentence,
      targetText: line.textTarget,
      language: line.language,
    )) {
      final sentenceTokens = WordCompare.splitTokens(
        sentence.sentence,
        language: line.language,
      );
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: url,
            segment: manualSegment ?? HintAudioSegment.full,
            karaokeTokenCount: sentenceTokens.length,
          ),
        ],
      );
    }

    final suffixStart = _sentenceSuffixStartInTarget(
      sentenceText: sentence.sentence,
      targetText: line.textTarget,
      language: line.language,
    );
    if (suffixStart != null) {
      final sentenceTokens = WordCompare.splitTokens(
        sentence.sentence,
        language: line.language,
      );
      return ScenarioHintAudio(
        clips: [
          HintAudioClip(
            playbackUrl: url,
            segment: manualSegment ?? HintAudioSegment.full,
            karaokeTokenStart: suffixStart,
            karaokeTokenCount: sentenceTokens.length,
          ),
        ],
      );
    }
  }

  return ScenarioHintAudio.empty;
}

String resolveScenarioHintAudioUrl({
  required ScenarioLine line,
  Iterable<Sentence> sentences = const [],
}) {
  final first = resolveScenarioHintAudio(line: line, sentences: sentences)
      .clips
      .firstOrNull;
  return first?.playbackUrl ?? '';
}

/// text_target을 sentences 행들로 순서대로 이어 붙여 클립 목록 생성.
List<HintAudioClip>? resolveDictionaryHintClips({
  required ScenarioLine line,
  Iterable<Sentence> sentences = const [],
}) {
  final language = line.language;
  final targetTokens =
      WordCompare.splitTokens(line.textTarget, language: language);
  if (targetTokens.isEmpty) return null;

  final pool = sentences
      .where(
        (s) => _languageMatches(s.language, language) && s.audioUrl.isNotEmpty,
      )
      .toList();
  if (pool.isEmpty) return null;

  final clips = <HintAudioClip>[];
  var cursor = 0;

  while (cursor < targetTokens.length) {
    final atCursor = _bestDictionaryClipAt(
      pool: pool,
      targetTokens: targetTokens,
      cursor: cursor,
      language: language,
    );

    if (atCursor != null) {
      clips.add(atCursor.clip);
      cursor += atCursor.length;
      continue;
    }

    final jumped = _nextDictionaryClipAfter(
      pool: pool,
      targetTokens: targetTokens,
      afterCursor: cursor,
      language: language,
    );
    if (jumped == null) break;

    clips.add(jumped.clip);
    cursor = jumped.start + jumped.length;
  }

  return clips.isEmpty ? null : clips;
}

({HintAudioClip clip, int length})? _bestDictionaryClipAt({
  required List<Sentence> pool,
  required List<String> targetTokens,
  required int cursor,
  required String language,
}) {
  HintAudioClip? bestClip;
  var bestLen = 0;

  for (final sentence in pool) {
    final sentenceTokens =
        WordCompare.splitTokens(sentence.sentence, language: language);
    if (sentenceTokens.isEmpty) continue;
    if (cursor + sentenceTokens.length > targetTokens.length) continue;
    if (!_tokensEqualAt(
      targetTokens,
      cursor,
      sentenceTokens,
      language: language,
    )) {
      continue;
    }

    if (sentenceTokens.length <= bestLen) continue;

    final url = AudioPlaybackUrl.resolve(sentence.audioUrl);
    if (url.isEmpty) continue;

    bestLen = sentenceTokens.length;
    bestClip = HintAudioClip(
      playbackUrl: url,
      segment: HintAudioSegment.full,
      karaokeTokenStart: cursor,
      karaokeTokenCount: sentenceTokens.length,
    );
  }

  if (bestClip == null) return null;
  return (clip: bestClip, length: bestLen);
}

({HintAudioClip clip, int start, int length})? _nextDictionaryClipAfter({
  required List<Sentence> pool,
  required List<String> targetTokens,
  required int afterCursor,
  required String language,
}) {
  for (var probe = afterCursor + 1; probe < targetTokens.length; probe++) {
    final match = _bestDictionaryClipAt(
      pool: pool,
      targetTokens: targetTokens,
      cursor: probe,
      language: language,
    );
    if (match != null) {
      return (clip: match.clip, start: probe, length: match.length);
    }
  }
  return null;
}

bool _languageMatches(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

int _tokenStartIndexForSegment(
  String targetText,
  HintAudioSegment segment,
  String language,
) {
  final targetTokens = WordCompare.splitTokens(targetText, language: language);
  if (targetTokens.isEmpty) return 0;

  if (segment.startSec != null || segment.endSec != null) {
    return 0;
  }

  final startRatio = (segment.startRatio ?? 0).clamp(0.0, 1.0);
  return (targetTokens.length * startRatio).floor().clamp(0, targetTokens.length - 1);
}

/// sentences 문장이 [targetText] 끝(접미)과 일치할 때 시작 토큰 인덱스.
int? _sentenceSuffixStartInTarget({
  required String sentenceText,
  required String targetText,
  required String language,
}) {
  final sentenceTokens =
      WordCompare.splitTokens(sentenceText, language: language);
  final targetTokens = WordCompare.splitTokens(targetText, language: language);
  if (sentenceTokens.isEmpty ||
      targetTokens.isEmpty ||
      sentenceTokens.length > targetTokens.length) {
    return null;
  }

  final start = targetTokens.length - sentenceTokens.length;
  if (!_tokensEqualAt(
    targetTokens,
    start,
    sentenceTokens,
    language: language,
  )) {
    return null;
  }
  return start > 0 ? start : null;
}

HintAudioSegment? _manualSegment(ScenarioLine line) {
  if (line.audioStartSec == null && line.audioEndSec == null) return null;
  return HintAudioSegment(
    startSec: line.audioStartSec ?? 0,
    endSec: line.audioEndSec,
  );
}

bool _tokensEqualAt(
  List<String> targetTokens,
  int start,
  List<String> sentenceTokens, {
  required String language,
}) {
  for (var i = 0; i < sentenceTokens.length; i++) {
    if (!_tokenEquivalent(
      targetTokens[start + i],
      sentenceTokens[i],
      language: language,
    )) {
      return false;
    }
  }
  return true;
}

bool _tokenEquivalent(String a, String b, {required String language}) {
  final left = ScenarioAnswerCompare.normalize(a, language: language);
  final right = ScenarioAnswerCompare.normalize(b, language: language);
  if (left == right) return true;
  return WordCompare.normalize(a) == WordCompare.normalize(b);
}

/// sentences 전체 문장 안에서 [targetText] 위치를 토큰 기준으로 추정.
HintAudioSegment? inferHintAudioSegment({
  required String fullText,
  required String targetText,
  required String language,
}) {
  final normFull = ScenarioAnswerCompare.normalize(fullText, language: language);
  final normTarget = ScenarioAnswerCompare.normalize(
    targetText,
    language: language,
  );
  if (normTarget.isEmpty || normFull.isEmpty) return null;
  if (normFull == normTarget) return HintAudioSegment.full;

  final fullTokens = WordCompare.splitTokens(fullText, language: language);
  final targetTokens = WordCompare.splitTokens(targetText, language: language);
  if (targetTokens.isNotEmpty && fullTokens.length >= targetTokens.length) {
    for (var i = 0; i <= fullTokens.length - targetTokens.length; i++) {
      var matched = true;
      for (var j = 0; j < targetTokens.length; j++) {
        final left = ScenarioAnswerCompare.normalize(
          fullTokens[i + j],
          language: language,
        );
        final right = ScenarioAnswerCompare.normalize(
          targetTokens[j],
          language: language,
        );
        if (left != right) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return HintAudioSegment(
          startRatio: i / fullTokens.length,
          endRatio: (i + targetTokens.length) / fullTokens.length,
        );
      }
    }
  }

  final idx = normFull.indexOf(normTarget);
  if (idx < 0) return null;
  return HintAudioSegment(
    startRatio: idx / normFull.length,
    endRatio: (idx + normTarget.length) / normFull.length,
  );
}

/// sentences 문장이 [targetText]의 앞부분(접두)과 같을 때 true.
bool sentenceIsPrefixOfTarget({
  required String sentenceText,
  required String targetText,
  required String language,
}) {
  final sentenceTokens =
      WordCompare.splitTokens(sentenceText, language: language);
  final targetTokens = WordCompare.splitTokens(targetText, language: language);
  if (sentenceTokens.isEmpty ||
      targetTokens.isEmpty ||
      sentenceTokens.length > targetTokens.length) {
    return false;
  }

  return _tokensEqualAt(
    targetTokens,
    0,
    sentenceTokens,
    language: language,
  ) &&
      sentenceTokens.length < targetTokens.length;
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
