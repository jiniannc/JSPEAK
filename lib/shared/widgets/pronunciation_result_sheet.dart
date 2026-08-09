import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/tts_providers.dart';
import '../../data/models/sentence.dart';
import 'pronunciation_inline_diff_text.dart';
import 'score_celebration_overlay.dart';

/// 발음 점수 구간별 피드백.
class _PronunciationFeedback {
  final String badge;
  final String message;
  final Color badgeColor;
  final String? tip;

  const _PronunciationFeedback({
    required this.badge,
    required this.message,
    required this.badgeColor,
    this.tip,
  });

  factory _PronunciationFeedback.forAccuracy(int accuracy) {
    if (accuracy >= 90) {
      return const _PronunciationFeedback(
        badge: '✨ Excellent',
        message: '✈️ 기내 방송 담당 승무원 수준의 명확한 발음이에요!',
        badgeColor: Color(0xFF0D9488),
      );
    }
    if (accuracy >= 70) {
      return const _PronunciationFeedback(
        badge: '👏 Great Job',
        message: '🎧 원어민 승객이 한 번에 알아듣는 매끄러운 발음입니다!',
        badgeColor: Color(0xFF10B981),
      );
    }
    if (accuracy >= 50) {
      return const _PronunciationFeedback(
        badge: '🎯 Keep Going',
        message: '💡 억양이 조금 낯설어요. 원어민 음성을 듣고 다시 도전해 볼까요?',
        badgeColor: Color(0xFFCA8A04),
      );
    }
    return const _PronunciationFeedback(
      badge: '🔄 Try Again',
      message: '🎙️ 또박또박 마이크 가까이에서 천천히 말해 보세요!',
      badgeColor: Color(0xFF64748B),
    );
  }

  factory _PronunciationFeedback.noAudio() {
    return const _PronunciationFeedback(
      badge: '⚠️ 마이크 확인 필요',
      message:
          '음성이 감지되지 않았어요! 마이크 권한이 켜져 있는지, 무음 상태가 아닌지 확인 후 다시 말해 주세요.',
      badgeColor: Color(0xFFF43F5E),
      tip: 'Tip: 마이크 가까이에서 소리 내어 말하면 더 정확히 인식돼요.',
    );
  }
}

ScoreCelebrationTier _celebrationTierFor(int accuracy) {
  if (accuracy >= 100) return ScoreCelebrationTier.perfect;
  if (accuracy >= 80) return ScoreCelebrationTier.excellent;
  return ScoreCelebrationTier.none;
}

enum _PronunciationAnalysisKind {
  wordDiff,
  acousticMismatch,
  noWordsRecognized,
}

/// 발음 연습 결과 — 글래스 바텀시트 + 오디오 파형 게이지.
class PronunciationResultSheet extends ConsumerStatefulWidget {
  final Sentence sentence;
  final int accuracy;
  final bool isNoAudioDetected;
  final String spokenText;
  final VoidCallback onRetry;
  final VoidCallback? onNextSentence;
  final VoidCallback onClose;

  const PronunciationResultSheet({
    super.key,
    required this.sentence,
    required this.accuracy,
    required this.isNoAudioDetected,
    required this.spokenText,
    required this.onRetry,
    this.onNextSentence,
    required this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required Sentence sentence,
    required int accuracy,
    required bool isNoAudioDetected,
    required String spokenText,
    required VoidCallback onRetry,
    VoidCallback? onNextSentence,
    VoidCallback? onClose,
  }) {
    final celebrationTier = isNoAudioDetected
        ? ScoreCelebrationTier.none
        : _celebrationTierFor(accuracy);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        final screenSize = MediaQuery.sizeOf(sheetContext);
        return SizedBox(
          height: screenSize.height,
          width: screenSize.width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (celebrationTier != ScoreCelebrationTier.none && !kIsWeb)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ScoreCelebrationOverlay(tier: celebrationTier),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: screenSize.height * 0.6,
                  width: screenSize.width,
                  child: PronunciationResultSheet(
                    sentence: sentence,
                    accuracy: accuracy,
                    isNoAudioDetected: isNoAudioDetected,
                    spokenText: spokenText,
                    onRetry: () {
                      Navigator.of(sheetContext).pop();
                      onRetry();
                    },
                    onNextSentence: onNextSentence == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            onNextSentence();
                          },
                    onClose: () {
                      Navigator.of(sheetContext).pop();
                      onClose?.call();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PronunciationResultSheet> createState() =>
      _PronunciationResultSheetState();
}

class _PronunciationResultSheetState extends ConsumerState<PronunciationResultSheet>
    with TickerProviderStateMixin {
  static const _slate = Color(0xFF0F172A);

  late final AnimationController _gaugeController;
  late final AnimationController _wavePulseController;
  late final AnimationController _shimmerController;
  Timer? _shimmerTimer;
  late final math.Random _shimmerRandom;

  _PronunciationFeedback get _feedback => widget.isNoAudioDetected
      ? _PronunciationFeedback.noAudio()
      : _PronunciationFeedback.forAccuracy(widget.accuracy);

  String get _language => widget.sentence.language;

  bool get _hasWordDiff => pronunciationHasWordDiff(
        targetText: widget.sentence.sentence,
        spokenText: widget.spokenText,
        language: _language,
        koreanPronunciation: widget.sentence.pronunciation,
      );

  bool get _isTextPerfectMatch => pronunciationIsTextPerfectMatch(
        targetText: widget.sentence.sentence,
        spokenText: widget.spokenText,
        language: _language,
        koreanPronunciation: widget.sentence.pronunciation,
      );

  _PronunciationAnalysisKind? get _analysisKind {
    if (widget.isNoAudioDetected || widget.spokenText.trim().isEmpty) {
      return null;
    }
    // 점수와 무관하게 텍스트 diff가 있으면 항상 칩 표시.
    if (_hasWordDiff) return _PronunciationAnalysisKind.wordDiff;
    if (_isTextPerfectMatch && widget.accuracy < 100) {
      return _PronunciationAnalysisKind.acousticMismatch;
    }
    // 100점·텍스트 완벽 일치 — 말한 문장(전부 Match 칩)을 하단에 표시.
    if (_isTextPerfectMatch && widget.accuracy >= 100) {
      return _PronunciationAnalysisKind.wordDiff;
    }
    if (pronunciationHasPartialMatch(
          targetText: widget.sentence.sentence,
          spokenText: widget.spokenText,
          language: _language,
          koreanPronunciation: widget.sentence.pronunciation,
        )) {
      return _PronunciationAnalysisKind.wordDiff;
    }
    return _PronunciationAnalysisKind.noWordsRecognized;
  }

  @override
  void initState() {
    super.initState();
    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _wavePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerRandom = math.Random(3182);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scheduleShimmer(initial: true);

    if (!widget.isNoAudioDetected && widget.accuracy >= 80) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.mediumImpact();
      });
    }
  }

  void _scheduleShimmer({required bool initial}) {
    _shimmerTimer?.cancel();
    final delayMs = initial
        ? 600 + _shimmerRandom.nextInt(900)
        : 1800 + _shimmerRandom.nextInt(2600);
    _shimmerTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      await _shimmerController.forward(from: 0);
      if (mounted) _scheduleShimmer(initial: false);
    });
  }

  Future<void> _playTargetAudio() async {
    final sentence = widget.sentence;
    if (sentence.audioUrl.isNotEmpty) {
      await ref.read(audioProvider.notifier).play(sentence);
      return;
    }
    await ref.read(ttsSpeakingProvider.notifier).speakWord(
          word: sentence.sentence,
          language: sentence.language,
        );
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    _gaugeController.dispose();
    _wavePulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _feedback;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return _WebSafeGlass(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      blurSigma: 16,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: kIsWeb ? 0.97 : 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SizedBox.expand(
        child: Stack(
          children: [
            if (!kIsWeb)
              Positioned.fill(
                child: IgnorePointer(
                  child: _SheetShimmerOverlay(animation: _shimmerController),
                ),
              ),
            SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(24, 18, 24, 16 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SheetHeader(onClose: widget.onClose),
                        const SizedBox(height: 16),
                        _ScoreWaveformSection(
                          feedback: feedback,
                          accuracy: widget.accuracy,
                          isNoAudioDetected: widget.isNoAudioDetected,
                          gaugeAnimation: _gaugeController,
                          wavePulseAnimation: _wavePulseController,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          feedback.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                        if (feedback.tip != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            feedback.tip!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _slate.withValues(alpha: 0.45),
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (_analysisKind != null) ...[
                          const SizedBox(height: 24),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _MorphInCard(
                                child: switch (_analysisKind!) {
                                  _PronunciationAnalysisKind.wordDiff =>
                                    _PronunciationDiffCard(
                                      sentence: widget.sentence,
                                      spokenText: widget.spokenText,
                                      onPlayTargetAudio: _playTargetAudio,
                                    ),
                                  _PronunciationAnalysisKind.acousticMismatch =>
                                    _AcousticMismatchCard(
                                      accuracy: widget.accuracy,
                                    ),
                                  _PronunciationAnalysisKind.noWordsRecognized =>
                                    const _NoWordsRecognizedCard(),
                                },
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        const SizedBox(height: 24),
                        if (widget.isNoAudioDetected)
                          _PrimaryRetryButton(onPressed: widget.onRetry)
                        else
                          _ResultActionRow(
                            onRetry: widget.onRetry,
                            onNextSentence: widget.onNextSentence,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '🎙 PRONUNCIATION REPORT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
          icon: Text(
            '✕',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A).withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  final _PronunciationFeedback feedback;

  const _FeedbackBadge({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: feedback.badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: feedback.badgeColor.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          feedback.badge,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: feedback.badgeColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _ScoreWaveformSection extends StatelessWidget {
  final _PronunciationFeedback feedback;
  final int accuracy;
  final bool isNoAudioDetected;
  final Animation<double> gaugeAnimation;
  final Animation<double> wavePulseAnimation;

  const _ScoreWaveformSection({
    required this.feedback,
    required this.accuracy,
    required this.isNoAudioDetected,
    required this.gaugeAnimation,
    required this.wavePulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeedbackBadge(feedback: feedback),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: gaugeAnimation,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(gaugeAnimation.value);
            final displayScore = isNoAudioDetected ? null : (accuracy * t).round();

            return Text(
              isNoAudioDetected ? '⚠️ --점' : '$displayScore점',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isNoAudioDetected ? 32 : 42,
                fontWeight: FontWeight.w900,
                color: isNoAudioDetected
                    ? const Color(0xFF64748B).withValues(alpha: 0.85)
                    : const Color(0xFF0F172A),
                height: 1,
                letterSpacing: -0.8,
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        _AudioWaveformGauge(
          accuracy: accuracy,
          isNoAudioDetected: isNoAudioDetected,
          gaugeAnimation: gaugeAnimation,
          wavePulseAnimation: wavePulseAnimation,
        ),
      ],
    );
  }
}

class _NoWordsRecognizedCard extends StatelessWidget {
  const _NoWordsRecognizedCard();

  @override
  Widget build(BuildContext context) {
    return _WebSafeGlass(
      borderRadius: BorderRadius.circular(14),
      blurSigma: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E).withValues(alpha: kIsWeb ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Text(
          '인식된 단어가 없습니다. 마이크 가까이에서 다시 말해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBE123C),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// STT 텍스트는 일치하지만 유사도·억양 점수만 미세 감점된 경우.
class _AcousticMismatchCard extends StatelessWidget {
  final int accuracy;

  const _AcousticMismatchCard({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🎙️ 발음 교정 분석',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.12,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '✨ 텍스트 완벽 일치! (원어민 억양과 속도에 $accuracy% 일치해요)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _WebSafeGlass(
          borderRadius: BorderRadius.circular(16),
          blurSigma: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: kIsWeb ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Text(
              '문맥과 단어는 정확해요! 조금 더 자연스러운 억양으로 말해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 메인 카드의 실시간 텍스트 영역이 결과 시트의 분석 카드로 확장되는
/// 느낌을 주기 위한 가벼운 fade + scale 진입 애니메이션.
/// (Flutter Web에서 AnimatedSwitcher와 결합된 Hero가 mouse_tracker와
/// 충돌하는 문제가 있어 실제 Hero 대신 이 방식을 사용한다.)
class _MorphInCard extends StatelessWidget {
  final Widget child;

  const _MorphInCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.92 + 0.08 * t,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PronunciationDiffCard extends ConsumerWidget {
  final Sentence sentence;
  final String spokenText;
  final VoidCallback onPlayTargetAudio;

  const _PronunciationDiffCard({
    required this.sentence,
    required this.spokenText,
    required this.onPlayTargetAudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final audio = ref.watch(audioProvider);
    final isPlayingTarget =
        audio.playingSentenceId == sentence.id && audio.isPlaying;
    final isReplayActive = isSpeaking || isPlayingTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              '🎙️ 발음 교정 분석',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.12,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _TargetAudioReplayButton(
                onTap: onPlayTargetAudio,
                isActive: isReplayActive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _WebSafeGlass(
          borderRadius: BorderRadius.circular(16),
          blurSigma: 10,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: kIsWeb ? 0.88 : 0.42),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: PronunciationInlineDiffText(
              targetText: sentence.sentence,
              spokenText: spokenText,
              language: sentence.language,
              correctPronunciation: sentence.pronunciation,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetAudioReplayButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _TargetAudioReplayButton({
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _WebSafeGlass(
          borderRadius: BorderRadius.circular(20),
          blurSigma: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.88 : 0.72),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.volume_up_rounded,
              size: 16,
              color: isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioWaveformGauge extends StatelessWidget {
  final int accuracy;
  final bool isNoAudioDetected;
  final Animation<double> gaugeAnimation;
  final Animation<double> wavePulseAnimation;

  static const _barCount = 13;
  static const _shape = [
    0.38, 0.52, 0.68, 0.82, 0.94, 1.0, 0.96, 0.88, 0.74, 0.58, 0.46, 0.52,
    0.64,
  ];

  const _AudioWaveformGauge({
    required this.accuracy,
    required this.isNoAudioDetected,
    required this.gaugeAnimation,
    required this.wavePulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: AnimatedBuilder(
        animation: Listenable.merge([gaugeAnimation, wavePulseAnimation]),
        builder: (context, _) {
          final fillT = Curves.easeOutCubic.transform(gaugeAnimation.value);
          final pulsePhase = wavePulseAnimation.value * 2 * math.pi;
          final isPerfectScore = !isNoAudioDetected && accuracy >= 100;
          final animFill = isPerfectScore ? 1.0 : fillT;
          final filledBars = isNoAudioDetected
              ? 0
              : isPerfectScore
                  ? _barCount
                  : ((accuracy / 100) * _barCount * animFill)
                      .ceil()
                      .clamp(0, _barCount);
          final highScore = !isNoAudioDetected && accuracy >= 70;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _barCount; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _WaveBar(
                  shape: _shape[i],
                  filled: i < filledBars,
                  isNoAudio: isNoAudioDetected,
                  isPerfectScore: isPerfectScore,
                  highScore: highScore,
                  fillProgress: fillT,
                  pulsePhase: pulsePhase,
                  barIndex: i,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WaveBar extends StatelessWidget {
  final double shape;
  final bool filled;
  final bool isNoAudio;
  final bool isPerfectScore;
  final bool highScore;
  final double fillProgress;
  final double pulsePhase;
  final int barIndex;

  const _WaveBar({
    required this.shape,
    required this.filled,
    required this.isNoAudio,
    required this.isPerfectScore,
    required this.highScore,
    required this.fillProgress,
    required this.pulsePhase,
    required this.barIndex,
  });

  @override
  Widget build(BuildContext context) {
    const maxHeight = 36.0;
    const minHeight = 5.0;

    final pulse =
        math.sin(pulsePhase + barIndex * 0.55) * (highScore ? 0.30 : 0.22) +
            (highScore ? 0.70 : 0.78);
    final animatedPulse = filled && !isNoAudio ? pulse : 1.0;
    final targetHeight = isNoAudio
        ? minHeight
        : minHeight + (maxHeight - minHeight) * shape * animatedPulse;
    final height = filled
        ? targetHeight *
            (isPerfectScore ? 1.0 : fillProgress.clamp(0.4, 1.0))
        : minHeight;

    final gradient = highScore
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
            stops: [0.0, 0.55, 1.0],
          )
        : LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.82),
              const Color(0xFF64748B).withValues(alpha: 0.72),
            ],
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 5,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: !isNoAudio && filled ? gradient : null,
        color: isNoAudio || !filled
            ? const Color(0xFFE2E8F0).withValues(alpha: filled ? 1 : 0.65)
            : null,
      ),
    );
  }
}

class _ResultActionRow extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onNextSentence;

  const _ResultActionRow({
    required this.onRetry,
    required this.onNextSentence,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LiquidGlassButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LiquidGlassButton(
            onPressed: onNextSentence,
            primary: true,
            child: const Text(
              '다음 문장 ▶',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiquidGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool primary;

  const _LiquidGlassButton({
    required this.onPressed,
    required this.child,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (primary)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF22D3EE).withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: kIsWeb ? 0.82 : 0.65),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: kIsWeb
                        ? const SizedBox.expand()
                        : BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const SizedBox.expand(),
                          ),
                  ),
                Center(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryRetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PrimaryRetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _LiquidGlassButton(
      onPressed: onPressed,
      primary: true,
      child: const Text(
        '다시 시도',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SheetShimmerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _SheetShimmerOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return ClipRect(
          child: Align(
            alignment: Alignment(-1.6 + 3.2 * t, 0),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: FractionallySizedBox(
                widthFactor: 0.28,
                heightFactor: 2.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Flutter Web CanvasKit에서 BackdropFilter + saveLayer 조합 시 picture dispose 크래시 방지.
class _WebSafeGlass extends StatelessWidget {
  final BorderRadius? borderRadius;
  final BoxDecoration decoration;
  final Widget child;
  final double blurSigma;

  const _WebSafeGlass({
    this.borderRadius,
    required this.decoration,
    required this.child,
    this.blurSigma = 10,
  });

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: decoration,
      child: child,
    );

    if (borderRadius == null) {
      if (kIsWeb) return panel;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: panel,
      );
    }

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: panel,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: panel,
      ),
    );
  }
}
