import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/labels.dart';
import '../../../core/theme/language_palette.dart';
import '../../dashboard/dashboard_palette.dart';

/// Hero 타이틀 — 선택 언어를 테마색으로 강조.
class DictionaryHeroTitle extends StatelessWidget {
  final String language;
  final LanguagePalette palette;

  const DictionaryHeroTitle({
    super.key,
    required this.language,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return DictionaryHeroTitleAnimated(
      progress: const AlwaysStoppedAnimation(1),
      language: language,
      palette: palette,
    );
  }
}

/// Hero 타이틀 타이핑 입장 애니메이션 + 주사위 리롤 버튼.
///
/// [progress]의 매 프레임마다 통째로 다시 빌드하면 텍스트 내용이 그대로인
/// 프레임에서도 RichText 문단 레이아웃을 새로 만들게 되어, Web CanvasKit에서
/// 짧은 시간에 문단 레이아웃 요청이 몰려 렌더러가 죽는(Aborted) 문제로 이어질
/// 수 있다. 바깥의 페이드는 매 프레임 리페인트만 하도록 유지하고, 실제 타이핑
/// 텍스트는 보여줄 글자 수가 바뀔 때만 다시 빌드하도록 분리한다.
class DictionaryHeroTitleAnimated extends StatelessWidget {
  final Animation<double> progress;
  final String language;
  final LanguagePalette palette;
  final VoidCallback? onDiceTap;
  final Animation<double>? diceSpin;

  const DictionaryHeroTitleAnimated({
    super.key,
    required this.progress,
    required this.language,
    required this.palette,
    this.onDiceTap,
    this.diceSpin,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return Opacity(
          opacity: progress.value.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: _TypingHeroContent(
        progress: progress,
        language: language,
        palette: palette,
        onDiceTap: onDiceTap,
        diceSpin: diceSpin,
      ),
    );
  }
}

class _TypingHeroContent extends StatefulWidget {
  final Animation<double> progress;
  final String language;
  final LanguagePalette palette;
  final VoidCallback? onDiceTap;
  final Animation<double>? diceSpin;

  const _TypingHeroContent({
    required this.progress,
    required this.language,
    required this.palette,
    required this.onDiceTap,
    required this.diceSpin,
  });

  @override
  State<_TypingHeroContent> createState() => _TypingHeroContentState();
}

class _TypingHeroContentState extends State<_TypingHeroContent> {
  int _visibleChars = -1;
  bool _showClosingQuote = false;
  bool _showDice = false;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onTick);
    _sync(force: true);
  }

  @override
  void didUpdateWidget(covariant _TypingHeroContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_onTick);
      widget.progress.addListener(_onTick);
    }
    if (oldWidget.language != widget.language) {
      _sync(force: true);
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onTick);
    super.dispose();
  }

  int get _totalChars {
    final langLabel = languageLabel(widget.language);
    return '어떤 '.length + langLabel.length + ' 기내 표현이 궁금하신가요?'.length;
  }

  void _onTick() => _sync();

  void _sync({bool force = false}) {
    final value = widget.progress.value;
    final totalChars = _totalChars;
    final visibleChars = (totalChars * value).floor().clamp(0, totalChars);
    final showClosingQuote = value >= 0.98;
    final showDice = widget.onDiceTap != null && value >= 0.72;

    if (!force &&
        visibleChars == _visibleChars &&
        showClosingQuote == _showClosingQuote &&
        showDice == _showDice) {
      return;
    }
    setState(() {
      _visibleChars = visibleChars;
      _showClosingQuote = showClosingQuote;
      _showDice = showDice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final langLabel = languageLabel(widget.language);
    const baseStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: DashboardPalette.navy,
      letterSpacing: -0.35,
      height: 1.2,
    );
    final langStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w900,
      color: widget.palette.primary,
      shadows: [
        Shadow(
          color: widget.palette.accent.withValues(alpha: 0.35),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );

    final typedSegments = <(String, TextStyle)>[
      ('어떤 ', baseStyle),
      (langLabel, langStyle),
      (' 기내 표현이 궁금하신가요?', baseStyle),
    ];

    var remaining = _visibleChars.clamp(0, _totalChars);
    final spans = <InlineSpan>[];
    for (final (text, style) in typedSegments) {
      if (remaining <= 0) break;
      final take = remaining < text.length ? remaining : text.length;
      spans.add(TextSpan(text: text.substring(0, take), style: style));
      remaining -= take;
    }

    final maxTextWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.58,
      360.0,
    );
    const diceSlotWidth = 36.0;

    final quotedText = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroQuoteMark(
          opening: true,
          color: widget.palette.primary,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxTextWidth),
          child: Text.rich(
            TextSpan(style: baseStyle, children: spans),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 4),
        Opacity(
          opacity: _showClosingQuote ? 1 : 0,
          child: _HeroQuoteMark(
            opening: false,
            color: widget.palette.primary,
          ),
        ),
      ],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onDiceTap != null) const SizedBox(width: diceSlotWidth),
        quotedText,
        if (widget.onDiceTap != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 36,
                    left: -78,
                    right: -78,
                      child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _DiceHintBubble(
                        visible: _showDice,
                        palette: widget.palette,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showDice ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !_showDice,
                      child: DictionaryDiceRerollButton(
                        spin: widget.diceSpin,
                        palette: widget.palette,
                        onTap: widget.onDiceTap!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 주사위 버튼 안내 말풍선 — 등장 + 부드러운 플로팅 애니메이션.
class _DiceHintBubble extends StatefulWidget {
  final bool visible;
  final LanguagePalette palette;

  const _DiceHintBubble({
    required this.visible,
    required this.palette,
  });

  @override
  State<_DiceHintBubble> createState() => _DiceHintBubbleState();
}

class _DiceHintBubbleState extends State<_DiceHintBubble>
    with TickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 520);
  static const _floatDuration = Duration(milliseconds: 2200);

  late final AnimationController _enterController;
  late final AnimationController _floatController;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: _enterDuration,
    );
    _floatController = AnimationController(
      vsync: this,
      duration: _floatDuration,
    );
    _syncVisibility(force: true);
  }

  @override
  void didUpdateWidget(covariant _DiceHintBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      _syncVisibility();
    }
  }

  void _syncVisibility({bool force = false}) {
    _revealTimer?.cancel();
    if (widget.visible) {
      _revealTimer = Timer(const Duration(milliseconds: 320), () {
        if (!mounted || !widget.visible) return;
        _enterController.forward(from: 0);
        if (!_floatController.isAnimating) {
          _floatController.repeat(reverse: true);
        }
      });
      if (force && widget.visible) {
        _enterController.value = 0;
      }
    } else {
      _enterController.reverse();
      _floatController.stop();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _floatController]),
      builder: (context, _) {
        final enterT =
            Curves.easeOutBack.transform(_enterController.value.clamp(0.0, 1.0));
        final floatY = math.sin(_floatController.value * math.pi) * 2.5;

        return IgnorePointer(
          ignoring: _enterController.value < 0.04,
          child: Opacity(
            opacity: _enterController.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, floatY + 10 * (1 - enterT)),
              child: Transform.scale(
                scale: 0.78 + 0.22 * enterT,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(
                  painter: _SleekSpeechBubblePainter(
                    gradient: widget.palette.speechBubbleGradient,
                    shadowColor: widget.palette.primary,
                    shadowStrength:
                        0.18 + 0.1 * math.sin(_floatController.value * math.pi),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(14, 9, 14, 17),
                    child: Text(
                      '탭하면 추천 #태그가\n랜덤으로 바뀌어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                        letterSpacing: -0.15,
                        color: Colors.white,
                      ),
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

/// 둥근 몸통 + 꼬리가 이어진 슬릭 말풍선 (테두리 없음).
class _SleekSpeechBubblePainter extends CustomPainter {
  final List<Color> gradient;
  final Color shadowColor;
  final double shadowStrength;

  const _SleekSpeechBubblePainter({
    required this.gradient,
    required this.shadowColor,
    this.shadowStrength = 0.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 20.0;
    const tailWidth = 11.0;
    const tailHeight = 8.0;
    final bodyBottom = size.height - tailHeight;
    final tailCenterX = size.width * 0.54;
    final fillTop = gradient.first;
    final fillBottom = gradient.length > 1 ? gradient.last : gradient.first;

    final bubblePath = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, bodyBottom - radius)
      ..arcToPoint(
        Offset(size.width - radius, bodyBottom),
        radius: const Radius.circular(radius),
      )
      ..lineTo(tailCenterX + tailWidth / 2, bodyBottom)
      ..quadraticBezierTo(
        tailCenterX,
        bodyBottom + tailHeight + 1.5,
        tailCenterX - tailWidth / 2,
        bodyBottom,
      )
      ..lineTo(radius, bodyBottom)
      ..arcToPoint(
        Offset(0, bodyBottom - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(0, radius)
      ..arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      )
      ..close();

    canvas.drawShadow(
      bubblePath,
      shadowColor.withValues(alpha: shadowStrength),
      10,
      false,
    );

    canvas.drawPath(
      bubblePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ).createShader(Rect.fromLTWH(0, 0, size.width, bodyBottom)),
    );

    canvas.save();
    canvas.clipPath(bubblePath);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, bodyBottom * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, bodyBottom * 0.45)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SleekSpeechBubblePainter oldDelegate) {
    return oldDelegate.shadowStrength != shadowStrength ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.gradient != gradient;
  }
}

/// 추천 태그 리롤 — 브랜드 블루 미니 원형 버튼 + 180° 회전.
class DictionaryDiceRerollButton extends StatefulWidget {
  final Animation<double>? spin;
  final LanguagePalette palette;
  final VoidCallback onTap;

  const DictionaryDiceRerollButton({
    super.key,
    required this.onTap,
    required this.palette,
    this.spin,
  });

  @override
  State<DictionaryDiceRerollButton> createState() =>
      _DictionaryDiceRerollButtonState();
}

class _DictionaryDiceRerollButtonState extends State<DictionaryDiceRerollButton> {
  static const _spinDuration = Duration(milliseconds: 480);

  double _turns = 0;
  Animation<double>? _boundSpin;

  @override
  void initState() {
    super.initState();
    _bindSpin(widget.spin);
  }

  @override
  void didUpdateWidget(covariant DictionaryDiceRerollButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spin != widget.spin) {
      _bindSpin(widget.spin);
    }
  }

  void _bindSpin(Animation<double>? spin) {
    _boundSpin?.removeStatusListener(_onSpinStatus);
    _boundSpin = spin;
    _boundSpin?.addStatusListener(_onSpinStatus);
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      setState(() => _turns += 0.5);
    }
  }

  @override
  void dispose() {
    _boundSpin?.removeStatusListener(_onSpinStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.palette.searchAccent;
    final buttonBg = widget.palette.diceButtonBackground;

    return AnimatedRotation(
      turns: _turns,
      duration: _spinDuration,
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonBg,
            ),
            child: Icon(
              Icons.casino_outlined,
              size: 18,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroQuoteMark extends StatelessWidget {
  final bool opening;
  final Color color;

  const _HeroQuoteMark({
    required this.opening,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: opening ? 0 : 2),
      child: Text(
        opening ? '“' : '”',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: -1,
          color: color.withValues(alpha: 0.28),
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

/// 퀵 검색 해시태그 — Important 단어 meaning 칩.
class DictionaryQuickSearchChips extends StatefulWidget {
  final List<String> tags;
  final int generation;
  final LanguagePalette palette;
  final ValueChanged<String> onTagSelected;
  final List<Animation<double>>? entryAnimations;

  const DictionaryQuickSearchChips({
    super.key,
    required this.tags,
    required this.generation,
    required this.palette,
    required this.onTagSelected,
    this.entryAnimations,
  });

  @override
  State<DictionaryQuickSearchChips> createState() =>
      _DictionaryQuickSearchChipsState();
}

class _DictionaryQuickSearchChipsState extends State<DictionaryQuickSearchChips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swapController;

  @override
  void initState() {
    super.initState();
    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (widget.generation > 0) {
      _swapController.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant DictionaryQuickSearchChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) {
      _swapController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _swapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _swapController,
      builder: (context, _) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.tags.length; i++)
                _buildChip(i, widget.tags[i]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(int index, String label) {
    final entryAnim = widget.entryAnimations != null &&
            index < widget.entryAnimations!.length
        ? widget.entryAnimations![index]
        : null;

    if (entryAnim != null && widget.generation == 0) {
      return _EntryAnimatedChip(
        animation: entryAnim,
        child: _GlassQuickChip(
          label: label,
          palette: widget.palette,
          onTap: () => widget.onTagSelected(label),
        ),
      );
    }

    final start = index * 0.08;
    final end = math.min(start + 0.72, 1.0);
    final curved = CurvedAnimation(
      parent: _swapController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: Transform.scale(
              scale: 0.88 + 0.12 * t,
              child: child,
            ),
          ),
        );
      },
      child: _GlassQuickChip(
        label: label,
        palette: widget.palette,
        onTap: () => widget.onTagSelected(label),
      ),
    );
  }
}

class _EntryAnimatedChip extends StatelessWidget {
  final Animation<double>? animation;
  final Widget child;

  const _EntryAnimatedChip({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final anim = animation;
    if (anim == null) return child;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: FractionalTranslation(
            translation: Offset(0, 0.3 * (1 - anim.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _GlassQuickChip extends StatelessWidget {
  final String label;
  final LanguagePalette palette;
  final VoidCallback onTap;

  const _GlassQuickChip({
    required this.label,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = palette.searchAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.05),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: palette.searchTagBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '#$label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: palette.searchTagForeground,
            ),
          ),
        ),
      ),
    );
  }
}
