import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dictionary_favorite_providers.dart';
import '../../../app/providers.dart';
import '../../../app/sentence_progress_providers.dart';
import '../../../app/speech_providers.dart';
import '../../../core/config/active5_layout.dart';
import '../../../core/utils/cjk_pronunciation_phrase.dart';
import '../../../core/utils/scenario_answer_compare.dart';
import '../../../core/utils/word_token_alignment.dart';
import '../../../data/models/sentence.dart';
import '../../../features/basic_sentence/widgets/achievement_stamps.dart';
import '../../../features/basic_sentence/widgets/in_flight_briefing_tour.dart';
import '../../../features/dashboard/dashboard_palette.dart';
import '../../../shared/widgets/pronunciation_inline_diff_text.dart';
import '../../../shared/widgets/pronunciation_result_sheet.dart';
import '../../../shared/widgets/pronunciation_voice_pipeline_overlay.dart';
import '../../../shared/widgets/tappable_sentence_rich_text.dart';

const _kHeaderContentGap = 10.0;
const _kDeckGap = 12.0;
/// 슬라이더 + 배속/재생 행 (Material Slider 터치 타깃 포함).
const _kPlaybackIdleInnerHeight = 90.0;

/// 3D 휠 학습 모드 전용 패널 — 재생·배속·플레이헤드·발음 연습.
class WheelLearningPanel extends ConsumerStatefulWidget {
  final Sentence sentence;
  final Color accent;
  final int displayIndex;
  final int totalCount;
  final LearningTourTargetKeys? tourKeys;
  final VoidCallback? onNextSentence;

  const WheelLearningPanel({
    super.key,
    required this.sentence,
    required this.accent,
    required this.displayIndex,
    required this.totalCount,
    this.tourKeys,
    this.onNextSentence,
  });

  @override
  ConsumerState<WheelLearningPanel> createState() =>
      _WheelLearningPanelState();
}

class _WheelLearningPanelState extends ConsumerState<WheelLearningPanel> {
  bool _coachingDialogOpen = false;
  bool _resultPending = false;
  DateTime? _analyzingStartedAt;
  PlayheadVoiceMode _localPlayheadMode = PlayheadVoiceMode.playback;

  static const _analyzingBridgeDuration = Duration(milliseconds: 700);

  void _setLocalMode(PlayheadVoiceMode mode) {
    if (!mounted || _localPlayheadMode == mode) return;
    setState(() => _localPlayheadMode = mode);
  }

  PlayheadVoiceMode _playheadMode({required bool isThisSpeech}) {
    if (!isThisSpeech) return PlayheadVoiceMode.playback;
    return _localPlayheadMode;
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

    // 레이아웃 패스가 끝난 뒤 스탬프를 점등해 Overlay/LayoutBuilder 충돌을 방지한다.
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
        ref.read(speechPracticeProvider.notifier).startPractice(widget.sentence);
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
        _setLocalMode(PlayheadVoiceMode.playback);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final speech = ref.watch(speechPracticeProvider);
    final metrics = Active5Layout.of(context);
    final accent = widget.accent;
    final sentence = widget.sentence;
    final isThisAudio = audio.playingSentenceId == sentence.id;
    final isThisSpeech = speech.activeSentenceId == sentence.id;
    final hasAudio = sentence.audioUrl.isNotEmpty;
    final stage =
        ref.watch(sentenceProgressProvider).stats.forSentence(sentence.id);
    // 듣기 미션 — 재생 버튼으로만 hasListened가 true (isRead와 분리).
    final hasListened = stage.hasListened;
    final hasSpoken = stage.isAttempted;
    final isMastered = stage.isMastered;

    ref.listen(speechPracticeProvider, (prev, next) {
      if (prev == null) return;
      final isThis = next.activeSentenceId == sentence.id;
      if (!isThis) return;

      if (next.isListening && !prev.isListening) {
        _setLocalMode(PlayheadVoiceMode.listening);
      }

      if (next.isRecognizing && !prev.isRecognizing) {
        _analyzingStartedAt = DateTime.now();
        _setLocalMode(PlayheadVoiceMode.analyzing);
      }

      if (next.error != null && next.error != prev.error) {
        _analyzingStartedAt = null;
        _setLocalMode(PlayheadVoiceMode.playback);
        return;
      }

      if (next.abortedNoSpeech && !prev.abortedNoSpeech) {
        _analyzingStartedAt = null;
        _resultPending = false;
        _setLocalMode(PlayheadVoiceMode.playback);
        ref.read(speechPracticeProvider.notifier).acknowledgeAbort();
        return;
      }

      final wasBusy = prev.isListening || prev.isRecognizing;
      final isIdle = !next.isListening && !next.isRecognizing;
      if (wasBusy && isIdle && !_coachingDialogOpen && !next.abortedNoSpeech) {
        // STT 엔진이 stop() 경유 없이 바로 최종 결과를 낼 수도 있으므로
        // 브릿지 구간에는 항상 분석 카드가 보이도록 보정한다.
        _setLocalMode(PlayheadVoiceMode.analyzing);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _completePipelineAndShowResult();
        });
      }
    });

    final playheadMode = _playheadMode(isThisSpeech: isThisSpeech);
    final isAnalyzingSpeech =
        isThisSpeech && playheadMode == PlayheadVoiceMode.analyzing;

    const outerPadding = EdgeInsets.fromLTRB(18, 14, 18, 12);
    const contentGap = 12.0;

    final textSection = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        TappableSentenceRichText(
          sentence: sentence.sentence,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: metrics.sentenceFontSize + 1,
            fontWeight: FontWeight.w800,
            height: 1.35,
            color: DashboardPalette.navy,
          ),
        ),
        if (sentence.stars > 0) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < sentence.stars; i++)
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Colors.amber.shade600,
                ),
            ],
          ),
        ],
        if (sentence.pronunciation.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            sentence.pronunciation,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metrics.pronunciationFontSize,
              fontStyle: FontStyle.italic,
              color: DashboardPalette.textMuted,
              height: 1.35,
            ),
          ),
        ],
        if (sentence.korean.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            sentence.korean,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: metrics.koreanFontSize,
              fontWeight: FontWeight.w600,
              color: DashboardPalette.navy.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: outerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BoardingPassMetaHeader(
            sentence: sentence,
            displayIndex: widget.displayIndex,
            totalCount: widget.totalCount,
            hasListened: hasListened,
            hasSpoken: hasSpoken,
            isMastered: isMastered,
            tourKeys: widget.tourKeys,
          ),
          const SizedBox(height: _kHeaderContentGap),
          Expanded(
            child: _CenteredScrollTextPane(child: textSection),
          ),
          const SizedBox(height: contentGap),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAudio) ...[
                KeyedSubtree(
                  key: widget.tourKeys?.playbackDeckKey,
                  child: SizedBox(
                    width: double.infinity,
                    child: _GlassPlaybackDeck(
                      accent: accent,
                      isActive: isThisAudio,
                      isPlaying: isThisAudio && audio.isPlaying,
                      isLoading: isThisAudio && audio.loading,
                      position: isThisAudio ? audio.position : Duration.zero,
                      duration: isThisAudio ? audio.duration : Duration.zero,
                      speed: audio.playbackSpeed,
                      playheadMode: playheadMode,
                  liveText: speech.spokenText,
                  onPlayPause: () {
                      ref
                          .read(sentenceProgressProvider.notifier)
                          .markListened(sentence.id);
                      ref
                          .read(audioProvider.notifier)
                          .togglePlayPause(sentence);
                    },
                    onRestart: () => ref.read(audioProvider.notifier).restart(),
                    onSeek: (v) =>
                        ref.read(audioProvider.notifier).seekToProgress(v),
                      onSpeed: (s) =>
                          ref.read(audioProvider.notifier).setSpeed(s),
                    ),
                  ),
                ),
                const SizedBox(height: _kDeckGap),
              ],
              SizedBox(
                width: double.infinity,
                child: _GlassPracticeDeck(
                  accent: accent,
                  speech: speech,
                  isActive: isThisSpeech,
                  isAnalyzing: isAnalyzingSpeech,
                  speakTourKey: widget.tourKeys?.speakKey,
                  playheadMode:
                      hasAudio ? PlayheadVoiceMode.playback : playheadMode,
                  liveText: speech.spokenText,
                  onCompleteRecording: isThisSpeech && speech.isListening
                      ? () => ref
                          .read(speechPracticeProvider.notifier)
                          .autoStopRecording()
                      : null,
                  onMic: () {
                    ref
                        .read(speechPracticeProvider.notifier)
                        .startPractice(sentence);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 짧은 문장은 세로 중앙, 긴 문장은 스크롤.
/// LayoutBuilder를 별도 위젯으로 분리해 부모 레이아웃 패스와 충돌하지 않게 한다.
class _CenteredScrollTextPane extends StatefulWidget {
  final Widget child;

  const _CenteredScrollTextPane({required this.child});

  @override
  State<_CenteredScrollTextPane> createState() =>
      _CenteredScrollTextPaneState();
}

class _CenteredScrollTextPaneState extends State<_CenteredScrollTextPane> {
  bool _showBottomFade = false;

  void _syncScrollable(bool scrollable) {
    if (_showBottomFade == scrollable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showBottomFade != scrollable) {
        setState(() => _showBottomFade = scrollable);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _syncScrollable(notification.metrics.maxScrollExtent > 4);
                return false;
              },
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minH),
                  child: Center(child: widget.child),
                ),
              ),
            ),
            if (_showBottomFade)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlassPlaybackDeck extends StatelessWidget {
  final Color accent;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double speed;
  final PlayheadVoiceMode playheadMode;
  final String liveText;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSpeed;

  const _GlassPlaybackDeck({
    required this.accent,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.speed,
    required this.playheadMode,
    required this.liveText,
    required this.onPlayPause,
    required this.onRestart,
    required this.onSeek,
    required this.onSpeed,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return _PanelGlassShell(
      borderRadius: BorderRadius.circular(18),
      fillColor: Colors.white.withValues(alpha: 0.42),
      blurSigma: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: PronunciationPlayheadMorph(
            mode: playheadMode,
            liveText: liveText,
            playbackChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _kPlaybackIdleInnerHeight - 42,
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: accent,
                            inactiveTrackColor: accent.withValues(alpha: 0.14),
                            thumbColor: accent,
                            overlayColor: accent.withValues(alpha: 0.12),
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: isActive ? onSeek : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmt(isActive ? position : Duration.zero),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: DashboardPalette.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        ' / ${_fmt(isActive ? duration : Duration.zero)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              DashboardPalette.textMuted.withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: Row(
                    children: [
                      for (final s in const [0.5, 0.75, 1.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _SpeedChip(
                            label: s == 1.0 ? '1×' : '$s×',
                            selected: (speed - s).abs() < 0.01,
                            accent: accent,
                            onTap: () => onSpeed(s),
                          ),
                        ),
                      const Spacer(),
                      _GlassRoundButton(
                        accent: accent,
                        size: 36,
                        tooltip: '처음부터',
                        onTap: onRestart,
                        icon: Icon(Icons.replay_rounded, size: 18, color: accent),
                      ),
                      const SizedBox(width: 6),
                      _GlassRoundButton(
                        accent: accent,
                        size: 42,
                        tooltip: isPlaying ? '일시정지' : '재생',
                        onTap: onPlayPause,
                        icon: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              )
                            : Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 22,
                                color: accent,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _GlassPracticeDeck extends StatelessWidget {
  final Color accent;
  final SpeechPracticeState speech;
  final bool isActive;
  final bool isAnalyzing;
  final GlobalKey? speakTourKey;
  final PlayheadVoiceMode playheadMode;
  final String liveText;
  final VoidCallback? onCompleteRecording;
  final VoidCallback onMic;

  const _GlassPracticeDeck({
    required this.accent,
    required this.speech,
    required this.isActive,
    this.isAnalyzing = false,
    this.speakTourKey,
    required this.playheadMode,
    required this.liveText,
    this.onCompleteRecording,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final initializing = isActive && speech.isInitializing;
    final listening = isActive && speech.isListening;

    final speakButton = SpeakLiquidGlassButton(
      isInitializing: initializing,
      isRecording: listening,
      isAnalyzing: isAnalyzing,
      onStart: onMic,
      onComplete: onCompleteRecording,
      tourKey: speakTourKey,
    );

    return _PanelGlassShell(
      borderRadius: BorderRadius.circular(18),
      fillColor: Colors.white.withValues(alpha: 0.42),
      blurSigma: 8,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (playheadMode != PlayheadVoiceMode.playback) ...[
                PronunciationPlayheadMorph(
                  mode: playheadMode,
                  liveText: liveText,
                  playbackChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
              ],
              speakButton,
              if (isActive && speech.error != null) ...[
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
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? accent : DashboardPalette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 보딩패스 티켓 패밀리룩 — 카드 상단 메타 헤더 + 3단계 미션 뱃지.
class _BoardingPassMetaHeader extends ConsumerWidget {
  final Sentence sentence;
  final int displayIndex;
  final int totalCount;
  final bool hasListened;
  final bool hasSpoken;
  final bool isMastered;
  final LearningTourTargetKeys? tourKeys;

  const _BoardingPassMetaHeader({
    required this.sentence,
    required this.displayIndex,
    required this.totalCount,
    required this.hasListened,
    required this.hasSpoken,
    required this.isMastered,
    this.tourKeys,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref
        .watch(dictionaryFavoritesResolvedProvider)
        .contains(sentence.storageFavoriteKey);

    return Row(
      children: [
        Text(
          '✈️ BOARDING PASS',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1.2,
            color: DashboardPalette.navy.withValues(alpha: 0.45),
          ),
        ),
        const Spacer(),
        KeyedSubtree(
          key: tourKeys?.bookmarkKey,
          child: _WheelBookmarkToggle(
            isBookmarked: isBookmarked,
            onToggle: () async {
              final added = await ref
                  .read(dictionaryFavoritesProvider.notifier)
                  .toggleSentence(sentence);
              if (context.mounted) {
                showDictionaryFavoriteSnackBar(context, added: added);
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        KeyedSubtree(
          key: tourKeys?.stampsKey,
          child: AchievementStampCluster(
            read: hasListened,
            attempted: hasSpoken,
            mastered: isMastered,
            stampSize: 26,
            width: 68,
            animateOnActivate: true,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${displayIndex.toString().padLeft(2, '0')}/${totalCount.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: DashboardPalette.navy.withValues(alpha: 0.5),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _WheelBookmarkToggle extends StatefulWidget {
  final bool isBookmarked;
  final Future<void> Function() onToggle;

  const _WheelBookmarkToggle({
    required this.isBookmarked,
    required this.onToggle,
  });

  @override
  State<_WheelBookmarkToggle> createState() => _WheelBookmarkToggleState();
}

class _WheelBookmarkToggleState extends State<_WheelBookmarkToggle> {
  bool _boost = false;

  Future<void> _handleTap() async {
    setState(() => _boost = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _boost = false);
    await widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF59E0B);
    const muted = Color(0xFF94A3B8);

    final icon = widget.isBookmarked
        ? Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40F59E0B),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 20,
              color: gold,
            ),
          )
        : Icon(
            Icons.star_outline_rounded,
            size: 20,
            color: muted.withValues(alpha: 0.5),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedScale(
            scale: _boost ? 1.3 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _GlassRoundButton extends StatelessWidget {
  final Color accent;
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  final Widget icon;

  const _GlassRoundButton({
    required this.accent,
    required this.size,
    required this.tooltip,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Semantics(label: tooltip, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// Flutter Web CanvasKit에서 BackdropFilter + 오버레이 saveLayer 조합 크래시 방지.
class _PanelGlassShell extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color fillColor;
  final double blurSigma;
  final Widget child;

  const _PanelGlassShell({
    required this.borderRadius,
    required this.fillColor,
    this.blurSigma = 8,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: borderRadius,
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
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}
