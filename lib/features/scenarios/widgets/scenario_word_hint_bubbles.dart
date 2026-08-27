import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/hint_run_badge.dart';
import '../../../shared/widgets/sleek_speech_bubble.dart';
import '../scenario_word_hints.dart';

/// 언더라인 바 아래에 배치되는 두 번째 힌트 말풍선 줄.
class ScenarioWordHintLane extends StatelessWidget {
  final List<ScenarioWordHint> hints;
  final Set<int> dismissedRunIndices;
  final List<Color> gradient;
  final Color shadowColor;
  final ValueChanged<int> onDismiss;

  const ScenarioWordHintLane({
    super.key,
    required this.hints,
    required this.dismissedRunIndices,
    required this.gradient,
    required this.shadowColor,
    required this.onDismiss,
  });

  bool get _showRunLabels => hints.length >= 2;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var runIndex = 0; runIndex < hints.length; runIndex++) {
      if (dismissedRunIndices.contains(runIndex)) continue;
      chips.add(
        ScenarioWordHintChip(
          key: ValueKey('hint_$runIndex'),
          hint: hints[runIndex],
          gradient: gradient,
          shadowColor: shadowColor,
          staggerIndex: runIndex,
          labelNumber: _showRunLabels ? runIndex + 1 : null,
          onDismiss: () => onDismiss(runIndex),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      ),
    );
  }
}

class ScenarioWordHintChip extends StatelessWidget {
  final ScenarioWordHint hint;
  final List<Color> gradient;
  final Color shadowColor;
  final int staggerIndex;
  final int? labelNumber;
  final VoidCallback onDismiss;

  const ScenarioWordHintChip({
    super.key,
    required this.hint,
    required this.gradient,
    required this.shadowColor,
    required this.staggerIndex,
    this.labelNumber,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final meaning = hint.meaning?.trim();
    final label = (meaning != null && meaning.isNotEmpty)
        ? meaning
        : '사전 정보를 찾지 못했어요';

    return SleekSpeechBubble(
      gradient: gradient,
      shadowColor: shadowColor,
      staggerIndex: staggerIndex,
      float: false,
      showTail: false,
      cornerRadius: 10,
      contentPadding: const EdgeInsets.fromLTRB(7, 4, 2, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (labelNumber != null) ...[
            HintRunBadge(
              number: labelNumber!,
              color: shadowColor,
              size: 13,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: _PopRevealHintText(
              text: label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.12,
                color: Colors.white,
              ),
              revealDelayMs: 120 + staggerIndex * 140,
            ),
          ),
          _InlineDismissButton(onTap: onDismiss),
        ],
      ),
    );
  }
}

/// 힌트 뜻 — 글자를 무작위 순서로 아래에서 튀어 오르게 공개.
class _PopRevealHintText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int revealDelayMs;

  const _PopRevealHintText({
    required this.text,
    required this.style,
    this.revealDelayMs = 0,
  });

  @override
  State<_PopRevealHintText> createState() => _PopRevealHintTextState();
}

class _PopRevealHintTextState extends State<_PopRevealHintText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<int> _order;

  @override
  void initState() {
    super.initState();
    final units = widget.text.characters.toList();
    _order = List<int>.generate(units.length, (i) => i)..shuffle(math.Random());
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (420 + units.length * 72).clamp(420, 2200),
      ),
    );
    Future<void>.delayed(Duration(milliseconds: widget.revealDelayMs), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _unitT(int index) {
    if (_order.isEmpty) return 1.0;
    final pos = _order.indexOf(index);
    if (pos < 0) return 1.0;
    const slot = 0.12;
    final start = pos / _order.length * (1.0 - slot);
    final t = _controller.value;
    if (t <= start) return 0.0;
    return ((t - start) / slot).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var i = 0; i < units.length; i++)
              _PopChar(
                char: units[i],
                style: widget.style,
                t: _unitT(i),
              ),
          ],
        );
      },
    );
  }
}

class _PopChar extends StatelessWidget {
  final String char;
  final TextStyle style;
  final double t;

  const _PopChar({
    required this.char,
    required this.style,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    if (char == ' ') {
      return SizedBox(width: style.fontSize != null ? style.fontSize! * 0.28 : 3);
    }

    final pop = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    return Transform.translate(
      offset: Offset(0, 10 * (1 - pop)),
      child: Transform.scale(
        scale: 0.4 + 0.6 * pop,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: pop.clamp(0.0, 1.0),
          child: Text(char, style: style),
        ),
      ),
    );
  }
}

class _InlineDismissButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InlineDismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.14),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
          child: Icon(
            Icons.close_rounded,
            size: 13,
            color: Color(0xCCFFFFFF),
          ),
        ),
      ),
    );
  }
}
