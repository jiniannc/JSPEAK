import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sentence_progress_providers.dart';
import '../../app/speech_providers.dart';
import '../../core/utils/cjk_pronunciation_phrase.dart';
import '../../core/utils/scenario_answer_compare.dart';
import '../../core/utils/word_token_alignment.dart';
import '../../data/models/sentence.dart';
import '../../features/dashboard/dashboard_palette.dart';
import 'pronunciation_inline_diff_text.dart';
import 'pronunciation_result_sheet.dart';
import 'pronunciation_voice_pipeline_overlay.dart';

/// Tap to Speak + 실시간 STT + 결과 바텀시트 — 기본문장학습·Today's Pick 공통.
class PronunciationPracticeSection extends ConsumerStatefulWidget {
  final Sentence sentence;
  final Color accent;
  final VoidCallback? onNextSentence;
  final EdgeInsetsGeometry padding;

  const PronunciationPracticeSection({
    super.key,
    required this.sentence,
    required this.accent,
    this.onNextSentence,
    this.padding = const EdgeInsets.fromLTRB(10, 0, 10, 8),
  });

  @override
  ConsumerState<PronunciationPracticeSection> createState() =>
      _PronunciationPracticeSectionState();
}

class _PronunciationPracticeSectionState
    extends ConsumerState<PronunciationPracticeSection> {
  bool _coachingDialogOpen = false;
  bool _resultPending = false;
  DateTime? _analyzingStartedAt;

  static const _analyzingBridgeDuration = Duration(milliseconds: 700);

  PlayheadVoiceMode _resolvePlayheadMode({
    required bool isThisSpeech,
    required SpeechPracticeState speech,
  }) {
    if (!isThisSpeech) return PlayheadVoiceMode.playback;
    if (speech.isListening) return PlayheadVoiceMode.listening;
    if (speech.isRecognizing || _resultPending) {
      return PlayheadVoiceMode.analyzing;
    }
    return PlayheadVoiceMode.playback;
  }

  void _clearAnalyzingBridge() {
    if (!_resultPending && _analyzingStartedAt == null) return;
    setState(() {
      _resultPending = false;
      _analyzingStartedAt = null;
    });
  }

  Future<void> _completePipelineAndShowResult() async {
    if (_coachingDialogOpen || _resultPending || !mounted) return;
    _resultPending = true;

    _analyzingStartedAt ??= DateTime.now();
    final started = _analyzingStartedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _analyzingBridgeDuration) {
      await Future<void>.delayed(_analyzingBridgeDuration - elapsed);
    }
    if (!mounted) {
      _resultPending = false;
      return;
    }

    _analyzingStartedAt = null;
    _openPronunciationResultSheet();
    _resultPending = false;
  }

  int _accuracyFor(String spokenText) {
    final language = widget.sentence.language;
    final pronunciation = widget.sentence.pronunciation;

    if ((language == 'Japanese' || language == 'Chinese') &&
        pronunciation.trim().isNotEmpty) {
      final lexicon = CjkPronunciationPhraseBuilder.buildLexicon(
        sentence: widget.sentence.sentence,
        pronunciation: pronunciation,
        language: language,
      );
      if (lexicon.isEmpty) return 0;

      final matched = pronunciationAccuracyPercent(
        targetText: widget.sentence.sentence,
        spokenText: spokenText,
        language: language,
        koreanPronunciation: pronunciation,
      );
      return matched.clamp(0, 100);
    }

    if (language == 'Japanese' || language == 'Chinese') {
      return ScenarioAnswerCompare.similarityPercent(
        spoken: spokenText,
        correct: widget.sentence.sentence,
        language: language,
      );
    }

    return WordTokenAligner.accuracyPercent(
      targetText: widget.sentence.sentence,
      spokenText: spokenText,
      language: language,
    );
  }

  void _openPronunciationResultSheet() {
    if (_coachingDialogOpen || !mounted) return;
    _coachingDialogOpen = true;

    final speech = ref.read(speechPracticeProvider);
    final spokenText = speech.spokenText.trim();
    final controller = ref.read(speechPracticeProvider.notifier);
    final isNoAudioDetected = controller.isNoAudioDetected(speech);
    final accuracy =
        isNoAudioDetected ? 0 : _accuracyFor(speech.spokenText);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sentenceProgressProvider.notifier).recordPracticeResult(
            sentenceId: widget.sentence.id,
            accuracy: accuracy,
            hasSpokenText: spokenText.isNotEmpty,
          );
    });

    PronunciationResultSheet.show(
      context: context,
      sentence: widget.sentence,
      accuracy: accuracy,
      isNoAudioDetected: isNoAudioDetected,
      spokenText: speech.spokenText,
      onRetry: () {
        ref
            .read(speechPracticeProvider.notifier)
            .startPractice(widget.sentence);
      },
      onNextSentence: widget.onNextSentence,
      onClose: () {},
    ).whenComplete(() {
      if (!mounted) return;
      _coachingDialogOpen = false;
      final currentSpeech = ref.read(speechPracticeProvider);
      final stillBusy = currentSpeech.activeSentenceId == widget.sentence.id &&
          (currentSpeech.isListening || currentSpeech.isRecognizing);
      if (!stillBusy) {
        _clearAnalyzingBridge();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechPracticeProvider);
    final sentence = widget.sentence;
    final isThisSpeech = speech.activeSentenceId == sentence.id;

    ref.listen(speechPracticeProvider, (prev, next) {
      if (prev == null) return;
      final isThis = next.activeSentenceId == sentence.id;
      if (!isThis) return;

      if (next.error != null && next.error != prev.error) {
        _clearAnalyzingBridge();
        return;
      }

      if (next.abortedNoSpeech && !prev.abortedNoSpeech) {
        _clearAnalyzingBridge();
        ref.read(speechPracticeProvider.notifier).acknowledgeAbort();
        return;
      }

      final wasBusy = prev.isListening || prev.isRecognizing;
      final isIdle = !next.isListening && !next.isRecognizing;
      if (wasBusy && isIdle && !_coachingDialogOpen && !next.abortedNoSpeech) {
        _analyzingStartedAt = DateTime.now();
        if (!_resultPending) {
          setState(() => _resultPending = true);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _completePipelineAndShowResult();
        });
      }
    });

    final playheadMode = _resolvePlayheadMode(
      isThisSpeech: isThisSpeech,
      speech: speech,
    );
    final isAnalyzingSpeech =
        isThisSpeech && playheadMode == PlayheadVoiceMode.analyzing;
    final initializing = isThisSpeech && speech.isInitializing;
    final listening = isThisSpeech && speech.isListening;

    return Padding(
      padding: widget.padding,
      child: _PracticeGlassShell(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (playheadMode != PlayheadVoiceMode.playback) ...[
                PronunciationPlayheadMorph(
                  mode: playheadMode,
                  liveText: speech.spokenText,
                  playbackChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
              ],
              SpeakLiquidGlassButton(
                isInitializing: initializing,
                isRecording: listening,
                isAnalyzing: isAnalyzingSpeech,
                onStart: () => ref
                    .read(speechPracticeProvider.notifier)
                    .startPractice(sentence),
                onComplete: isThisSpeech && speech.isListening
                    ? () => ref
                        .read(speechPracticeProvider.notifier)
                        .autoStopRecording()
                    : null,
              ),
              if (isThisSpeech && speech.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  speech.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeGlassShell extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget child;

  const _PracticeGlassShell({
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: borderRadius,
      border: Border.all(
        color: DashboardPalette.borderLight.withValues(alpha: 0.65),
      ),
    );

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}
