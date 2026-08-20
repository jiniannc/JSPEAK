import 'package:flutter/material.dart';

import '../../../app/scenario_providers.dart';
import '../../../core/theme/language_palette.dart';
import '../../../core/utils/answer_blank_hints.dart';
import '../../../core/utils/cjk_spoken_feedback_spans.dart';
import '../../../core/utils/cjk_stt_segments.dart';
import '../../../core/utils/scenario_answer_compare.dart';
import '../../../core/utils/word_compare.dart';
import '../../../data/models/scenario_line.dart';
import '../../../features/dashboard/dashboard_palette.dart';
import '../scenario_word_hints.dart';
import 'scenario_word_hint_bubbles.dart';

/// STT 인식 문장의 틀린 단어만 빨간색·취소선으로 표시.
List<TextSpan> buildSpokenFeedbackSpans({
  required String correctSentence,
  required String spokenText,
  required String language,
  required TextStyle baseStyle,
  Color incorrectColor = Colors.red,
}) {
  if (spokenText.trim().isEmpty) {
    return [TextSpan(text: spokenText, style: baseStyle)];
  }

  if (language == 'English') {
    final spokenWords = WordCompare.splitWords(spokenText);
    final correctWords = WordCompare.splitWords(correctSentence);
    if (spokenWords.isEmpty) {
      return [TextSpan(text: spokenText, style: baseStyle)];
    }
    final spans = <TextSpan>[];
    for (var i = 0; i < spokenWords.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: baseStyle));
      final isMatch = WordCompare.matchesAt(spokenWords, correctWords, i);
      spans.add(
        TextSpan(
          text: spokenWords[i],
          style: baseStyle.copyWith(
            color: isMatch ? baseStyle.color : incorrectColor,
            decoration: isMatch ? null : TextDecoration.lineThrough,
            decorationColor: incorrectColor,
          ),
        ),
      );
    }
    return spans;
  }

  if (CjkSttSegments.isTargetLanguage(language)) {
    return buildCjkSpokenFeedbackSpans(
      correctSentence: correctSentence,
      spokenText: spokenText,
      language: language,
      baseStyle: baseStyle,
      incorrectColor: incorrectColor,
    );
  }

  final spokenChars = spokenText.split('');
  final matchFlags = ScenarioAnswerCompare.spokenCharMatchFlags(
    spoken: spokenText,
    correct: correctSentence,
    language: language,
  );
  final spans = <TextSpan>[];
  for (var i = 0; i < spokenChars.length; i++) {
    final char = spokenChars[i];
    if (char.trim().isEmpty) {
      spans.add(TextSpan(text: char, style: baseStyle));
      continue;
    }
    final isMatch = i < matchFlags.length && matchFlags[i];
    spans.add(
      TextSpan(
        text: char,
        style: baseStyle.copyWith(
          color: isMatch ? baseStyle.color : incorrectColor,
          decoration: isMatch ? null : TextDecoration.lineThrough,
          decorationColor: incorrectColor,
        ),
      ),
    );
  }
  return spans;
}

/// 채팅 말풍선 — 내용 폭에 맞게 줄어들고, 승무원 턴은 힌트/정답으로 변형.
class ScenarioChatBubble extends StatefulWidget {
  final ChatMessage message;
  final Color? accentColor;
  final bool isActive;
  final String liveSpokenText;
  final List<String> blankInputs;
  final int? selectedBlankIndex;
  final ValueChanged<int>? onBlankTap;
  final List<ScenarioWordHint> wordHints;
  final GlobalKey? tourHighlightKey;

  const ScenarioChatBubble({
    super.key,
    required this.message,
    this.accentColor,
    this.isActive = false,
    this.liveSpokenText = '',
    this.blankInputs = const [],
    this.selectedBlankIndex,
    this.onBlankTap,
    this.wordHints = const [],
    this.tourHighlightKey,
  });

  @override
  State<ScenarioChatBubble> createState() => _ScenarioChatBubbleState();
}

class _ScenarioChatBubbleState extends State<ScenarioChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final isPassenger = widget.message.kind == ChatBubbleKind.passenger;
    _enterController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: isPassenger ? 520 : 480),
    );
    final curved = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(isPassenger ? -0.08 : 0.1, 0.22),
      end: Offset.zero,
    ).animate(curved);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.04), weight: 62),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 38),
    ]).animate(curved);
    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isUser = msg.isUser;
    final palette = context.languagePalette;
    final accent =
        widget.accentColor ?? palette?.primary ?? DashboardPalette.teal;
    final maxW = MediaQuery.sizeOf(context).width * 0.88; // 💡 가로폭 살짝 조정

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4), // 💡 양옆 마진 확보
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: IntrinsicWidth(
                  child: Container(
                    key: widget.tourHighlightKey,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? accent.withValues(alpha: widget.isActive ? 0.14 : 0.08)
                          : Colors.white, // 💡 완전한 깔끔 화이트로 변경
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(24),  // 💡 곡률 18 -> 24 확장
                        topRight: const Radius.circular(24), // 💡 곡률 18 -> 24 확장
                        bottomLeft: Radius.circular(isUser ? 24 : 8), // 💡 꼬리 각도 부드럽게
                        bottomRight: Radius.circular(isUser ? 8 : 24),
                      ),
                      border: Border.all(
                        color: widget.isActive
                            ? accent
                            : (isUser
                                ? accent.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.05)), // 💡 선을 엄청 연하게 변경
                        width: widget.isActive ? 2 : 1,
                      ),
                      boxShadow: [
                        // 💡 넓고 은은하게 퍼지는 대기업 스타일 섀도우 적용
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isActive ? 0.06 : 0.03),
                          blurRadius: widget.isActive ? 20 : 12,
                          offset: const Offset(0, 6),
                        ),
                        if (widget.isActive)
                          BoxShadow(
                            color: accent.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: msg.kind == ChatBubbleKind.passenger
                        ? _PassengerBody(line: msg.line)
                        : _CrewTurnBody(
                            message: msg,
                            accent: accent,
                            isActive: widget.isActive,
                            liveSpokenText: widget.liveSpokenText,
                            blankInputs: widget.blankInputs,
                            selectedBlankIndex: widget.selectedBlankIndex,
                            onBlankTap: widget.onBlankTap,
                            wordHints: widget.wordHints,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PassengerBody extends StatefulWidget {
  final ScenarioLine line;

  const _PassengerBody({required this.line});

  @override
  State<_PassengerBody> createState() => _PassengerBodyState();
}

class _PassengerBodyState extends State<_PassengerBody> {
  static const _msPerChar = 40;
  String _visibleTarget = '';
  bool _showKo = false;
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();
    _runTyping();
  }

  Future<void> _runTyping() async {
    final full = widget.line.textTarget;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    for (var i = 1; i <= full.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: _msPerChar));
      if (!mounted) return;
      setState(() {
        _visibleTarget = full.substring(0, i);
        _showCursor = i < full.length;
      });
    }

    if (!mounted) return;
    setState(() => _showCursor = false);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _showKo = true);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RoleChip(
          icon: Icons.person_rounded, // 💡 라운드 아이콘으로 변경
          label: '승객',
          color: DashboardPalette.textMuted,
        ),
        const SizedBox(height: 10), // 💡 간격 8 -> 10 확대
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _visibleTarget,
                style: const TextStyle(
                  fontSize: 16.5, // 💡 시각 밸런스 조정
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.navy,
                  height: 1.4,
                ),
              ),
              if (_showCursor)
                TextSpan(
                  text: '▏',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: DashboardPalette.navy.withValues(alpha: 0.45),
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        if (line.textKo.isNotEmpty)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 380),
            opacity: _showKo ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              offset: _showKo ? Offset.zero : const Offset(0, 0.12),
              child: Padding(
                padding: const EdgeInsets.only(top: 8), // 💡 마진 최적화
                child: Text(
                  line.textKo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: DashboardPalette.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CrewTurnBody extends StatelessWidget {
  final ChatMessage message;
  final Color accent;
  final bool isActive;
  final String liveSpokenText;
  final List<String> blankInputs;
  final int? selectedBlankIndex;
  final ValueChanged<int>? onBlankTap;
  final List<ScenarioWordHint> wordHints;

  const _CrewTurnBody({
    required this.message,
    required this.accent,
    required this.isActive,
    required this.liveSpokenText,
    this.blankInputs = const [],
    this.selectedBlankIndex,
    this.onBlankTap,
    this.wordHints = const [],
  });

  @override
  Widget build(BuildContext context) {
    final line = message.line;
    final resolved = message.isResolved;
    final spokenForBlanks = isActive
        ? liveSpokenText
        : (message.spokenText ?? '');
    final showPronunciation =
        line.language == 'Japanese' || line.language == 'Chinese';

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!resolved) ...[
            _RoleChip(
              icon: Icons.badge_rounded, // 💡 라운드 아이콘으로 변경
              label: '승무원',
              color: accent,
            ),
            const SizedBox(height: 10), // 💡 간격 확대
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(opacity: anim, child: child);
            },
            child: resolved
                ? KeyedSubtree(
                    key: const ValueKey('resolved'),
                    child: _ResolvedContent(
                      line: line,
                      accent: accent,
                      showPronunciation: showPronunciation,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('speaking'),
                    child: _SpeakingContent(
                      line: line,
                      accent: accent,
                      showBlankFrame: message.showBlankFrame,
                      spokenForBlanks: spokenForBlanks,
                      blankInputs: blankInputs,
                      selectedBlankIndex: selectedBlankIndex,
                      onBlankTap: onBlankTap,
                      showPronunciation: showPronunciation,
                      showWordHints: message.showWordHints,
                      wordHints: wordHints,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpeakingContent extends StatefulWidget {
  final ScenarioLine line;
  final Color accent;
  final bool showBlankFrame;
  final String spokenForBlanks;
  final List<String> blankInputs;
  final int? selectedBlankIndex;
  final ValueChanged<int>? onBlankTap;
  final bool showPronunciation;
  final bool showWordHints;
  final List<ScenarioWordHint> wordHints;

  const _SpeakingContent({
    required this.line,
    required this.accent,
    required this.showBlankFrame,
    required this.spokenForBlanks,
    this.blankInputs = const [],
    this.selectedBlankIndex,
    this.onBlankTap,
    this.showPronunciation = false,
    this.showWordHints = false,
    this.wordHints = const [],
  });

  @override
  State<_SpeakingContent> createState() => _SpeakingContentState();
}

class _SpeakingContentState extends State<_SpeakingContent> {
  final Set<int> _dismissedHintRuns = {};

  @override
  void didUpdateWidget(covariant _SpeakingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showWordHints) {
      _dismissedHintRuns.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final accent = widget.accent;
    final showWordHints = widget.showWordHints;
    final wordHints = widget.wordHints;
    final structureOn =
        widget.showBlankFrame && line.blankFrame.trim().isNotEmpty;

    // ConstrainedBox(maxWidth: screen*0.88) − 말풍선 좌우 패딩 18*2
    final blankMaxW = MediaQuery.sizeOf(context).width * 0.88 - 36;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.textKo,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: DashboardPalette.navy,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        AnswerBlankHintView(
          correctSentence: line.textTarget,
          spokenText: widget.spokenForBlanks,
          language: line.language,
          accentColor: accent,
          fontSize: 16.5,
          maxWidth: blankMaxW,
          blankFrame: line.blankFrame,
          structureRevealed: structureOn,
          blankInputs: widget.blankInputs,
          selectedBlankIndex: widget.selectedBlankIndex,
          onBlankTap: structureOn ? widget.onBlankTap : null,
          showHintRunLabels: showWordHints && wordHints.length >= 2,
        ),
        if (showWordHints && wordHints.isNotEmpty)
          ScenarioWordHintLane(
            hints: wordHints,
            dismissedRunIndices: _dismissedHintRuns,
            gradient: context.languagePalette?.speechBubbleGradient ??
                [
                  Color.lerp(accent, Colors.white, 0.28)!,
                  accent,
                ],
            shadowColor: context.languagePalette?.primary ?? accent,
            onDismiss: (runIndex) =>
                setState(() => _dismissedHintRuns.add(runIndex)),
          ),
        if (structureOn &&
            widget.showPronunciation &&
            line.pronunciation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            line.pronunciation,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: DashboardPalette.textMuted,
              height: 1.45,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

/// 정답 공개 — 'Correct' 배지 + 바운스·샤인 연출.
class _ResolvedContent extends StatefulWidget {
  final ScenarioLine line;
  final Color accent;
  final bool showPronunciation;

  const _ResolvedContent({
    required this.line,
    required this.accent,
    required this.showPronunciation,
  });

  @override
  State<_ResolvedContent> createState() => _ResolvedContentState();
}

class _ResolvedContentState extends State<_ResolvedContent>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _shineCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeFade;
  late final Animation<double> _shine;
  bool _shineDone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.1), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.97), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _badgeScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.18), weight: 55),
          TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 45),
        ]).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.08, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _badgeFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.05, 0.4, curve: Curves.easeOut),
    );
    _shine = Tween<double>(
      begin: -1.2,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut));
    _shineCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _shineDone = true);
      }
    });
    _ctrl.forward();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _shineCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  Widget _answerText(Color accent, double maxWidth) {
    const style = TextStyle(
      fontSize: 16.5,
      fontWeight: FontWeight.w800,
      height: 1.35,
      letterSpacing: -0.2,
    );
    final text = _shineDone
        ? Text(
            widget.line.textTarget,
            style: style.copyWith(
              color: Color.lerp(accent, DashboardPalette.navy, 0.15),
            ),
          )
        : AnimatedBuilder(
            animation: _shine,
            builder: (context, child) {
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  final t = _shine.value;
                  return LinearGradient(
                    begin: Alignment(-1 + t, 0),
                    end: Alignment(t, 0),
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.white, 0.55)!,
                      Color.lerp(accent, DashboardPalette.navy, 0.2)!,
                    ],
                    stops: const [0.25, 0.5, 0.75],
                  ).createShader(bounds);
                },
                child: child,
              );
            },
            child: Text(
              widget.line.textTarget,
              style: style,
            ),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final accent = widget.accent;
    final textMaxW = MediaQuery.sizeOf(context).width * 0.88 - 36;
    const success = Color(0xFF0C9E6E); // 💡 살짝 청량한 초록으로 변경

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RoleChip(
                  icon: Icons.badge_rounded,
                  label: '정답',
                  color: accent,
                ),
                const SizedBox(width: 8),
                FadeTransition(
                  opacity: _badgeFade,
                  child: ScaleTransition(
                    scale: _badgeScale,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            success,
                            Color.lerp(success, accent, 0.25)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: success.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Correct',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _answerText(accent, textMaxW),
            if (widget.showPronunciation && line.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                line.pronunciation,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: DashboardPalette.textMuted,
                  height: 1.45,
                  letterSpacing: 0.2,
                ),
              ),
            ],
            if (line.textKo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                line.textKo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.navy,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RoleChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)), // 💡 연하게 처리
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // 💡 11 -> 12 확장
            fontWeight: FontWeight.w800, // 💡 700 -> 800 더 단단하게
            color: color.withValues(alpha: 0.8),
            letterSpacing: 0.3, // 💡 자간 튜닝
          ),
        ),
      ],
    );
  }
}