import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/datasources/local/scenario_progress_local_datasource.dart';
import '../data/models/content_bundle.dart';
import '../data/models/scenario.dart';
import '../data/models/scenario_chapter.dart';
import '../data/models/scenario_line.dart';
import '../data/models/scenario_training_result.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/scenario_progress_repository.dart';
import 'dictionary_providers.dart';
import 'learning_hub_language_provider.dart';
import 'sentence_progress_providers.dart';
import 'swipe_progress_providers.dart';
import 'providers.dart';
import 'speech_providers.dart';
import '../core/network/apps_script_fetch.dart';
import '../core/services/audio_bytes_cache.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/dio_stream_audio_source.dart';
import '../core/services/speech_recognition_service.dart';
import '../core/constants/labels.dart';
import '../core/utils/answer_blank_hints.dart';
import '../core/utils/karaoke_word_index.dart';
import '../core/utils/scenario_answer_compare.dart';
import '../core/utils/scenario_hint_audio.dart';
import '../core/utils/word_compare.dart';
import 'tts_providers.dart';

final scenarioProgressLocalDataSourceProvider =
    Provider<ScenarioProgressLocalDataSource>(
  (ref) => ScenarioProgressLocalDataSource(),
);

final scenarioProgressRepositoryProvider =
    Provider<ScenarioProgressRepository>((ref) {
  return ScenarioProgressRepository(
    local: ref.watch(scenarioProgressLocalDataSourceProvider),
  );
});

/// 시나리오 화면 언어 탭 선택.
class ScenarioLanguageController extends Notifier<String> {
  @override
  String build() => 'English';

  void set(String language) => state = language;
}

final scenarioLanguageProvider =
    NotifierProvider<ScenarioLanguageController, String>(
  ScenarioLanguageController.new,
);

/// 전역 시나리오 진도 상태 (홈·리스트와 실시간 연동).
class ScenarioProgressState {
  final ScenarioProgressStats stats;
  final bool loading;

  const ScenarioProgressState({
    required this.stats,
    this.loading = false,
  });

  ScenarioProgressState copyWith({
    ScenarioProgressStats? stats,
    bool? loading,
  }) {
    return ScenarioProgressState(
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
    );
  }
}

class ScenarioProgressController extends Notifier<ScenarioProgressState> {
  ScenarioProgressRepository get _repo =>
      ref.read(scenarioProgressRepositoryProvider);

  @override
  ScenarioProgressState build() {
    Future.microtask(_load);
    return const ScenarioProgressState(stats: ScenarioProgressStats());
  }

  Future<void> _load() async {
    state = state.copyWith(loading: true);
    final stats = await _repo.loadStats();
    state = ScenarioProgressState(stats: stats);
  }

  Future<void> refresh() => _load();

  Future<void> markCompleted({
    required String language,
    required String scenarioId,
  }) async {
    await _repo.markCompleted(language: language, scenarioId: scenarioId);
    final stats = await _repo.loadStats();
    state = ScenarioProgressState(stats: stats);
  }

  Future<void> recordLastPerformance({
    required String language,
    required String scenarioId,
    required int score,
  }) async {
    await _repo.saveLastPerformance(
      language: language,
      scenarioId: scenarioId,
      score: score,
    );
    final stats = await _repo.loadStats();
    state = ScenarioProgressState(stats: stats);
  }

  int? lastPerformance(String language, String scenarioId) =>
      state.stats.lastPerformance(language, scenarioId);

  double progressPercent(String language, List<Scenario> scenarios) =>
      _repo.progressPercent(
        language: language,
        scenarios: scenarios,
        stats: state.stats,
      );

  double progressRatio(String language, List<Scenario> scenarios) =>
      _repo.progressRatio(
        language: language,
        scenarios: scenarios,
        stats: state.stats,
      );

  bool isCompleted(String language, String scenarioId) =>
      state.stats.isCompleted(language, scenarioId);
}

final scenarioProgressProvider =
    NotifierProvider<ScenarioProgressController, ScenarioProgressState>(
  ScenarioProgressController.new,
);

/// 현재 언어의 시나리오 목록.
final scenarioListProvider = Provider<List<Scenario>>((ref) {
  final language = ref.watch(scenarioLanguageProvider);
  final content = ref.watch(contentProvider).value;
  if (content == null) return [];
  return content.bundle
      .scenariosFor(language)
      .where((s) => !s.isSheetHeaderRow)
      .toList();
});

/// chapter_no 기준 커리큘럼 그룹.
final scenarioChapterListProvider = Provider<List<ScenarioChapter>>((ref) {
  final scenarios = ref.watch(scenarioListProvider);
  return ScenarioChapter.fromScenarios(scenarios);
});

/// 언어별 진도 요약 (홈 대시보드용).
class LanguageProgressSummary {
  final String language;
  final double percent;
  final int completed;
  final int total;

  const LanguageProgressSummary({
    required this.language,
    required this.percent,
    required this.completed,
    required this.total,
  });
}

final scenarioLanguageProgressProvider =
    Provider<List<LanguageProgressSummary>>((ref) {
  final content = ref.watch(contentProvider).value;
  final progress = ref.watch(scenarioProgressProvider);
  if (content == null) return [];

  final repo = ref.watch(scenarioProgressRepositoryProvider);
  final scenarios = content.bundle.scenarios;

  return kDictionaryLanguages.map((lang) {
    return LanguageProgressSummary(
      language: lang,
      percent: repo.progressPercent(
        language: lang,
        scenarios: scenarios,
        stats: progress.stats,
      ),
      completed: repo.completedCount(
        language: lang,
        scenarios: scenarios,
        stats: progress.stats,
      ),
      total: repo.totalCount(language: lang, scenarios: scenarios),
    );
  }).toList();
});

final scenarioOverallProgressProvider = Provider<double>((ref) {
  final content = ref.watch(contentProvider).value;
  final progress = ref.watch(scenarioProgressProvider);
  if (content == null) return 0;

  return ref.watch(scenarioProgressRepositoryProvider).overallProgressPercent(
        bundle: content.bundle,
        stats: progress.stats,
      );
});

// ---------------------------------------------------------------------------
// 훈련 세션 상태
// ---------------------------------------------------------------------------

/// 말풍선 콘텐츠 모드.
enum ChatBubbleKind {
  /// 승객: 외국어 + 한국어
  passenger,
  /// 승무원 턴: 하나의 말풍선이 힌트·정답으로 변형됨
  crewTurn,
}

/// 가이드 문구 상태 (어텐션 애니메이션 트리거용).
enum TrainingFeedback {
  start,
  wrong,
  hint,
  correct,
  listening,
}

class ChatMessage {
  final String id;
  final ScenarioLine line;
  final ChatBubbleKind kind;
  final String? spokenText;
  /// 빈칸 틀(blank_frame) 힌트를 말풍선 안에 표시.
  final bool showBlankFrame;
  /// 세 번째 힌트 — 빈칸 단어 뜻 말풍선.
  final bool showWordHints;
  /// 정답으로 전환된 상태 (맞추거나 정답 보기).
  final bool isResolved;
  /// 정답 확인 버튼으로 넘긴 경우 — Correct 뱃지와 구분.
  final bool resolvedByAnswerReveal;

  const ChatMessage({
    required this.id,
    required this.line,
    required this.kind,
    this.spokenText,
    this.showBlankFrame = false,
    this.showWordHints = false,
    this.isResolved = false,
    this.resolvedByAnswerReveal = false,
  });

  bool get isUser => kind != ChatBubbleKind.passenger;

  ChatMessage copyWith({
    String? spokenText,
    bool? showBlankFrame,
    bool? showWordHints,
    bool? isResolved,
    bool? resolvedByAnswerReveal,
    bool clearSpokenText = false,
  }) {
    return ChatMessage(
      id: id,
      line: line,
      kind: kind,
      spokenText: clearSpokenText ? null : (spokenText ?? this.spokenText),
      showBlankFrame: showBlankFrame ?? this.showBlankFrame,
      showWordHints: showWordHints ?? this.showWordHints,
      isResolved: isResolved ?? this.isResolved,
      resolvedByAnswerReveal:
          resolvedByAnswerReveal ?? this.resolvedByAnswerReveal,
    );
  }
}

class ScenarioTrainingState {
  final String scenarioId;
  final String language;
  final List<ChatMessage> messages;
  final int currentLineIndex;
  /// 힌트 단계: 1=없음, 2=TTS 가라오케, 3=빈칸틀, 4=단어 뜻.
  final int hintStage;
  static const hintStageNone = 1;
  static const hintStageAudio = 2;
  static const hintStageStructure = 3;
  static const hintStageWordMeaning = 4;
  /// TTS 가라오케로 읽고 있는 토큰. null이면 비활성.
  final int? karaokeTokenIndex;
  final int submitCount;
  final bool isListening;
  final bool isInitializingStt;
  final String spokenText;
  final double soundLevel;
  final bool isVolumeLow;
  final TrainingFeedback feedback;
  /// 영어 STT 오답 유형 (가이드 멘트 분기).
  final EnglishSpeakingWrongKind? speakingWrongKind;
  /// 오답 시 셰이크 트리거 (값이 바뀔 때마다 재생).
  final int shakeToken;
  /// 사용자가 다음 행동을 알 수 있도록 마이크를 강조하는 트리거.
  final int micAttentionToken;
  /// 힌트 2·3 공개 후 빈칸 박스를 강조하는 트리거.
  final int blankAttentionToken;
  final bool lastAttemptCorrect;
  final bool isCompleted;
  final bool isTypingMode;
  /// 힌트 빈칸 입력: 선택된 빈칸 인덱스 (없으면 null).
  final int? selectedBlankIndex;
  /// 힌트 빈칸별 입력값.
  final List<String> blankInputs;
  final ScenarioTrainingResult? result;
  final String? error;

  const ScenarioTrainingState({
    required this.scenarioId,
    required this.language,
    this.messages = const [],
    this.currentLineIndex = 0,
    this.hintStage = hintStageNone,
    this.karaokeTokenIndex,
    this.submitCount = 0,
    this.isListening = false,
    this.isInitializingStt = false,
    this.spokenText = '',
    this.soundLevel = 0,
    this.isVolumeLow = false,
    this.feedback = TrainingFeedback.start,
    this.speakingWrongKind,
    this.shakeToken = 0,
    this.micAttentionToken = 0,
    this.blankAttentionToken = 0,
    this.lastAttemptCorrect = false,
    this.isCompleted = false,
    this.isTypingMode = false,
    this.selectedBlankIndex,
    this.blankInputs = const [],
    this.result,
    this.error,
  });

  ScenarioTrainingState copyWith({
    List<ChatMessage>? messages,
    int? currentLineIndex,
    int? hintStage,
    int? karaokeTokenIndex,
    bool clearKaraoke = false,
    int? submitCount,
    bool? isListening,
    bool? isInitializingStt,
    String? spokenText,
    double? soundLevel,
    bool? isVolumeLow,
    TrainingFeedback? feedback,
    EnglishSpeakingWrongKind? speakingWrongKind,
    bool clearSpeakingWrongKind = false,
    int? shakeToken,
    int? micAttentionToken,
    int? blankAttentionToken,
    bool? lastAttemptCorrect,
    bool? isCompleted,
    bool? isTypingMode,
    int? selectedBlankIndex,
    List<String>? blankInputs,
    ScenarioTrainingResult? result,
    String? error,
    bool clearSpokenText = false,
    bool clearError = false,
    bool clearSelectedBlank = false,
  }) {
    return ScenarioTrainingState(
      scenarioId: scenarioId,
      language: language,
      messages: messages ?? this.messages,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      hintStage: hintStage ?? this.hintStage,
      karaokeTokenIndex: clearKaraoke
          ? null
          : (karaokeTokenIndex ?? this.karaokeTokenIndex),
      submitCount: submitCount ?? this.submitCount,
      isListening: isListening ?? this.isListening,
      isInitializingStt: isInitializingStt ?? this.isInitializingStt,
      spokenText: clearSpokenText ? '' : (spokenText ?? this.spokenText),
      soundLevel: soundLevel ?? this.soundLevel,
      isVolumeLow: isVolumeLow ?? this.isVolumeLow,
      feedback: feedback ?? this.feedback,
      speakingWrongKind: clearSpeakingWrongKind
          ? null
          : (speakingWrongKind ?? this.speakingWrongKind),
      shakeToken: shakeToken ?? this.shakeToken,
      micAttentionToken: micAttentionToken ?? this.micAttentionToken,
      blankAttentionToken: blankAttentionToken ?? this.blankAttentionToken,
      lastAttemptCorrect: lastAttemptCorrect ?? this.lastAttemptCorrect,
      isCompleted: isCompleted ?? this.isCompleted,
      isTypingMode: isTypingMode ?? this.isTypingMode,
      selectedBlankIndex: clearSelectedBlank
          ? null
          : (selectedBlankIndex ?? this.selectedBlankIndex),
      blankInputs: blankInputs ?? this.blankInputs,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get canRevealMoreHints => hintStage < hintStageWordMeaning;

  /// 다음에 쓸 힌트 버튼 문구.
  String get nextHintLabel => switch (hintStage) {
        <= hintStageNone => '힌트',
        hintStageAudio => '두 번째 힌트',
        _ => '세 번째 힌트',
      };

  /// 힌트가 열려 빈칸 터치 입력 모드인지.
  bool get isBlankFillMode {
    if (hintStage < hintStageStructure || isCompleted) return false;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.kind == ChatBubbleKind.crewTurn && !m.isResolved) {
        return m.showBlankFrame && m.line.blankFrame.trim().isNotEmpty;
      }
    }
    return false;
  }

  /// 활성 승무원 턴 말풍선 id (변형 대상).
  String? get activeCrewMessageId {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.kind == ChatBubbleKind.crewTurn && !m.isResolved) return m.id;
    }
    return null;
  }

  /// 마이크 상단 가이드 문구.
  String get guidanceText {
    if (isCompleted) return '';
    if (isBlankFillMode) {
      if (feedback == TrainingFeedback.wrong) {
        if (selectedBlankIndex != null) {
          return '아쉬워요! 빈칸을 다시 확인하고 입력해 보세요. 🔁';
        }
        return _wrongGuidanceText();
      }
      if (feedback == TrainingFeedback.correct) {
        return '완벽합니다! 다음 대화로 넘어갈게요. 🎉';
      }
      if (feedback == TrainingFeedback.listening) {
        return isVolumeLow
            ? '조금 더 크게 말씀해 보세요 🗣️'
            : '듣고 있어요 — 말씀이 끝나면 자동으로 채점됩니다 ✓';
      }
      if (selectedBlankIndex != null) {
        return '빈칸에 단어를 입력한 뒤 제출해 주세요.';
      }
      return '마이크 버튼을 눌러 전체 문장을 다시 말해보거나, 빈칸을 터치해서 단어를 입력해보세요.';
    }
    return switch (feedback) {
      TrainingFeedback.listening => isVolumeLow
          ? '조금 더 크게 말씀해 보세요 🗣️'
          : '듣고 있어요 — 말씀이 끝나면 자동으로 채점됩니다 ✓',
      TrainingFeedback.wrong => _wrongGuidanceText(),
      TrainingFeedback.hint => karaokeTokenIndex != null
          ? '승무원 대사를 듣고, 빈칸 문장을 따라가 보세요! ✨'
          : '제공된 힌트를 참고해서 천천히 따라 읽어보세요! ✨',
      TrainingFeedback.correct => '완벽합니다! 다음 대화로 넘어갈게요. 🎉',
      TrainingFeedback.start =>
        '위 문장을 ${languageLabel(language)}로 말해보세요! 🎙️',
    };
  }

  String _wrongGuidanceText() {
    return switch (speakingWrongKind) {
      EnglishSpeakingWrongKind.omittedWord =>
        '아쉬워요! 빠진 단어가 있어요. 빈칸을 확인하고 다시 말해보세요. 🔁',
      EnglishSpeakingWrongKind.incompleteEnding =>
        '아쉬워요! 문장 끝까지 끊기지 않게 다시 말해보세요. 🔁',
      EnglishSpeakingWrongKind.mispronunciation || null =>
        '아쉬워요! 빨간색 틀린 단어에 유의하여 다시 한번 말해보세요. 🔁',
    };
  }
}

class _ScenarioTurnAccumulator {
  final int lineOrder;
  int voiceAttempts = 0;
  int keyboardAttempts = 0;
  int hintLevel = 0;
  ScenarioResolutionMethod? resolutionMethod;

  _ScenarioTurnAccumulator(this.lineOrder);

  ScenarioTurnPerformance build() => ScenarioTurnPerformance(
        lineOrder: lineOrder,
        voiceAttempts: voiceAttempts,
        keyboardAttempts: keyboardAttempts,
        hintLevel: hintLevel,
        resolutionMethod:
            resolutionMethod ?? ScenarioResolutionMethod.answerReveal,
      );
}

class ScenarioTrainingController extends Notifier<ScenarioTrainingState> {
  static const _lowVolumeThreshold = -0.5;
  /// 문장 스피킹(SpeechPracticeController)과 동일한 VAD 파라미터.
  static const _speechThreshold = -0.35;
  static const _silenceThreshold = -1.2;
  static const _silenceHoldDuration = Duration(milliseconds: 1200);
  static const _noSpeechTimeout = Duration(seconds: 10);
  static const _enginePauseFor = Duration(milliseconds: 2800);
  static const _speechConfirmDuration = Duration(milliseconds: 450);
  static const _maxListeningDuration = Duration(seconds: 30);

  Scenario? _scenario;
  bool _sessionActive = false;
  int _msgSeq = 0;
  DateTime? _sessionStartedAt;
  DateTime? _silenceStartedAt;
  DateTime? _speechLevelAboveSince;
  Object? _maxListenToken;
  Object? _noSpeechToken;
  Timer? _partialSilenceTimer;
  DateTime? _lastPartialSpeechAt;
  String _lastPartialText = '';
  bool _hadSpeechDuringSession = false;
  bool _autoStopping = false;
  bool _restartingListen = false;
  bool _enginePauseForEnabled = false;
  ScenarioLine? _listeningLine;
  bool _gradingInProgress = false;
  final Map<int, _ScenarioTurnAccumulator> _turnPerformance = {};
  int _hintTtsGen = 0;
  Timer? _karaokeFallbackTimer;
  bool _usedNativeKaraokeProgress = false;
  StreamSubscription<Duration>? _hintAudioPositionSub;
  final Set<String> _prefetchedHintUrls = {};
  int _scenarioPrefetchGen = 0;

  List<ScenarioLine> get _lines => _scenario?.lines ?? [];

  SpeechRecognitionService get _stt =>
      ref.read(speechRecognitionServiceProvider);

  @override
  ScenarioTrainingState build() {
    ref.onDispose(() {
      _sessionActive = false;
      _hintTtsGen++;
      _karaokeFallbackTimer?.cancel();
      _hintAudioPositionSub?.cancel();
      _stt.cancelListening();
      ref.read(ttsServiceProvider).stop();
      ref.read(audioPlayerServiceProvider).stop();
    });
    return const ScenarioTrainingState(scenarioId: '', language: 'English');
  }

  void init(Scenario scenario) {
    _sessionActive = true;
    _msgSeq = 0;
    _turnPerformance.clear();
    _scenario = scenario;
    _prefetchedHintUrls.clear();
    state = ScenarioTrainingState(
      scenarioId: scenario.id,
      language: scenario.language,
    );
    unawaited(_prefetchScenarioHintAudio(scenario));
    _beginCurrentLine();
  }

  Future<void> _prefetchScenarioHintAudio(Scenario scenario) async {
    final gen = ++_scenarioPrefetchGen;

    ContentBundle? bundle = ref.read(contentProvider).value?.bundle;
    for (var attempt = 0; bundle == null && attempt < 60; attempt++) {
      if (gen != _scenarioPrefetchGen || !ref.mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      bundle = ref.read(contentProvider).value?.bundle;
    }
    if (bundle == null) return;

    final urls = <String>{};
    for (final line in scenario.lines) {
      if (!line.isCrew) continue;
      final hint = resolveScenarioHintAudio(
        line: line,
        sentences: bundle.sentences,
      );
      for (final clip in hint.clips) {
        if (clip.playbackUrl.isNotEmpty) {
          urls.add(clip.playbackUrl);
        }
      }
    }
    if (urls.isEmpty || gen != _scenarioPrefetchGen) return;

    await _prefetchHintUrls(urls);
  }

  Future<void> _prefetchHintUrls(Set<String> urls) async {
    if (urls.isEmpty) return;
    final pending = urls
        .where((url) => !_prefetchedHintUrls.contains(url))
        .toList();
    if (pending.isEmpty) return;

    if (kIsWeb) {
      await Future.wait(
        pending.map((url) async {
          try {
            await AudioBytesCache.instance.getOrFetch(url);
            _prefetchedHintUrls.add(url);
          } catch (_) {}
        }),
      );
      return;
    }

    final repo = ref.read(contentRepositoryProvider);
    await Future.wait(
      pending.map((url) async {
        try {
          await repo.cacheAudioInBackground(url);
          _prefetchedHintUrls.add(url);
        } catch (_) {}
      }),
    );
  }

  Future<void> _prefetchHintClips(List<HintAudioClip> clips) async {
    await _prefetchHintUrls(
      clips.map((clip) => clip.playbackUrl).where((url) => url.isNotEmpty).toSet(),
    );
  }

  _ScenarioTurnAccumulator _performanceFor(ScenarioLine line) =>
      _turnPerformance.putIfAbsent(
        line.order,
        () => _ScenarioTurnAccumulator(line.order),
      );

  ScenarioLine? get _currentLine {
    if (currentLineIndex >= _lines.length) return null;
    return _lines[currentLineIndex];
  }

  int get currentLineIndex => state.currentLineIndex;

  String _nextMsgId(String prefix) {
    _msgSeq++;
    return '${prefix}_$_msgSeq';
  }

  Future<void> _beginCurrentLine() async {
    // 새 시나리오의 첫 말풍선은 이전 오디오 정리 완료를 기다릴 이유가 없다.
    // 특히 웹에서는 player.stop()이 늦게 끝날 수 있어 첫 화면이 비는 원인이 된다.
    final isInitialCrewReveal =
        state.currentLineIndex == 0 && state.messages.isEmpty;
    if (isInitialCrewReveal) {
      unawaited(_stopHintTts());
    } else {
      await _stopHintTts();
    }
    final line = _currentLine;
    if (line == null) {
      await _completeScenario();
      return;
    }

    if (line.isPassenger) {
      // 말풍선 등장 + 타이핑 애니메이션이 끝날 때까지 대기 후 다음 턴.
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: _nextMsgId('pax'),
            line: line,
            kind: ChatBubbleKind.passenger,
          ),
        ],
        hintStage: ScenarioTrainingState.hintStageNone,
        submitCount: 0,
        clearSpokenText: true,
        clearKaraoke: true,
        clearError: true,
        lastAttemptCorrect: false,
        soundLevel: 0,
        isVolumeLow: false,
        feedback: TrainingFeedback.start,
      );
      await Future<void>.delayed(_passengerHoldDuration(line));
      if (!_sessionActive) return;
      await _advanceLine();
      return;
    }

    if (line.isCrew) {
      // 단일 crewTurn 말풍선 — 이후 힌트/정답이 이 말풍선 안에서 변형됨.
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: _nextMsgId('crew'),
            line: line,
            kind: ChatBubbleKind.crewTurn,
          ),
        ],
        hintStage: ScenarioTrainingState.hintStageNone,
        submitCount: 0,
        clearSpokenText: true,
        clearKaraoke: true,
        clearError: true,
        clearSelectedBlank: true,
        blankInputs: const [],
        lastAttemptCorrect: false,
        isListening: false,
        isTypingMode: false,
        soundLevel: 0,
        isVolumeLow: false,
        feedback: TrainingFeedback.start,
        micAttentionToken: state.micAttentionToken + 1,
      );
    }
  }

  /// 승객 말풍선 등장·타이핑·여유 시간을 합친 대기 시간.
  static Duration _passengerHoldDuration(ScenarioLine line) {
    const enterMs = 520;
    const pauseAfterMs = 700;
    const msPerChar = 40;
    final len = line.textTarget.length;
    final typingMs = (len * msPerChar).clamp(900, 3800);
    return Duration(milliseconds: enterMs + typingMs + pauseAfterMs);
  }

  /// 현재 미해결 crewTurn 메시지를 갱신한다.
  List<ChatMessage> _updateActiveCrew(ChatMessage Function(ChatMessage) fn) {
    final line = _currentLine;
    return [
      for (final m in state.messages)
        if (m.kind == ChatBubbleKind.crewTurn &&
            !m.isResolved &&
            line != null &&
            m.line.order == line.order &&
            m.line.scenarioId == line.scenarioId)
          fn(m)
        else
          m,
    ];
  }

  Future<void> _advanceLine() async {
    if (!_sessionActive) return;
    final next = state.currentLineIndex + 1;
    state = state.copyWith(currentLineIndex: next);
    await _beginCurrentLine();
  }

  void _clearVadTimers({bool resetSession = true}) {
    _silenceStartedAt = null;
    _speechLevelAboveSince = null;
    _maxListenToken = null;
    _noSpeechToken = null;
    _lastPartialSpeechAt = null;
    _lastPartialText = '';
    _partialSilenceTimer?.cancel();
    _partialSilenceTimer = null;
    _hadSpeechDuringSession = false;
    _autoStopping = false;
    _restartingListen = false;
    _enginePauseForEnabled = false;
    _listeningLine = null;
    if (resetSession) {
      _sessionStartedAt = null;
    }
  }

  bool get _canAutoStopNow => _hadSpeechDuringSession;

  void _onSpeechDetected() {
    if (_hadSpeechDuringSession) return;
    _hadSpeechDuringSession = true;
    _noSpeechToken = null;
    _silenceStartedAt = null;
    _partialSilenceTimer?.cancel();
    if (!_enginePauseForEnabled) {
      _enginePauseForEnabled = true;
      _stt.changePauseFor(_enginePauseFor);
    }
  }

  Duration get _remainingNoSpeechWindow {
    if (_sessionStartedAt == null) return Duration.zero;
    final remaining = _noSpeechTimeout - DateTime.now().difference(_sessionStartedAt!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get _remainingListenWindow {
    if (_sessionStartedAt == null) return _maxListeningDuration;
    final remaining =
        _maxListeningDuration - DateTime.now().difference(_sessionStartedAt!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _handleEngineStatus(String status) {
    final line = _listeningLine;
    if (line == null || !state.isListening) return;
    if (_autoStopping || _restartingListen || _hadSpeechDuringSession) return;
    if (status != 'done' && status != 'notListening') return;

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!ref.mounted) return;
      unawaited(_maybeRestartListening(line));
    });
  }

  Future<void> _maybeRestartListening(ScenarioLine line) async {
    if (!state.isListening || _autoStopping || _restartingListen) return;
    if (_hadSpeechDuringSession) return;
    if (_listeningLine?.order != line.order) return;

    final noSpeechLeft = _remainingNoSpeechWindow;
    if (noSpeechLeft <= Duration.zero) {
      await _abortListeningNoSpeech();
      return;
    }

    final listenFor = _remainingListenWindow;
    if (listenFor <= Duration.zero) {
      await _abortListeningNoSpeech();
      return;
    }

    _restartingListen = true;
    try {
      await _stt.startListening(
        localeId: speechLocaleFor(line.language),
        listenFor: listenFor,
        onSoundLevelChange: (level) => _handleSoundLevel(line, level),
        onResult: (text, {required bool isFinal}) =>
            _handleListenResult(line, text, isFinal: isFinal),
      );
    } catch (e) {
      if (ref.mounted && state.isListening && !_hadSpeechDuringSession) {
        state = state.copyWith(
          isListening: false,
          error: '음성 인식 재시작 실패: $e',
          feedback: state.isBlankFillMode
              ? TrainingFeedback.hint
              : TrainingFeedback.start,
        );
      }
    } finally {
      _restartingListen = false;
    }
  }

  void _handleListenResult(
    ScenarioLine line,
    String text, {
    required bool isFinal,
  }) {
    if (!state.isListening || _listeningLine?.order != line.order) return;

    if (isFinal) {
      _partialSilenceTimer?.cancel();
      if (_autoStopping || _gradingInProgress) return;
      _clearVadTimers();
      if (!_hadSpeechDuringSession && text.trim().isEmpty) {
        unawaited(_maybeRestartListening(line));
        return;
      }
      unawaited(_onSttFinal(text, line));
      return;
    }

    state = state.copyWith(spokenText: text);
    _handlePartialSpeech(text);
  }

  void _scheduleNoSpeechTimeout() {
    final token = Object();
    _noSpeechToken = token;
    Future<void>.delayed(_noSpeechTimeout, () {
      if (!ref.mounted) return;
      if (_noSpeechToken != token) return;
      if (!state.isListening) return;
      if (_hadSpeechDuringSession) return;
      unawaited(_abortListeningNoSpeech());
    });
  }

  void _scheduleMaxListeningTimeout() {
    final token = Object();
    _maxListenToken = token;
    Future<void>.delayed(_maxListeningDuration, () {
      if (!ref.mounted) return;
      if (_maxListenToken != token) return;
      if (!state.isListening) return;
      if (!_hadSpeechDuringSession) {
        unawaited(_abortListeningNoSpeech());
        return;
      }
      unawaited(_triggerAutoStop());
    });
  }

  void _handleSoundLevel(ScenarioLine line, double level) {
    if (!state.isListening || _listeningLine?.order != line.order) return;

    state = state.copyWith(
      soundLevel: level,
      isVolumeLow: level < _lowVolumeThreshold,
      feedback: TrainingFeedback.listening,
    );

    final now = DateTime.now();

    if (level > _speechThreshold) {
      _speechLevelAboveSince ??= now;
      if (now.difference(_speechLevelAboveSince!) >= _speechConfirmDuration) {
        _onSpeechDetected();
      }
      return;
    }

    _speechLevelAboveSince = null;

    if (level > _silenceThreshold) {
      _silenceStartedAt = null;
      return;
    }

    if (!_canAutoStopNow) return;

    _silenceStartedAt ??= now;
    if (now.difference(_silenceStartedAt!) >= _silenceHoldDuration) {
      unawaited(_triggerAutoStop());
    }
  }

  void _handlePartialSpeech(String text) {
    if (!state.isListening) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _lastPartialText) return;
    if (_lastPartialText.isEmpty && trimmed.length < 3) return;

    final now = DateTime.now();
    _onSpeechDetected();
    _lastPartialText = trimmed;
    _lastPartialSpeechAt = now;
    _silenceStartedAt = null;

    _partialSilenceTimer?.cancel();
    _partialSilenceTimer = Timer(_silenceHoldDuration, () {
      if (!ref.mounted || !state.isListening || _autoStopping) return;
      if (_lastPartialSpeechAt == null) return;
      if (!_canAutoStopNow) return;
      if (DateTime.now().difference(_lastPartialSpeechAt!) <
          _silenceHoldDuration) {
        return;
      }
      unawaited(_triggerAutoStop());
    });
  }

  Future<void> _triggerAutoStop() async {
    if (_autoStopping || !state.isListening) return;
    if (!_canAutoStopNow) return;
    _autoStopping = true;
    try {
      await submitSpeaking();
    } finally {
      _autoStopping = false;
    }
  }

  Future<void> _abortListeningNoSpeech() async {
    if (!state.isListening) return;
    await _stt.cancelListening();
    _clearVadTimers();
    state = state.copyWith(
      isListening: false,
      isInitializingStt: false,
      soundLevel: 0,
      isVolumeLow: false,
      clearSpokenText: true,
      feedback: state.isBlankFillMode
          ? TrainingFeedback.hint
          : TrainingFeedback.start,
    );
  }

  Future<void> toggleMic() async {
    final line = _currentLine;
    if (line == null || !line.isCrew || state.isCompleted) return;

    if (state.isListening) {
      await submitSpeaking();
      return;
    }

    await _stopHintTts();

    state = state.copyWith(
      isInitializingStt: true,
      clearSpokenText: true,
      clearKaraoke: true,
      clearSpeakingWrongKind: true,
      clearSelectedBlank: true,
      clearError: true,
      soundLevel: 0,
      isVolumeLow: false,
      isTypingMode: false,
    );

    final available = await _stt.initialize(onStatus: _handleEngineStatus);
    if (!available) {
      state = state.copyWith(
        isInitializingStt: false,
        error: '음성 인식을 사용할 수 없습니다.',
      );
      return;
    }

    state = state.copyWith(
      isInitializingStt: false,
      isListening: true,
      feedback: TrainingFeedback.listening,
    );

    _clearVadTimers();
    _sessionStartedAt = DateTime.now();
    _listeningLine = line;
    _scheduleMaxListeningTimeout();
    _scheduleNoSpeechTimeout();

    try {
      await _stt.startListening(
        localeId: speechLocaleFor(line.language),
        listenFor: _maxListeningDuration,
        onSoundLevelChange: (level) => _handleSoundLevel(line, level),
        onResult: (text, {required bool isFinal}) =>
            _handleListenResult(line, text, isFinal: isFinal),
      );
    } catch (e) {
      _clearVadTimers();
      state = state.copyWith(
        isListening: false,
        error: '음성 인식 시작 실패: $e',
        feedback: state.isBlankFillMode
            ? TrainingFeedback.hint
            : TrainingFeedback.start,
      );
    }
  }

  /// 녹음 중 즉시 제출·채점 (VAD 자동 제출 또는 사용자가 마이크 재탭).
  Future<void> submitSpeaking() async {
    if (!state.isListening || state.isCompleted) return;
    final line = _currentLine;
    if (line == null || !line.isCrew) return;

    _clearVadTimers();
    await _stt.stopListening();
    state = state.copyWith(isListening: false);
    final text = state.spokenText;
    await _onSttFinal(text, line);
  }

  /// 타이핑 모드 토글. 힌트 빈칸 모드에서는 첫 빈칸을 선택한다.
  Future<void> setTypingMode(bool enabled) async {
    if (state.isCompleted) return;
    if (enabled && state.isListening) {
      _clearVadTimers();
      await _stt.cancelListening();
    }

    await _stopHintTts();

    if (enabled && state.isBlankFillMode) {
      final idx = state.selectedBlankIndex ?? _firstEmptyBlankIndex() ?? 0;
      selectBlank(idx);
      return;
    }

    state = state.copyWith(
      isTypingMode: enabled,
      isListening: false,
      soundLevel: 0,
      isVolumeLow: false,
      clearSpokenText: enabled,
      clearKaraoke: true,
      clearError: true,
      clearSelectedBlank: true,
      feedback: TrainingFeedback.start,
    );
  }

  /// 힌트 빈칸(런) 선택.
  void selectBlank(int runIndex) {
    if (!state.isBlankFillMode || state.isCompleted) return;
    final inputs = List<String>.from(state.blankInputs);
    if (runIndex < 0 || runIndex >= inputs.length) return;
    state = state.copyWith(
      selectedBlankIndex: runIndex,
      isTypingMode: true,
      isListening: false,
      spokenText: inputs[runIndex],
      feedback: TrainingFeedback.hint,
      clearError: true,
    );
  }

  /// 선택된 빈칸 런 텍스트 갱신.
  void updateBlankTypedText(String text) {
    if (!state.isBlankFillMode || state.selectedBlankIndex == null) return;
    final idx = state.selectedBlankIndex!;
    final inputs = List<String>.from(state.blankInputs);
    if (idx < 0 || idx >= inputs.length) return;
    inputs[idx] = text;
    state = state.copyWith(
      blankInputs: inputs,
      spokenText: text,
      clearError: true,
    );
  }

  /// 타이핑 중 실시간 텍스트 (언더라인 힌트 갱신).
  void updateTypedText(String text) {
    if (state.isBlankFillMode) {
      updateBlankTypedText(text);
      return;
    }
    if (!state.isTypingMode || state.isCompleted) return;
    state = state.copyWith(spokenText: text, clearError: true);
  }

  /// 타이핑 답안 제출.
  Future<void> submitTypedAnswer() async {
    if (state.isCompleted) return;
    final line = _currentLine;
    if (line == null || !line.isCrew) return;

    if (state.isBlankFillMode) {
      await _submitSelectedBlank(line);
      return;
    }
    if (!state.isTypingMode) return;
    await _onSttFinal(state.spokenText, line);
  }

  int? _firstEmptyBlankIndex() {
    for (var i = 0; i < state.blankInputs.length; i++) {
      if (state.blankInputs[i].trim().isEmpty) return i;
    }
    return state.blankInputs.isEmpty ? null : 0;
  }

  List<String> _keyWordsFor(ScenarioLine line) {
    return AnswerBlankHints.extractKeyWordList(
      correct: line.textTarget,
      blankFrame: line.blankFrame,
      language: line.language,
    );
  }

  List<List<int>> _keyRunsFor(ScenarioLine line) {
    return AnswerBlankHints.contiguousKeyRuns(
      correct: line.textTarget,
      blankFrame: line.blankFrame,
      language: line.language,
    );
  }

  bool _isBlankWordCorrect({
    required String spoken,
    required String expected,
    required String language,
  }) {
    final a = AnswerBlankHints.matchLetters(spoken, language: language).join();
    final b = AnswerBlankHints.matchLetters(expected, language: language).join();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (language == 'English') {
      final sw = WordCompare.splitWords(spoken).map(WordCompare.normalize);
      final ew = WordCompare.splitWords(expected).map(WordCompare.normalize);
      if (sw.length == ew.length) {
        final pairs = sw.toList();
        final exp = ew.toList();
        var ok = true;
        for (var i = 0; i < pairs.length; i++) {
          if (pairs[i] != exp[i]) {
            ok = false;
            break;
          }
        }
        if (ok) return true;
      }
      return WordCompare.normalize(spoken) == WordCompare.normalize(expected);
    }
    return a.contains(b) || b.contains(a);
  }

  Future<void> _submitSelectedBlank(ScenarioLine line) async {
    final idx = state.selectedBlankIndex;
    if (idx == null) {
      state = state.copyWith(
        error: '먼저 빈칸을 터치해 주세요.',
        feedback: TrainingFeedback.hint,
      );
      return;
    }
    final runs = _keyRunsFor(line);
    if (idx < 0 || idx >= runs.length) return;

    final expected = AnswerBlankHints.runAnswerText(
      correct: line.textTarget,
      blankFrame: line.blankFrame,
      language: line.language,
      keyIndices: runs[idx],
    );

    final spoken = idx < state.blankInputs.length
        ? state.blankInputs[idx]
        : state.spokenText;
    if (spoken.trim().isEmpty) {
      state = state.copyWith(
        error: '단어를 입력하거나 녹음해 주세요.',
        feedback: TrainingFeedback.hint,
      );
      return;
    }

    final performance = _performanceFor(line);
    performance.keyboardAttempts++;
    final ok = _isBlankWordCorrect(
      spoken: spoken,
      expected: expected,
      language: line.language,
    );
    final nextSubmitCount = state.submitCount + 1;

    if (!ok) {
      state = state.copyWith(
        submitCount: nextSubmitCount,
        lastAttemptCorrect: false,
        feedback: TrainingFeedback.wrong,
        shakeToken: state.shakeToken + 1,
        clearError: true,
      );
      return;
    }

    final inputs = List<String>.from(state.blankInputs);
    inputs[idx] = expected;
    final allDone = List.generate(runs.length, (i) {
      final exp = AnswerBlankHints.runAnswerText(
        correct: line.textTarget,
        blankFrame: line.blankFrame,
        language: line.language,
        keyIndices: runs[i],
      );
      return _isBlankWordCorrect(
        spoken: inputs[i],
        expected: exp,
        language: line.language,
      );
    }).every((e) => e);

    final allKeys = _keyWordsFor(line);

    if (allDone) {
      performance.resolutionMethod = ScenarioResolutionMethod.keyboard;
      state = state.copyWith(
        submitCount: nextSubmitCount,
        lastAttemptCorrect: true,
        blankInputs: inputs,
        isTypingMode: false,
        isListening: false,
        clearSelectedBlank: true,
        spokenText: allKeys.join(' '),
        messages: _updateActiveCrew(
          (m) => m.copyWith(
            isResolved: true,
            showBlankFrame: false,
            spokenText: allKeys.join(' '),
          ),
        ),
        feedback: TrainingFeedback.correct,
        clearError: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_sessionActive) return;
      await _advanceLine();
      return;
    }

    final nextIdx = () {
      for (var i = 0; i < inputs.length; i++) {
        final exp = AnswerBlankHints.runAnswerText(
          correct: line.textTarget,
          blankFrame: line.blankFrame,
          language: line.language,
          keyIndices: runs[i],
        );
        if (!_isBlankWordCorrect(
          spoken: inputs[i],
          expected: exp,
          language: line.language,
        )) {
          return i;
        }
      }
      return null;
    }();

    state = state.copyWith(
      submitCount: nextSubmitCount,
      blankInputs: inputs,
      selectedBlankIndex: nextIdx,
      isTypingMode: nextIdx != null,
      spokenText: nextIdx != null ? inputs[nextIdx] : '',
      feedback: TrainingFeedback.hint,
      clearError: true,
    );
  }

  /// 힌트 보기 — 1차: TTS 가라오케 / 2차: blank_frame / 3차: 빈칸 단어 뜻.
  void revealNextHint() {
    if (!state.canRevealMoreHints || state.isCompleted) return;
    final line = _currentLine;
    if (line == null || !line.isCrew) return;

    if (state.hintStage < ScenarioTrainingState.hintStageAudio) {
      _performanceFor(line).hintLevel =
          math.max(_performanceFor(line).hintLevel, 1);
      final hintAudio = _resolveHintAudio(line);
      final initialKaraoke = hintAudio.clips.isNotEmpty
          ? hintAudio.clips.first.karaokeTokenStart
          : 0;
      state = state.copyWith(
        hintStage: ScenarioTrainingState.hintStageAudio,
        karaokeTokenIndex: initialKaraoke,
        isListening: false,
        clearSpokenText: true,
        feedback: TrainingFeedback.hint,
        clearError: true,
      );
      unawaited(_playHintTts(line));
      return;
    }

    unawaited(_stopHintTts());

    if (state.hintStage < ScenarioTrainingState.hintStageStructure) {
      _performanceFor(line).hintLevel =
          math.max(_performanceFor(line).hintLevel, 2);
      final runs = line.blankFrame.trim().isEmpty
          ? const <List<int>>[]
          : _keyRunsFor(line);

      state = state.copyWith(
        hintStage: ScenarioTrainingState.hintStageStructure,
        messages: _updateActiveCrew(
          (m) => m.copyWith(showBlankFrame: true),
        ),
        blankInputs: List<String>.filled(runs.length, ''),
        clearSelectedBlank: true,
        clearKaraoke: true,
        isTypingMode: false,
        isListening: false,
        clearSpokenText: true,
        feedback: TrainingFeedback.hint,
        clearError: true,
        micAttentionToken: state.micAttentionToken + 1,
        blankAttentionToken: state.blankAttentionToken + 1,
      );
      return;
    }

    _performanceFor(line).hintLevel =
        math.max(_performanceFor(line).hintLevel, 3);
    state = state.copyWith(
      hintStage: ScenarioTrainingState.hintStageWordMeaning,
      messages: _updateActiveCrew(
        (m) => m.copyWith(showWordHints: true),
      ),
      clearKaraoke: true,
      feedback: TrainingFeedback.hint,
      clearError: true,
      micAttentionToken: state.micAttentionToken + 1,
      blankAttentionToken: state.blankAttentionToken + 1,
    );
  }

  Future<void> _stopHintTts() async {
    _hintTtsGen++;
    _usedNativeKaraokeProgress = false;
    _karaokeFallbackTimer?.cancel();
    _karaokeFallbackTimer = null;
    await _hintAudioPositionSub?.cancel();
    _hintAudioPositionSub = null;
    await ref.read(ttsServiceProvider).stop();
    await ref.read(audioPlayerServiceProvider).stop();
  }

  ScenarioHintAudio _resolveHintAudio(ScenarioLine line) {
    final bundle = ref.read(contentProvider).value?.bundle;
    return resolveScenarioHintAudio(
      line: line,
      sentences: bundle?.sentences ?? const [],
    );
  }

  Future<void> _playHintTts(ScenarioLine line) async {
    final gen = ++_hintTtsGen;
    _usedNativeKaraokeProgress = false;
    _karaokeFallbackTimer?.cancel();
    _karaokeFallbackTimer = null;
    await _hintAudioPositionSub?.cancel();
    _hintAudioPositionSub = null;
    var finished = false;

    try {
      final hintAudio = _resolveHintAudio(line);
      if (hintAudio.isAvailable) {
        final played = await _playHintRecordingChain(line, hintAudio, gen);
        if (played) return;
        debugPrint('힌트 녹음 클립은 찾았지만 재생 실패 — 전체 TTS 폴백 생략');
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (finished || gen != _hintTtsGen || !ref.mounted) return;
        if (_usedNativeKaraokeProgress) return;
        _startKaraokeFallback(line, gen);
      });
      await _speakHintWithBuiltInTts(line, gen);
    } finally {
      finished = true;
      if (gen == _hintTtsGen) {
        _karaokeFallbackTimer?.cancel();
        _karaokeFallbackTimer = null;
        await _hintAudioPositionSub?.cancel();
        _hintAudioPositionSub = null;
        if (ref.mounted) {
          state = state.copyWith(
            clearKaraoke: true,
            // 힌트 1의 오디오/TTS가 모두 끝난 뒤에만 다시 말하기를 유도한다.
            micAttentionToken:
                state.hintStage == ScenarioTrainingState.hintStageAudio
                ? state.micAttentionToken + 1
                : state.micAttentionToken,
          );
        }
      }
    }
  }

  Future<bool> _playHintRecordingChain(
    ScenarioLine line,
    ScenarioHintAudio hintAudio,
    int gen,
  ) async {
    if (hintAudio.clips.length > 1) {
      return _playHintRecordingConcatenated(line, hintAudio, gen);
    }
    if (hintAudio.clips.length == 1) {
      return _playHintClip(line, hintAudio.clips.single, gen);
    }
    return false;
  }

  Future<AudioSource> _audioSourceForHintClip(
    HintAudioClip clip,
    ContentRepository repo,
  ) async {
    final url = clip.playbackUrl;
    if (!kIsWeb) {
      final localPath =
          await repo.cachedAudioPath(url) ?? await repo.localAudioPath(url);
      if (localPath != null) {
        return AudioSource.file(localPath);
      }
    }

    if (kIsWeb || AppsScriptFetch.isWebAppUrl(url)) {
      return DioStreamAudioSource(url);
    }
    return AudioSource.uri(Uri.parse(url));
  }

  Future<void> _waitForPlayerReady(
    AudioPlayerService service, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await service.playerStateStream
        .firstWhere(
          (state) =>
              state.processingState == ProcessingState.ready ||
              state.processingState == ProcessingState.completed,
        )
        .timeout(timeout);
  }

  Future<List<Duration>> _resolveClipDurations(
    AudioPlayerService service,
    int clipCount,
  ) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final fromSequence = service.sequence
          .map((source) => source.duration ?? Duration.zero)
          .toList();
      if (fromSequence.length >= clipCount &&
          fromSequence.take(clipCount).every((d) => d.inMilliseconds > 0)) {
        return fromSequence.take(clipCount).toList();
      }

      final total = await service.resolveDuration();
      if (total.inMilliseconds > 0 && clipCount == 1) {
        return [total];
      }

      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return List<Duration>.filled(clipCount, Duration.zero);
  }

  Future<bool> _waitForHintPlaybackEnd(
    AudioPlayerService service,
    int gen, {
    required int expectedTotalMs,
  }) async {
    final timeoutMs = expectedTotalMs > 0 ? expectedTotalMs + 12000 : 90000;
    final done = Completer<void>();
    late StreamSubscription<PlayerState> stateSub;
    late StreamSubscription<Duration> positionSub;

    void tryComplete() {
      if (done.isCompleted) return;
      if (gen != _hintTtsGen) {
        done.complete();
        return;
      }
      final posMs = service.position.inMilliseconds;
      if (expectedTotalMs > 0 && posMs >= expectedTotalMs - 120) {
        done.complete();
      }
    }

    stateSub = service.playerStateStream.listen((playerState) {
      if (gen != _hintTtsGen) {
        done.complete();
        return;
      }
      if (playerState.processingState == ProcessingState.completed) {
        done.complete();
        return;
      }
      if (!playerState.playing &&
          expectedTotalMs > 0 &&
          service.position.inMilliseconds >= expectedTotalMs - 250) {
        done.complete();
      }
    });

    positionSub = service.positionStream.listen((_) => tryComplete());

    try {
      await done.future.timeout(Duration(milliseconds: timeoutMs));
    } on TimeoutException {
      // 재생은 끝났을 가능성이 큼 — TTS 폴백으로 넘기지 않는다.
    } finally {
      await stateSub.cancel();
      await positionSub.cancel();
    }

    return gen == _hintTtsGen && ref.mounted;
  }

  int _resolveKaraokePositionMs({
    required AudioPlayerService service,
    required Stopwatch stopwatch,
    required Duration playbackAnchor,
    List<Duration>? clipDurations,
    required int maxPosMs,
  }) {
    final watchMs = playbackAnchor.inMilliseconds + stopwatch.elapsedMilliseconds;

    if (clipDurations != null && clipDurations.length > 1) {
      final index = service.currentIndex ?? 0;
      var offsetMs = 0;
      for (var i = 0; i < index && i < clipDurations.length; i++) {
        offsetMs += clipDurations[i].inMilliseconds;
      }
      // ConcatenatingAudioSource는 클립 전환 시 position이 0으로 리셋될 수 있다.
      final estimatedMs = offsetMs + service.position.inMilliseconds;
      if (estimatedMs + 120 < maxPosMs) {
        return math.max(maxPosMs, watchMs);
      }
      return math.max(maxPosMs, estimatedMs);
    }

    final playerMs = service.position.inMilliseconds;
    final estimatedMs = playerMs > playbackAnchor.inMilliseconds + 50
        ? playerMs
        : watchMs;
    return math.max(maxPosMs, estimatedMs);
  }

  void _startRecordedKaraoke({
    required int gen,
    required AudioPlayerService service,
    required Stopwatch stopwatch,
    required Duration playbackAnchor,
    required List<({HintAudioClip clip, Duration start, Duration end})> segments,
    List<Duration>? clipDurations,
  }) {
    _karaokeFallbackTimer?.cancel();
    if (segments.isEmpty) return;

    _usedNativeKaraokeProgress = true;
    var maxPosMs = 0;
    _karaokeFallbackTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (gen != _hintTtsGen || !ref.mounted) {
        t.cancel();
        return;
      }

      final posMs = _resolveKaraokePositionMs(
        service: service,
        stopwatch: stopwatch,
        playbackAnchor: playbackAnchor,
        clipDurations: clipDurations,
        maxPosMs: maxPosMs,
      );
      maxPosMs = posMs;
      for (final segment in segments) {
        final startMs = segment.start.inMilliseconds;
        final endMs = segment.end.inMilliseconds;
        if (endMs <= startMs || posMs < startMs || posMs >= endMs) {
          continue;
        }

        _usedNativeKaraokeProgress = true;
        final spanMs = endMs - startMs;
        final elapsedMs = (posMs - startMs).clamp(0, spanMs);
        final ratio = elapsedMs / spanMs;
        final tokenCount = segment.clip.karaokeTokenCount;
        if (tokenCount <= 0) return;

        final localIdx = (ratio * tokenCount)
            .floor()
            .clamp(0, math.max(0, tokenCount - 1))
            .toInt();
        final globalIdx = segment.clip.karaokeTokenStart + localIdx;
        if (globalIdx != state.karaokeTokenIndex) {
          state = state.copyWith(karaokeTokenIndex: globalIdx);
        }
        return;
      }
    });
  }

  Future<bool> _playHintRecordingConcatenated(
    ScenarioLine line,
    ScenarioHintAudio hintAudio,
    int gen,
  ) async {
    if (gen != _hintTtsGen || !ref.mounted) return false;

    try {
      // 웹 just_audio의 ConcatenatingAudioSource는 클립 전환 때 position과
      // currentIndex가 비동기적으로 갱신돼 두 번째 문장의 가라오케 기준이
      // 흔들릴 수 있다. 각 녹음을 독립 재생해 그 클립의 시간축만 사용한다.
      for (final clip in hintAudio.clips) {
        final played = await _playHintClip(line, clip, gen);
        if (!played || gen != _hintTtsGen || !ref.mounted) return false;
      }
      return true;
    } catch (e, st) {
      debugPrint('힌트 연속 녹음 재생 실패');
      debugPrint('$e\n$st');
      await ref.read(audioPlayerServiceProvider).stop();
      return false;
    }
  }

  Future<bool> _playHintClip(
    ScenarioLine line,
    HintAudioClip clip,
    int gen,
  ) async {
    if (gen != _hintTtsGen || !ref.mounted) return false;

    final service = ref.read(audioPlayerServiceProvider);
    final repo = ref.read(contentRepositoryProvider);

    try {
      await ref.read(audioProvider.notifier).stop();
      await _hintAudioPositionSub?.cancel();
      _hintAudioPositionSub = null;

      if (ref.mounted) {
        state = state.copyWith(karaokeTokenIndex: clip.karaokeTokenStart);
      }

      unawaited(_prefetchHintClips([clip]));
      if (gen != _hintTtsGen || !ref.mounted) return false;

      final source = await _audioSourceForHintClip(clip, repo);
      await service.loadConcatenating([source]);
      await _waitForPlayerReady(service);

      final duration = await _resolveClipDurations(service, 1).then(
        (durations) => durations.isNotEmpty ? durations.first : Duration.zero,
      );
      final (segmentStart, segmentEnd) = clip.segment.resolveBounds(duration);
      if (segmentStart.inMilliseconds > 0) {
        await service.seek(segmentStart);
      }

      final stopwatch = Stopwatch()..start();
      await service.startPlayback();
      if (gen != _hintTtsGen || !ref.mounted) return false;

      _startRecordedKaraoke(
        gen: gen,
        service: service,
        stopwatch: stopwatch,
        playbackAnchor: segmentStart,
        segments: [
          (clip: clip, start: segmentStart, end: segmentEnd),
        ],
      );
      if (segmentEnd.inMilliseconds <= segmentStart.inMilliseconds) {
        _startKaraokeFallback(line, gen);
      }

      final segmentMs = segmentEnd.inMilliseconds - segmentStart.inMilliseconds;
      return await _waitForHintPlaybackEnd(
        service,
        gen,
        expectedTotalMs: segmentMs > 0 ? segmentEnd.inMilliseconds : duration.inMilliseconds,
      );
    } catch (e, st) {
      debugPrint('힌트 녹음 재생 실패: ${clip.playbackUrl}');
      debugPrint('$e\n$st');
      await service.stop();
      return false;
    }
  }

  Future<void> _speakHintWithBuiltInTts(ScenarioLine line, int gen) async {
    await ref.read(ttsServiceProvider).speakWithProgress(
      line.textTarget,
      language: line.language,
      onProgress: (start, end, word) {
        if (gen != _hintTtsGen || !ref.mounted) return;
        if (!_usedNativeKaraokeProgress) {
          _usedNativeKaraokeProgress = true;
          _karaokeFallbackTimer?.cancel();
          _karaokeFallbackTimer = null;
        }
        final idx = KaraokeWordIndex.resolveFromOffset(
          sentence: line.textTarget,
          language: line.language,
          startOffset: start,
        );
        if (idx == null || idx == state.karaokeTokenIndex) return;
        state = state.copyWith(karaokeTokenIndex: idx);
      },
    );
  }

  void _startKaraokeFallback(ScenarioLine line, int gen) {
    _karaokeFallbackTimer?.cancel();
    final tokens = WordCompare.splitTokens(
      line.textTarget,
      language: line.language,
    );
    if (tokens.isEmpty) return;

    final msPer = WordCompare.isCjkLanguage(line.language) ? 210 : 300;
    var idx = 0;
    if (ref.mounted && state.karaokeTokenIndex != 0) {
      state = state.copyWith(karaokeTokenIndex: 0);
    }
    _karaokeFallbackTimer = Timer.periodic(Duration(milliseconds: msPer), (t) {
      if (gen != _hintTtsGen || !ref.mounted) {
        t.cancel();
        return;
      }
      idx++;
      if (idx >= tokens.length) {
        t.cancel();
        return;
      }
      state = state.copyWith(karaokeTokenIndex: idx);
    });
  }

  /// 정답 보기 — 같은 말풍선을 정답으로 변형 후 다음 턴.
  Future<void> revealAnswerAndSkip() async {
    if (state.isCompleted) return;
    final line = _currentLine;
    if (line == null || !line.isCrew) return;

    if (state.isListening) {
      _clearVadTimers();
      await _stt.cancelListening();
    }

    await _stopHintTts();

    _performanceFor(line).resolutionMethod =
        ScenarioResolutionMethod.answerReveal;
    _performanceFor(line)
      ..voiceAttempts = 0
      ..keyboardAttempts = 0;
    state = state.copyWith(
      isListening: false,
      isTypingMode: false,
      soundLevel: 0,
      isVolumeLow: false,
      hintStage: ScenarioTrainingState.hintStageStructure,
      messages: _updateActiveCrew(
        (m) => m.copyWith(
          isResolved: true,
          showBlankFrame: false,
          resolvedByAnswerReveal: true,
        ),
      ),
      clearKaraoke: true,
      feedback: TrainingFeedback.hint,
      clearError: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!_sessionActive) return;
    await _advanceLine();
  }

  Future<void> _onSttFinal(String text, ScenarioLine line) async {
    if (state.isCompleted || _gradingInProgress) return;
    _gradingInProgress = true;

    final wasTyping = state.isTypingMode;
    final hintShown = state.hintStage >= ScenarioTrainingState.hintStageStructure;

    state = state.copyWith(
      isListening: false,
      isTypingMode: false,
      soundLevel: 0,
      isVolumeLow: false,
    );

    if (text.trim().isEmpty) {
      state = state.copyWith(
        error: '인식된 음성이 없습니다. 다시 시도해 주세요.',
        feedback: TrainingFeedback.start,
      );
      _gradingInProgress = false;
      return;
    }

    final performance = _performanceFor(line);
    if (wasTyping) {
      performance.keyboardAttempts++;
    } else {
      performance.voiceAttempts++;
    }
    final nextSubmitCount = state.submitCount + 1;
    // 키보드 + 힌트: 주요 단어만 / 음성: 풀 문장
    final correct = ScenarioAnswerCompare.isCorrect(
      spoken: text,
      correct: line.textTarget,
      language: line.language,
      blankFrame: line.blankFrame,
      keyWordsOnly: wasTyping && hintShown && line.blankFrame.trim().isNotEmpty,
    );

    if (correct) {
      performance.resolutionMethod = wasTyping
          ? ScenarioResolutionMethod.keyboard
          : ScenarioResolutionMethod.voice;
      state = state.copyWith(
        submitCount: nextSubmitCount,
        lastAttemptCorrect: true,
        spokenText: text,
        messages: _updateActiveCrew(
          (m) => m.copyWith(
            isResolved: true,
            showBlankFrame: false,
            spokenText: text,
          ),
        ),
        feedback: TrainingFeedback.correct,
        clearSpeakingWrongKind: true,
        clearError: true,
      );
      _gradingInProgress = false;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_sessionActive) return;
      await _advanceLine();
      return;
    }

    // 오답: 같은 말풍선에 spoken 피드백 유지 + 셰이크.
    final wrongKind = line.language == 'English'
        ? AnswerBlankHints.classifyEnglishSpeakingWrong(
            correct: line.textTarget,
            spoken: text,
          )
        : null;
    state = state.copyWith(
      submitCount: nextSubmitCount,
      lastAttemptCorrect: false,
      spokenText: text,
      messages: _updateActiveCrew((m) => m.copyWith(spokenText: text)),
      feedback: TrainingFeedback.wrong,
      speakingWrongKind: wrongKind,
      shakeToken: state.shakeToken + 1,
      clearSelectedBlank: state.isBlankFillMode,
      isTypingMode: false,
      clearError: true,
    );
    _gradingInProgress = false;
  }

  Future<void> _completeScenario() async {
    final result = ScenarioTrainingResult(
      turns: [
        for (final line in _lines.where((line) => line.isCrew))
          _performanceFor(line).build(),
      ],
    );
    state = state.copyWith(isCompleted: true, result: result);
    await ref.read(scenarioProgressProvider.notifier).recordLastPerformance(
          language: state.language,
          scenarioId: state.scenarioId,
          score: result.score,
        );
    await ref.read(scenarioProgressProvider.notifier).markCompleted(
          language: state.language,
          scenarioId: state.scenarioId,
        );
  }

  /// TTS·STT 등 오디오 리소스를 즉시 해제한다.
  Future<void> stopAll() async {
    _sessionActive = false;
    await _stopHintTts();
    _clearVadTimers();
    await _stt.cancelListening();
    state = state.copyWith(
      isListening: false,
      isInitializingStt: false,
      soundLevel: 0,
      isVolumeLow: false,
      clearSpokenText: true,
      clearKaraoke: true,
      clearError: true,
    );
  }

  ScenarioLine? get currentLine => _currentLine;
}

final scenarioTrainingProvider =
    NotifierProvider<ScenarioTrainingController, ScenarioTrainingState>(
  ScenarioTrainingController.new,
);

void selectScenarioLanguage(WidgetRef ref, String language) {
  ref.read(scenarioLanguageProvider.notifier).set(language);
  ref.read(learningHubLanguageProvider.notifier).set(language);
  ref.read(basicSentenceLanguageProvider.notifier).set(language);
  ref.read(swipeLanguageProvider.notifier).set(language);
  ref.read(selectedLanguageProvider.notifier).set(language);
}
