import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_providers.dart';
import '../core/services/speech_recognition_service.dart';
import '../data/models/sentence.dart';

/// 시트 언어명 → speech_to_text localeId.
const Map<String, String> speechLocaleIds = {
  'English': 'en_US',
  'Japanese': 'ja_JP',
  'Chinese': 'zh_CN',
};

String speechLocaleFor(String language) =>
    speechLocaleIds[language] ?? 'en_US';

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>(
  (ref) => SpeechRecognitionService(),
);

/// 문장별 발음 연습(STT) 상태.
class SpeechPracticeState {
  final String? activeSentenceId;
  final bool isListening;
  final bool isInitializing;
  final bool isAvailable;
  /// stop() 직후 ~ STT isFinal 수신 전 구간.
  final bool isRecognizing;
  final String spokenText;
  /// 세션 중 관측된 최대 soundLevel (speech_to_text ≈ -2~10).
  final double peakSoundLevel;
  /// 실시간 마이크 음량 — 라이브 파형 UI용.
  final double currentSoundLevel;
  final bool hadSoundLevelSample;
  /// 10초 내 무응답으로 녹음이 취소됐을 때 true (결과 시트 없이 idle 복귀).
  final bool abortedNoSpeech;
  final String? error;

  const SpeechPracticeState({
    this.activeSentenceId,
    this.isListening = false,
    this.isInitializing = false,
    this.isAvailable = false,
    this.isRecognizing = false,
    this.spokenText = '',
    this.peakSoundLevel = -10,
    this.currentSoundLevel = -10,
    this.hadSoundLevelSample = false,
    this.abortedNoSpeech = false,
    this.error,
  });

  SpeechPracticeState copyWith({
    String? activeSentenceId,
    bool? isListening,
    bool? isInitializing,
    bool? isAvailable,
    bool? isRecognizing,
    String? spokenText,
    double? peakSoundLevel,
    double? currentSoundLevel,
    bool? hadSoundLevelSample,
    bool? abortedNoSpeech,
    String? error,
    bool clearActiveSentence = false,
    bool clearSpokenText = false,
    bool clearError = false,
    bool clearAbortedNoSpeech = false,
  }) {
    return SpeechPracticeState(
      activeSentenceId:
          clearActiveSentence ? null : (activeSentenceId ?? this.activeSentenceId),
      isListening: isListening ?? this.isListening,
      isInitializing: isInitializing ?? this.isInitializing,
      isAvailable: isAvailable ?? this.isAvailable,
      isRecognizing: isRecognizing ?? this.isRecognizing,
      spokenText: clearSpokenText ? '' : (spokenText ?? this.spokenText),
      peakSoundLevel: peakSoundLevel ?? this.peakSoundLevel,
      currentSoundLevel: currentSoundLevel ?? this.currentSoundLevel,
      hadSoundLevelSample: hadSoundLevelSample ?? this.hadSoundLevelSample,
      abortedNoSpeech: clearAbortedNoSpeech
          ? false
          : (abortedNoSpeech ?? this.abortedNoSpeech),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SpeechPracticeController extends Notifier<SpeechPracticeState> {
  SpeechRecognitionService get _service =>
      ref.read(speechRecognitionServiceProvider);

  static const _recognizingTimeout = Duration(milliseconds: 2500);
  /// speech_to_text soundLevel 기준 — 이 값 미만이면 무음/미감지로 판정.
  static const _lowVolumeThreshold = -0.5;
  /// 이 값을 넘겨야 '말하기 시작'으로 인정 (무음 오탐 방지).
  static const _speechThreshold = -0.35;
  /// VAD: 이 값 이하가 일정 시간 유지되면 자동 종료.
  static const _silenceThreshold = -1.2;
  static const _silenceHoldDuration = Duration(milliseconds: 1200);
  /// 말하기 전 대기 상한 — 무응답 시 idle 복귀 (결과 시트 없음).
  static const _noSpeechTimeout = Duration(seconds: 10);
  /// 말한 뒤 STT 엔진 pauseFor — 앱 VAD(1.2s)보다 길게.
  static const _enginePauseFor = Duration(milliseconds: 2800);
  /// soundLevel이 이 시간 이상 임계치를 넘어야 '말하기'로 인정.
  static const _speechConfirmDuration = Duration(milliseconds: 450);
  /// 말한 뒤 절대 상한.
  static const _maxListeningDuration = Duration(seconds: 30);

  Object? _recognizingTimeoutToken;
  DateTime? _sessionStartedAt;
  DateTime? _listeningStartedAt;
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
  Sentence? _listeningSentence;

  @override
  SpeechPracticeState build() => const SpeechPracticeState();

  void _clearRecognizingTimeout() {
    _recognizingTimeoutToken = null;
  }

  void _clearVadTimers({bool resetSession = true}) {
    _listeningStartedAt = null;
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
    _listeningSentence = null;
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
      _service.changePauseFor(_enginePauseFor);
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
    final sentence = _listeningSentence;
    if (sentence == null || !state.isListening) return;
    if (_autoStopping || _restartingListen || _hadSpeechDuringSession) return;
    if (status != 'done' && status != 'notListening') return;

    // Web STT는 무음 ~1~2초 후 자체 종료 — 말하기 전에는 세션을 이어 붙인다.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!ref.mounted) return;
      unawaited(_maybeRestartListening(sentence));
    });
  }

  Future<void> _maybeRestartListening(Sentence sentence) async {
    if (!state.isListening || _autoStopping || _restartingListen) return;
    if (_hadSpeechDuringSession) return;
    if (state.activeSentenceId != sentence.id) return;

    final noSpeechLeft = _remainingNoSpeechWindow;
    if (noSpeechLeft <= Duration.zero) {
      await abortListeningNoSpeech();
      return;
    }

    final listenFor = _remainingListenWindow;
    if (listenFor <= Duration.zero) {
      await abortListeningNoSpeech();
      return;
    }

    _restartingListen = true;
    try {
      await _service.startListening(
        localeId: speechLocaleFor(sentence.language),
        listenFor: listenFor,
        onSoundLevelChange: (level) => _handleSoundLevel(sentence, level),
        onResult: (text, {required bool isFinal}) =>
            _handleListenResult(sentence, text, isFinal: isFinal),
      );
    } catch (e) {
      if (ref.mounted && state.isListening && !_hadSpeechDuringSession) {
        state = state.copyWith(
          error: '음성 인식 재시작 실패: $e',
          isListening: false,
          isRecognizing: false,
        );
      }
    } finally {
      _restartingListen = false;
    }
  }

  void _handleListenResult(
    Sentence sentence,
    String text, {
    required bool isFinal,
  }) {
    if (state.activeSentenceId != sentence.id) return;
    if (isFinal) {
      _partialSilenceTimer?.cancel();
      if (!_hadSpeechDuringSession && text.trim().isEmpty) {
        unawaited(_maybeRestartListening(sentence));
        return;
      }
      _clearVadTimers();
      _clearRecognizingTimeout();
      state = state.copyWith(
        spokenText: text,
        isListening: false,
        isRecognizing: false,
      );
      if (text.trim().isNotEmpty) {
        _recordPractice(sentence.id);
      }
      return;
    }
    _handlePartialSpeech(text);
    state = state.copyWith(spokenText: text);
  }

  void _scheduleNoSpeechTimeout() {
    final token = Object();
    _noSpeechToken = token;
    Future<void>.delayed(_noSpeechTimeout, () {
      if (!ref.mounted) return;
      if (_noSpeechToken != token) return;
      if (!state.isListening) return;
      if (_hadSpeechDuringSession) return;
      unawaited(abortListeningNoSpeech());
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
        unawaited(abortListeningNoSpeech());
        return;
      }
      unawaited(_triggerAutoStop());
    });
  }

  void _handleSoundLevel(Sentence sentence, double level) {
    if (state.activeSentenceId != sentence.id || !state.isListening) return;

    final peak = level > state.peakSoundLevel ? level : state.peakSoundLevel;
    state = state.copyWith(
      currentSoundLevel: level,
      peakSoundLevel: peak,
      hadSoundLevelSample: true,
    );

    final now = DateTime.now();
    _listeningStartedAt ??= now;

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

  /// Web 등 soundLevel 콜백이 없을 때 partial STT 갱신으로 무음을 감지한다.
  void _handlePartialSpeech(String text) {
    if (state.activeSentenceId == null || !state.isListening) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _lastPartialText) return;
    // 첫 partial이 짧은 노이즈면 무시, 이후 갱신은 허용.
    if (_lastPartialText.isEmpty && trimmed.length < 3) return;

    final now = DateTime.now();
    _listeningStartedAt ??= now;
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
    await autoStopRecording();
  }

  /// Tap to Speak — 이미 녹음 중이면 무시(수동 Stop 제거).
  Future<void> startPractice(Sentence sentence) async {
    if (state.isListening || state.isRecognizing || state.isInitializing) {
      return;
    }

    if (state.activeSentenceId != null &&
        state.activeSentenceId != sentence.id &&
        (state.isListening || state.isRecognizing)) {
      await _service.stopListening();
      _clearRecognizingTimeout();
    }

    state = state.copyWith(
      activeSentenceId: sentence.id,
      isListening: false,
      isRecognizing: false,
      clearSpokenText: true,
      peakSoundLevel: -10,
      currentSoundLevel: -10,
      hadSoundLevelSample: false,
      clearError: true,
    );

    await start(sentence);
  }

  /// VAD 또는 최대 녹음 시간 도달 시 자동 종료.
  Future<void> autoStopRecording() async {
    await stop();
  }

  void _finishAbortNoSpeech() {
    _noSpeechToken = null;
    _partialSilenceTimer?.cancel();
    _clearVadTimers();
    _clearRecognizingTimeout();
    state = state.copyWith(
      isListening: false,
      isRecognizing: false,
      abortedNoSpeech: true,
      clearSpokenText: true,
      clearError: true,
    );
  }

  /// 10초 내 무응답 — 분석/결과 없이 녹음만 취소.
  Future<void> abortListeningNoSpeech() async {
    if (!state.isListening) return;
    await _service.cancelListening();
    _finishAbortNoSpeech();
  }

  void acknowledgeAbort() {
    if (!state.abortedNoSpeech) return;
    state = state.copyWith(clearAbortedNoSpeech: true);
  }

  void _scheduleRecognizingTimeout() {
    final token = Object();
    _recognizingTimeoutToken = token;
    Future<void>.delayed(_recognizingTimeout, () {
      if (!ref.mounted) return;
      if (_recognizingTimeoutToken != token) return;
      if (!state.isRecognizing) return;
      state = state.copyWith(isRecognizing: false);
    });
  }

  /// 마이크 버튼 토글: 같은 문장이면 중지, 다른 문장이면 전환 후 시작.
  Future<void> toggle(Sentence sentence) async {
    if (state.activeSentenceId == sentence.id &&
        (state.isListening || state.isRecognizing)) {
      await stop();
      return;
    }

    if (state.isListening || state.isRecognizing) {
      await _service.stopListening();
      _clearRecognizingTimeout();
    }

    state = state.copyWith(
      activeSentenceId: sentence.id,
      isListening: false,
      isRecognizing: false,
      clearSpokenText: true,
      peakSoundLevel: -10,
      hadSoundLevelSample: false,
      clearError: true,
    );

    await start(sentence);
  }

  Future<void> start(Sentence sentence) async {
    _clearRecognizingTimeout();
    state = state.copyWith(
      activeSentenceId: sentence.id,
      isInitializing: true,
      isRecognizing: false,
      clearSpokenText: true,
      clearAbortedNoSpeech: true,
      peakSoundLevel: -10,
      currentSoundLevel: -10,
      hadSoundLevelSample: false,
      clearError: true,
    );

    _clearVadTimers();
    _sessionStartedAt = DateTime.now();
    _listeningSentence = sentence;

    final available = await _service.initialize(
      onStatus: _handleEngineStatus,
    );
    if (!available) {
      state = state.copyWith(
        isInitializing: false,
        isAvailable: false,
        error: '음성 인식을 사용할 수 없습니다.',
      );
      return;
    }

    state = state.copyWith(
      isInitializing: false,
      isAvailable: true,
      isListening: true,
      isRecognizing: false,
    );

    _scheduleMaxListeningTimeout();
    _scheduleNoSpeechTimeout();

    try {
      // 말하기 전에는 pauseFor 없음 — Web/엔진 조기 종료 시 _maybeRestartListening.
      await _service.startListening(
        localeId: speechLocaleFor(sentence.language),
        listenFor: _maxListeningDuration,
        onSoundLevelChange: (level) => _handleSoundLevel(sentence, level),
        onResult: (text, {required bool isFinal}) =>
            _handleListenResult(sentence, text, isFinal: isFinal),
      );
    } catch (e) {
      _clearRecognizingTimeout();
      state = state.copyWith(
        isListening: false,
        isRecognizing: false,
        error: '음성 인식 시작 실패: $e',
      );
    }
  }

  Future<void> stop() async {
    if (!state.isListening) return;
    _clearVadTimers();
    await _service.stopListening();
    _clearRecognizingTimeout();
    state = state.copyWith(
      isListening: false,
      isRecognizing: true,
    );
    _scheduleRecognizingTimeout();
  }

  void reset() {
    if (!ref.mounted) return;
    _clearRecognizingTimeout();
    _clearVadTimers();
    _service.cancelListening();
    state = const SpeechPracticeState();
  }

  Future<void> _recordPractice(String sentenceId) async {
    await ref.read(learningRepositoryProvider).recordPractice(sentenceId);
    ref.invalidate(dashboardProvider);
  }

  /// STT 텍스트가 비었거나, 녹음 진폭이 기준치 미만이면 true.
  bool isNoAudioDetected(SpeechPracticeState speech) {
    final spokenText = speech.spokenText.trim();
    if (spokenText.isEmpty) return true;
    return speech.hadSoundLevelSample &&
        speech.peakSoundLevel < _lowVolumeThreshold;
  }
}

final speechPracticeProvider =
    NotifierProvider<SpeechPracticeController, SpeechPracticeState>(
  SpeechPracticeController.new,
);
