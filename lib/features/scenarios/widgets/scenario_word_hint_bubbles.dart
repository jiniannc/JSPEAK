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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.12,
                color: Colors.white,
              ),
            ),
          ),
          _InlineDismissButton(onTap: onDismiss),
        ],
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
