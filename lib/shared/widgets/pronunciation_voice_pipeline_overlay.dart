import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 메인 카드 플레이헤드 영역의 현재 표시 모드.
enum PlayheadVoiceMode { playback, listening, analyzing }

/// 리퀴드 글래스 마감 스펙 — STT 카드·CTA 버튼 공통.
class _LiquidGlassSpec {
  static const fill = Color(0xFFF8FAFC);
  static const blurSigma = 16.0;
  static const borderRadius = 14.0;
  static const buttonRadius = 16.0;
  static const buttonHeight = 52.0;

  static BoxDecoration decoration({double radius = borderRadius}) =>
      BoxDecoration(
        color: fill.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(radius),
      );
}

/// 하단 통합 말하기 CTA — Tap to Speak / Tap to finish / 분석 중.
class SpeakLiquidGlassButton extends StatefulWidget {
  final bool isInitializing;
  final bool isRecording;
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback? onComplete;
  final GlobalKey? tourKey;

  const SpeakLiquidGlassButton({
    super.key,
    required this.isInitializing,
    required this.isRecording,
    this.isAnalyzing = false,
    required this.onStart,
    this.onComplete,
    this.tourKey,
  });

  @override
  State<SpeakLiquidGlassButton> createState() => _SpeakLiquidGlassButtonState();
}

class _SpeakLiquidGlassButtonState extends State<SpeakLiquidGlassButton>
    with TickerProviderStateMixin {
  static const _micCyan = Color(0xFF0891B2);
  static const _liveRed = Color(0xFFEF4444);

  late final AnimationController _ripple;
  late final AnimationController _labelWave;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _labelWave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(SpeakLiquidGlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimations();
  }

  void _syncAnimations() {
    if (widget.isRecording) {
      if (!_ripple.isAnimating) _ripple.repeat();
    } else {
      _ripple.stop();
      _ripple.value = 0;
    }
    if (widget.isAnalyzing) {
      if (!_labelWave.isAnimating) _labelWave.repeat();
    } else {
      _labelWave.stop();
      _labelWave.value = 0;
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    _labelWave.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isInitializing || widget.isAnalyzing) return;
    if (widget.isRecording) {
      widget.onComplete?.call();
    } else {
      widget.onStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;
    final analyzing = widget.isAnalyzing;
    final initializing = widget.isInitializing;
    final disabled = initializing || analyzing;
    final label = initializing
        ? '준비 중...'
        : analyzing
            ? 'Analyzing...'
            : recording
                ? 'Tap to finish'
                : 'Tap to Speak';

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(_LiquidGlassSpec.buttonRadius),
      child: kIsWeb
          ? Material(
              color: Colors.transparent,
              child: _speakButtonInk(
                analyzing: analyzing,
                disabled: disabled,
                label: label,
                recording: recording,
                initializing: initializing,
              ),
            )
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _LiquidGlassSpec.blurSigma,
                sigmaY: _LiquidGlassSpec.blurSigma,
              ),
              child: Material(
                color: Colors.transparent,
                child: _speakButtonInk(
                  analyzing: analyzing,
                  disabled: disabled,
                  label: label,
                  recording: recording,
                  initializing: initializing,
                ),
              ),
            ),
    );

    if (widget.tourKey != null) {
      return KeyedSubtree(key: widget.tourKey, child: content);
    }
    return kIsWeb ? content : RepaintBoundary(child: content);
  }

  Widget _speakButtonInk({
    required bool analyzing,
    required bool disabled,
    required String label,
    required bool recording,
    required bool initializing,
  }) {
    return InkWell(
      onTap: disabled ? null : _handleTap,
      borderRadius: BorderRadius.circular(_LiquidGlassSpec.buttonRadius),
      child: Ink(
        decoration: analyzing
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(
                  _LiquidGlassSpec.buttonRadius,
                ),
              )
            : _LiquidGlassSpec.decoration(
                radius: _LiquidGlassSpec.buttonRadius,
              ),
        child: SizedBox(
          height: _LiquidGlassSpec.buttonHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (initializing) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _micCyan,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ] else if (analyzing)
                _AnalyzingLabelWave(
                  text: label,
                  animation: _labelWave,
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: recording
                      ? _MicWithRadialRipple(
                          animation: _ripple,
                          color: _liveRed,
                        )
                      : const Icon(
                          Icons.mic_rounded,
                          size: 18,
                          color: _micCyan,
                        ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: recording ? _liveRed : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Analyzing... — 글자별 subtle 위로 솟구치는 웨이브.
class _AnalyzingLabelWave extends StatelessWidget {
  final String text;
  final Animation<double> animation;

  static const _style = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: Color(0xFF64748B),
    height: 1.2,
  );

  const _AnalyzingLabelWave({
    required this.text,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < text.length; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  -math.max(
                    0.0,
                    math.sin(
                          animation.value * 2 * math.pi - i * 0.55,
                        ) *
                        2.8,
                  ),
                ),
                child: Text(text[i], style: _style),
              ),
          ],
        );
      },
    );
  }
}

/// 마이크 중심 동심원 방사형 잔물결 — Scale 1.0→1.8 + Fade Out.
class _MicWithRadialRipple extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _MicWithRadialRipple({
    required this.animation,
    required this.color,
  });

  static const _ringCount = 3;
  static const _stagger = 0.33;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < _ringCount; i++)
                _RadialRippleRing(
                  progress: (animation.value + i * _stagger) % 1.0,
                  color: color,
                ),
              Icon(Icons.mic_rounded, size: 18, color: color),
            ],
          );
        },
      ),
    );
  }
}

class _RadialRippleRing extends StatelessWidget {
  final double progress;
  final Color color;

  const _RadialRippleRing({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress);
    final scale = 1.0 + eased * 0.8;
    final opacity = (1.0 - progress) * 0.25;

    if (opacity <= 0.01) return const SizedBox.shrink();

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// 메인 카드 플레이헤드 영역 — 재생 컨트롤 / 실시간 STT 텍스트 스트림 /
/// 분석 중 상태를 한 영역 안에서 인플레이스로 모핑한다.
class PronunciationPlayheadMorph extends StatelessWidget {
  final PlayheadVoiceMode mode;
  /// speech_to_text의 partial/final 인식 결과 — 실시간으로 갱신된다.
  final String liveText;
  final Widget playbackChild;

  const PronunciationPlayheadMorph({
    super.key,
    required this.mode,
    required this.liveText,
    required this.playbackChild,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: switch (mode) {
        PlayheadVoiceMode.playback => KeyedSubtree(
            key: const ValueKey('playback'),
            child: playbackChild,
          ),
        PlayheadVoiceMode.listening => _LiveTranscriptCard(
            key: const ValueKey('listening'),
            text: liveText,
          ),
        PlayheadVoiceMode.analyzing => _AnalyzingTranscriptCard(
            key: const ValueKey('analyzing'),
            text: liveText,
          ),
      },
    );
  }
}

/// 실시간 STT 부분/최종 인식 텍스트를 인쇄하는 카드 (녹음 중).
class _LiveTranscriptCard extends StatefulWidget {
  final String text;

  const _LiveTranscriptCard({
    super.key,
    required this.text,
  });

  @override
  State<_LiveTranscriptCard> createState() => _LiveTranscriptCardState();
}

class _LiveTranscriptCardState extends State<_LiveTranscriptCard>
    with SingleTickerProviderStateMixin {
  static const _liveRed = Color(0xFFEF4444);

  late final AnimationController _pulse;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    _stopwatch
      ..reset()
      ..start();
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.trim();
    final liveLabel = '● LIVE ${_formatElapsed(_elapsedSeconds)}';

    return SizedBox(
      height: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_LiquidGlassSpec.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _LiquidGlassSpec.blurSigma,
            sigmaY: _LiquidGlassSpec.blurSigma,
          ),
          child: DecoratedBox(
            decoration: _LiquidGlassSpec.decoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return Text(
                        liveLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: _liveRed.withValues(
                            alpha: 0.72 + 0.28 * _pulse.value,
                          ),
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        displayText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 발음 분석 중 — Typographic Breathing (텍스트 호흡만).
class _AnalyzingTranscriptCard extends StatefulWidget {
  final String text;

  const _AnalyzingTranscriptCard({
    super.key,
    required this.text,
  });

  @override
  State<_AnalyzingTranscriptCard> createState() =>
      _AnalyzingTranscriptCardState();
}

class _AnalyzingTranscriptCardState extends State<_AnalyzingTranscriptCard>
    with SingleTickerProviderStateMixin {
  static const _textSlate = Color(0xFF0F172A);

  late final AnimationController _breath;
  late final Animation<double> _breathOpacity;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _breathOpacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.trim();

    return SizedBox(
      height: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_LiquidGlassSpec.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _LiquidGlassSpec.blurSigma,
            sigmaY: _LiquidGlassSpec.blurSigma,
          ),
          child: DecoratedBox(
            decoration: _LiquidGlassSpec.decoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: AnimatedBuilder(
                  animation: _breathOpacity,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _breathOpacity.value,
                      child: Text(
                        displayText.isEmpty ? '...' : displayText,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textSlate,
                          height: 1.35,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
