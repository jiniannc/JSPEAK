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
  final int diceRestFace;
  final int diceSpinFromFace;

  const DictionaryHeroTitleAnimated({
    super.key,
    required this.progress,
    required this.language,
    required this.palette,
    this.onDiceTap,
    this.diceSpin,
    this.diceRestFace = 5,
    this.diceSpinFromFace = 5,
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
        diceRestFace: diceRestFace,
        diceSpinFromFace: diceSpinFromFace,
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
  final int diceRestFace;
  final int diceSpinFromFace;

  const _TypingHeroContent({
    required this.progress,
    required this.language,
    required this.palette,
    required this.onDiceTap,
    required this.diceSpin,
    required this.diceRestFace,
    required this.diceSpinFromFace,
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
      fontSize: 17,
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
    const diceSlotWidth = 42.0;

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
            child: AnimatedOpacity(
              opacity: _showDice ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_showDice,
                child: DictionaryDiceRerollButton(
                  accent: widget.palette.primary,
                  spin: widget.diceSpin,
                  restFace: widget.diceRestFace,
                  spinFromFace: widget.diceSpinFromFace,
                  onTap: widget.onDiceTap!,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 주사위 탭 — 3D 회전 + 바운스 + 1~6 면 전환 + 대기(탭 유도) 애니메이션.
class DictionaryDiceRerollButton extends StatefulWidget {
  final Color accent;
  final Animation<double>? spin;
  final VoidCallback onTap;
  final int restFace;
  final int spinFromFace;

  const DictionaryDiceRerollButton({
    super.key,
    required this.accent,
    required this.onTap,
    this.spin,
    this.restFace = 5,
    this.spinFromFace = 5,
  });

  @override
  State<DictionaryDiceRerollButton> createState() =>
      _DictionaryDiceRerollButtonState();
}

class _DictionaryDiceRerollButtonState extends State<DictionaryDiceRerollButton>
    with SingleTickerProviderStateMixin {
  static const _idleCycle = Duration(milliseconds: 3000);

  late final AnimationController _idleController;
  Animation<double>? _boundSpin;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: _idleCycle,
    );
    _bindSpin(widget.spin);
    _startIdleIfAllowed();
  }

  @override
  void didUpdateWidget(covariant DictionaryDiceRerollButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spin != widget.spin) {
      _bindSpin(widget.spin);
      _startIdleIfAllowed();
    }
  }

  void _bindSpin(Animation<double>? spin) {
    _boundSpin?.removeStatusListener(_onSpinStatus);
    _boundSpin = spin;
    _boundSpin?.addStatusListener(_onSpinStatus);
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      _idleController.stop();
      return;
    }
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _startIdleIfAllowed();
    }
  }

  void _startIdleIfAllowed() {
    if (!mounted) return;
    if (_boundSpin?.isAnimating == true) return;
    if (!_idleController.isAnimating) {
      _idleController.repeat();
    }
  }

  @override
  void dispose() {
    _boundSpin?.removeStatusListener(_onSpinStatus);
    _idleController.dispose();
    super.dispose();
  }

  ({double rotY, double rotX, double lift, double scale, double glow})
      _idleMotion(double phase) {
    const baseRotX = 0.32;

    if (phase < 0.68) {
      final breathe = math.sin(phase / 0.68 * math.pi * 2) * 0.018;
      return (
        rotY: 0,
        rotX: baseRotX,
        lift: 0,
        scale: 1 + breathe,
        glow: 0.06 + breathe * 2.5,
      );
    }

    final t = ((phase - 0.68) / 0.32).clamp(0.0, 1.0);
    final envelope = math.sin(t * math.pi);
    final wiggle = math.sin(t * math.pi * 4.2);

    return (
      rotY: wiggle * envelope * 0.62,
      rotX: baseRotX + envelope * 0.14,
      lift: envelope * 4.5,
      scale: 1 + envelope * 0.08,
      glow: envelope * 0.48,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spinAnim = widget.spin;

    if (spinAnim == null) {
      return AnimatedBuilder(
        animation: _idleController,
        builder: (context, _) {
          final idle = _idleMotion(_idleController.value);
          return _DiceFace(
            accent: widget.accent,
            onTap: widget.onTap,
            rotationY: idle.rotY,
            rotationX: idle.rotX,
            lift: idle.lift,
            scale: idle.scale,
            glowStrength: idle.glow,
            dice: _ColorfulDiceVisual(
              accent: widget.accent,
              face: widget.restFace,
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([spinAnim, _idleController]),
      builder: (context, _) {
        final raw = spinAnim.value;
        final t = Curves.easeInOutCubic.transform(raw);
        final spinning = spinAnim.isAnimating;

        var rotationY = spinning ? t * 3.6 * math.pi : 0.0;
        var rotationX = spinning
            ? 0.32 + math.sin(t * 3.6 * math.pi * 1.4) * 0.18
            : 0.32;
        var lift = spinning ? math.sin(t * math.pi) * 5.0 : 0.0;
        var scale = 1.0;
        var glowStrength = 0.0;

        if (!spinning) {
          final idle = _idleMotion(_idleController.value);
          rotationY += idle.rotY;
          rotationX += idle.rotX - 0.32;
          lift += idle.lift;
          scale = idle.scale;
          glowStrength = idle.glow;
        }

        final spinStep = (rotationY / (math.pi / 2.05)).floor().abs();
        final face = spinning
            ? ((widget.spinFromFace - 1 + spinStep) % 6) + 1
            : widget.restFace;

        return _DiceFace(
          accent: widget.accent,
          onTap: widget.onTap,
          rotationY: rotationY,
          rotationX: rotationX,
          lift: lift,
          scale: scale,
          glowStrength: glowStrength,
          dice: _ColorfulDiceVisual(accent: widget.accent, face: face),
        );
      },
    );
  }
}

class _DiceFace extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  final double rotationY;
  final double rotationX;
  final double lift;
  final double scale;
  final double glowStrength;
  final Widget dice;

  const _DiceFace({
    required this.accent,
    required this.onTap,
    required this.rotationY,
    required this.rotationX,
    required this.lift,
    this.scale = 1,
    this.glowStrength = 0,
    required this.dice,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: accent.withValues(alpha: 0.14),
        highlightColor: accent.withValues(alpha: 0.08),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (glowStrength > 0.01)
                IgnorePointer(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: 0.22 * glowStrength,
                          ),
                          blurRadius: 8 + 10 * glowStrength,
                          spreadRadius: 0.5 + 1.5 * glowStrength,
                        ),
                      ],
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, -lift),
                child: Transform.scale(
                  scale: scale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(rotationX)
                      ..rotateY(rotationY),
                    child: dice,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 등각(isometric) 투영 육각형 주사위 — MaskFilter 없이 Path만 사용.
class _ColorfulDiceVisual extends StatelessWidget {
  final Color accent;
  final int face;

  const _ColorfulDiceVisual({
    required this.accent,
    this.face = 5,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(32, 28),
        painter: _IsometricDicePainter(
          accent: accent,
          face: face.clamp(1, 6),
        ),
      ),
    );
  }
}

class _IsometricDiceGeometry {
  static const _sqrt3Over2 = 0.8660254037844386;

  final double edge;
  final Offset origin;

  const _IsometricDiceGeometry({
    required this.edge,
    required this.origin,
  });

  double get w => edge * _sqrt3Over2;
  double get h => edge * 0.5;

  Offset get top => origin;
  Offset get upperRight => origin + Offset(w, h);
  Offset get lowerRight => origin + Offset(w, h + edge);
  Offset get bottom => origin + Offset(0, edge * 2);
  Offset get lowerLeft => origin + Offset(-w, h + edge);
  Offset get upperLeft => origin + Offset(-w, h);
  Offset get topFaceBottom => origin + Offset(0, edge);

  Path get hexOutline => Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(upperRight.dx, upperRight.dy)
    ..lineTo(lowerRight.dx, lowerRight.dy)
    ..lineTo(bottom.dx, bottom.dy)
    ..lineTo(lowerLeft.dx, lowerLeft.dy)
    ..lineTo(upperLeft.dx, upperLeft.dy)
    ..close();

  Path get leftFace => Path()
    ..moveTo(upperLeft.dx, upperLeft.dy)
    ..lineTo(topFaceBottom.dx, topFaceBottom.dy)
    ..lineTo(bottom.dx, bottom.dy)
    ..lineTo(lowerLeft.dx, lowerLeft.dy)
    ..close();

  Path get rightFace => Path()
    ..moveTo(upperRight.dx, upperRight.dy)
    ..lineTo(lowerRight.dx, lowerRight.dy)
    ..lineTo(bottom.dx, bottom.dy)
    ..lineTo(topFaceBottom.dx, topFaceBottom.dy)
    ..close();

  Path get topFace => Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(upperRight.dx, upperRight.dy)
    ..lineTo(topFaceBottom.dx, topFaceBottom.dy)
    ..lineTo(upperLeft.dx, upperLeft.dy)
    ..close();

  /// [-1, 1] 정규 좌표 → 윗면 마름모 위 점.
  Offset pipPosition(double ax, double ay) {
    final x = ax * w * 0.74;
    final y = edge * 0.52 + ay * edge * 0.36;
    return Offset(origin.dx + x, origin.dy + y);
  }
}

class _IsometricDicePainter extends CustomPainter {
  final Color accent;
  final int face;

  const _IsometricDicePainter({
    required this.accent,
    required this.face,
  });

  static const _pipColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
  ];

  static const _facePipOffsets = <int, List<Offset>>{
    1: [Offset(0, 0)],
    2: [Offset(-0.68, -0.68), Offset(0.68, 0.68)],
    3: [
      Offset(-0.68, -0.68),
      Offset(0, 0),
      Offset(0.68, 0.68),
    ],
    4: [
      Offset(-0.68, -0.68),
      Offset(0.68, -0.68),
      Offset(-0.68, 0.68),
      Offset(0.68, 0.68),
    ],
    5: [
      Offset(-0.68, -0.68),
      Offset(0.68, -0.68),
      Offset(0, 0),
      Offset(-0.68, 0.68),
      Offset(0.68, 0.68),
    ],
    6: [
      Offset(-0.68, -0.82),
      Offset(-0.68, 0),
      Offset(-0.68, 0.82),
      Offset(0.68, -0.82),
      Offset(0.68, 0),
      Offset(0.68, 0.82),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    const edge = 11.0;
    final geo = _IsometricDiceGeometry(
      edge: edge,
      origin: Offset(size.width / 2, 3.5),
    );

    canvas.save();
    canvas.translate(1.2, 2.4);
    canvas.drawPath(
      geo.hexOutline,
      Paint()..color = const Color(0xFF1E293B).withValues(alpha: 0.13),
    );
    canvas.restore();

    final leftPaint = Paint()
      ..color = Color.lerp(accent, const Color(0xFF1E3A5F), 0.55)!;
    final rightPaint = Paint()
      ..color = Color.lerp(accent, Colors.white, 0.28)!;

    canvas.drawPath(geo.leftFace, leftPaint);
    canvas.drawPath(geo.rightFace, rightPaint);

    final topBounds = Rect.fromPoints(geo.upperLeft, geo.lowerRight);
    canvas.drawPath(
      geo.topFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(accent, Colors.white, 0.92)!,
            Colors.white,
          ],
        ).createShader(topBounds),
    );

    canvas.drawPath(
      geo.topFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ).createShader(topBounds),
    );

    canvas.drawPath(
      geo.hexOutline,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65
        ..strokeJoin = StrokeJoin.round,
    );

    final pips = _facePipOffsets[face] ?? _facePipOffsets[5]!;
    for (var i = 0; i < pips.length; i++) {
      final center = geo.pipPosition(pips[i].dx, pips[i].dy);
      final pipColor = _pipColors[i % _pipColors.length];
      canvas.drawCircle(
        center + const Offset(0, 0.45),
        2.35,
        Paint()..color = pipColor.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        center,
        2.35,
        Paint()..color = pipColor,
      );
      canvas.drawCircle(
        center + const Offset(0, -0.35),
        0.9,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricDicePainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.face != face;
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
  final Color accent;
  final ValueChanged<String> onTagSelected;
  final List<Animation<double>>? entryAnimations;

  const DictionaryQuickSearchChips({
    super.key,
    required this.tags,
    required this.generation,
    required this.accent,
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
          accent: widget.accent,
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
        accent: widget.accent,
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
  final Color accent;
  final VoidCallback onTap;

  const _GlassQuickChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accent.withValues(alpha: 0.06),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 0.8,
            ),
          ),
          child: Text(
            '#$label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: DashboardPalette.textMuted.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}
