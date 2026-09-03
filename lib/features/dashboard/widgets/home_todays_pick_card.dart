import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/providers.dart';
import '../../../app/speech_providers.dart';
import '../../../core/utils/karaoke_word_index.dart';
import '../../../data/models/sentence.dart';
import '../../../shared/widgets/pronunciation_practice_section.dart';
import '../../../shared/widgets/tappable_sentence_rich_text.dart';
import '../dashboard_palette.dart';
abstract final class _JinAirLogoAssets {
  /// 헤더 — JINAIR 워드마크
  static const headerWordmark = 'assets/images/jinair_logo2.svg';
  /// CTA — 라임 나비
  static const ctaButterfly = 'assets/images/jinair_logo1.svg';
}

class _JinAirLogo extends StatelessWidget {
  final String asset;
  final double height;
  final double? width;
  final Color? color;

  const _JinAirLogo({
    required this.asset,
    required this.height,
    this.width,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: SvgPicture.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        allowDrawingOutsideViewBox: true,
        clipBehavior: Clip.none,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
  }
}

/// 홈 Today's Pick — 진에어 실물 탑승권(Boarding Pass) 스타일 카드.
class HomeTodaysPickCard extends ConsumerStatefulWidget {
  /// 헤더 밴드 아래 본문(탑승권) 최소 높이 — 짧은 문장도 볼륨감 유지.
  static const bodyMinHeight = 132.0;

  final Sentence sentence;
  final String flightNumber;
  final Color accent;
  final VoidCallback? onStartLearning;
  final VoidCallback? onListen;

  const HomeTodaysPickCard({
    super.key,
    required this.sentence,
    required this.flightNumber,
    required this.accent,
    this.onStartLearning,
    this.onListen,
  });

  @override
  ConsumerState<HomeTodaysPickCard> createState() => _HomeTodaysPickCardState();

  static String gateFor(Sentence sentence) {
    final gate = 1 + (sentence.id.hashCode % 30).abs();
    return gate.toString().padLeft(2, '0');
  }

  static String routeFor(Sentence sentence) {
    const destinations = {
      'English': ['DAD', 'CNX', 'BKK', 'HKT', 'DPS'],
      'Japanese': ['NRT', 'KIX', 'FUK', 'CTS'],
      'Chinese': ['PVG', 'TAO', 'WEH', 'YNJ'],
    };
    final list = destinations[sentence.language] ?? ['DAD', 'NRT', 'PVG'];
    final dest = list[sentence.id.hashCode.abs() % list.length];
    return 'ICN ✈ $dest';
  }

  static String seatFor(Sentence sentence) {
    final row = 1 + (sentence.id.hashCode % 30).abs();
    const letters = 'ABCDEF';
    final letter = letters[(sentence.id.hashCode >> 3).abs() % letters.length];
    return 'SEAT ${row.toString().padLeft(2, '0')}$letter';
  }
}

class _HomeTodaysPickCardState extends ConsumerState<HomeTodaysPickCard> {
  bool _practiceOpen = false;

  @override
  void initState() {
    super.initState();
    _prefetchAudio();
  }

  @override
  void didUpdateWidget(covariant HomeTodaysPickCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence.id != widget.sentence.id) {
      _prefetchAudio();
    }
  }

  void _prefetchAudio() {
    if (widget.sentence.audioUrl.isEmpty) return;
    ref.read(audioProvider.notifier).prefetch(widget.sentence);
  }

  void _openPractice() {
    setState(() => _practiceOpen = true);
    ref.read(speechPracticeProvider.notifier).startPractice(widget.sentence);
  }

  bool _isPracticingThis(SpeechPracticeState speech) {
    return speech.activeSentenceId == widget.sentence.id &&
        (speech.isInitializing ||
            speech.isListening ||
            speech.isRecognizing ||
            _practiceOpen);
  }

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechPracticeProvider);
    final category = widget.sentence.category.trim().isNotEmpty
        ? widget.sentence.category.trim()
        : widget.sentence.language;
    final gate = HomeTodaysPickCard.gateFor(widget.sentence);
    final route = HomeTodaysPickCard.routeFor(widget.sentence);
    final showPractice = _isPracticingThis(speech);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _JinAirHeaderBand(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const stubFraction = 0.25;
                    const dividerWidth = 22.0;
                    const dividerShift = 20.0;
                    final stubWidth = math.max(
                      0.0,
                      constraints.maxWidth * stubFraction - dividerShift,
                    );
                    final bodyWidth = math.max(
                      0.0,
                      constraints.maxWidth - stubWidth - dividerWidth,
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: HomeTodaysPickCard.bodyMinHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: bodyWidth,
                                    child: _BoardingPassMainBody(
                                      sentence: widget.sentence,
                                      category: category,
                                      onListen: widget.onListen,
                                      onPractice: _openPractice,
                                    ),
                                  ),
                                  SizedBox(width: dividerWidth),
                                  SizedBox(
                                    width: stubWidth,
                                    child: _BoardingPassStubSection(
                                      flightNumber: widget.flightNumber,
                                      gate: gate,
                                      route: route,
                                      onStartLearning: widget.onStartLearning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: bodyWidth,
                          top: 0,
                          bottom: 0,
                          width: dividerWidth,
                          child: const _PerforationDivider(),
                        ),
                      ],
                    );
                  },
                ),
                if (showPractice) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: DashboardPalette.borderLight.withValues(alpha: 0.7),
                    ),
                  ),
                  PronunciationPracticeSection(
                    sentence: widget.sentence,
                    accent: widget.accent,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's Pick 플립 리빌용 탑승권 뒷면 — 밝은 펄 광택.
class TodaysPickTicketBack extends StatefulWidget {
  const TodaysPickTicketBack({super.key});

  @override
  State<TodaysPickTicketBack> createState() => _TodaysPickTicketBackState();
}

class _TodaysPickTicketBackState extends State<TodaysPickTicketBack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFBFCEE),
              DashboardPalette.jinLimeAlt.withValues(alpha: 0.55),
              const Color(0xFFF7EEF3),
              const Color(0xFFEEF6B8),
            ],
            stops: const [0.0, 0.38, 0.68, 1.0],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x73FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x28FFFFFF),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _TicketBackShineOverlay(animation: _shine),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _JinAirLogo(
                    asset: _JinAirLogoAssets.headerWordmark,
                    height: 22,
                    color: DashboardPalette.jinPurple,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BOARDING PASS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      height: 1,
                      color: DashboardPalette.jinPurple.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketBackShineOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _TicketBackShineOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment(-1.7 + 3.4 * t, -0.2),
              child: Transform.rotate(
                angle: -math.pi / 5.5,
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  heightFactor: 2.8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.92),
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment(-2.1 + 3.6 * ((t + 0.45) % 1.0), 0.35),
              child: Transform.rotate(
                angle: -math.pi / 5.5,
                child: FractionallySizedBox(
                  widthFactor: 0.18,
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
                      ),
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

class _JinAirHeaderBand extends StatefulWidget {
  const _JinAirHeaderBand();

  @override
  State<_JinAirHeaderBand> createState() => _JinAirHeaderBandState();
}

class _JinAirHeaderBandState extends State<_JinAirHeaderBand>
    with SingleTickerProviderStateMixin {
  static const _logoHeight = 20.0;

  late final AnimationController _shimmerController;
  late final math.Random _shimmerRandom;
  Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    _shimmerRandom = math.Random(6151);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scheduleShimmer(initial: true);
  }

  void _scheduleShimmer({required bool initial}) {
    _shimmerTimer?.cancel();
    final delayMs = initial
        ? 900 + _shimmerRandom.nextInt(1400)
        : 2200 + _shimmerRandom.nextInt(3800);
    _shimmerTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      await _shimmerController.forward(from: 0);
      if (mounted) _scheduleShimmer(initial: false);
    });
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DashboardPalette.jinLime,
            DashboardPalette.jinLimeAlt,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              _JinAirLogo(
                asset: _JinAirLogoAssets.headerWordmark,
                height: _logoHeight,
              ),
              const Spacer(),
              const Text(
                'TODAY\'S PICK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: DashboardPalette.jinPurple,
                  letterSpacing: 1.1,
                  height: 1,
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _HeaderShimmerOverlay(animation: _shimmerController),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderShimmerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _HeaderShimmerOverlay({required this.animation});

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
                widthFactor: 0.32,
                heightFactor: 2.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.22),
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

class _FlyingButterflyLogo extends StatefulWidget {
  final double height;

  const _FlyingButterflyLogo({required this.height});

  @override
  State<_FlyingButterflyLogo> createState() => _FlyingButterflyLogoState();
}

/// 페이퍼 마리오식 부유 비행 — 상하 보빙 + 기울기 + 날개 펄럭임.
class _FlyingButterflyLogoState extends State<_FlyingButterflyLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * 2 * math.pi;
        final bob = math.sin(phase);
        final wingBeat = math.sin(phase * 2.4);
        final verticalOffset = bob * 0.8;
        final tilt = bob * 0.03;
        final scaleX = 1.0 + wingBeat * 0.07;
        final scaleY = 1.0 - wingBeat * 0.05;

        return Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Transform.rotate(
            angle: tilt,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
              child: child,
            ),
          ),
        );
      },
      child: _JinAirLogo(
        asset: _JinAirLogoAssets.ctaButterfly,
        height: widget.height,
        width: widget.height,
      ),
    );
  }
}

class _StartLearningLink extends StatelessWidget {
  final VoidCallback? onPressed;

  const _StartLearningLink({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 24,
              child: OverflowBox(
                alignment: Alignment.center,
                maxWidth: 22,
                maxHeight: 28,
                child: _FlyingButterflyLogo(height: 20),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              '학습 시작하기 ▶',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardingPassMainBody extends ConsumerWidget {
  final Sentence sentence;
  final String category;
  final VoidCallback? onListen;
  final VoidCallback? onPractice;

  const _BoardingPassMainBody({
    required this.sentence,
    required this.category,
    this.onListen,
    this.onPractice,
  });

  static const _slate = Color(0xFF0F172A);
  static const _pronunciationColor = Color(0xFF64748B);
  static const _koreanColor = Color(0xFF475569);

  bool _showPronunciation(Sentence sentence) {
    final isCjk = sentence.language == 'Japanese' || sentence.language == 'Chinese';
    return isCjk && sentence.pronunciation.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final isThisAudio = audio.playingSentenceId == sentence.id;
    final showPronunciation = _showPronunciation(sentence);
    final englishStyle = const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: _slate,
      height: 1.38,
      letterSpacing: -0.35,
    );
    final karaokeWordIndex = KaraokeWordIndex.resolve(
      isActive: isThisAudio && audio.isPlaying,
      position: audio.position,
      duration: audio.duration,
      sentence: sentence.sentence,
      language: sentence.language,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: _VerticalBarcodeStrip(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _CategoryBadge(label: category),
                    ),
                    if (onListen != null || onPractice != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onListen != null)
                            _MediaActionIcon(
                              icon: Icons.volume_up_rounded,
                              onTap: onListen!,
                            ),
                          if (onListen != null && onPractice != null)
                            const SizedBox(width: 2),
                          if (onPractice != null)
                            _MediaActionIcon(
                              icon: Icons.mic_none_rounded,
                              onTap: onPractice!,
                            ),
                        ],
                      ),
                  ],
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TappableSentenceRichText(
                          sentence: sentence.sentence,
                          language: sentence.language,
                          karaokeWordIndex: karaokeWordIndex,
                          style: englishStyle,
                        ),
                        if (showPronunciation) ...[
                          const SizedBox(height: 6),
                          Text(
                            sentence.pronunciation.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: _pronunciationColor,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        if (sentence.korean.trim().isNotEmpty) ...[
                          SizedBox(height: showPronunciation ? 6 : 10),
                          Text(
                            sentence.korean,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _koreanColor,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MediaActionIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 16,
            color: DashboardPalette.jinBoardingNavy,
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  static const _fill = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _BoardingPassStubSection extends StatelessWidget {
  final String flightNumber;
  final String gate;
  final String route;
  final VoidCallback? onStartLearning;

  const _BoardingPassStubSection({
    required this.flightNumber,
    required this.gate,
    required this.route,
    this.onStartLearning,
  });

  static const _metaColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 8, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$flightNumber · GATE: $gate · $route',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: _metaColor.withValues(alpha: 0.85),
              letterSpacing: 0.05,
              height: 1.35,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _StartLearningLink(onPressed: onStartLearning),
          ),
        ],
      ),
    );
  }
}

class _PerforationDivider extends StatelessWidget {
  const _PerforationDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerticalDashedLinePainter(
        color: const Color(0xFFCBD5E1),
        strokeWidth: 1.0,
        dashLength: 3.0,
        dashGap: 3.0,
      ),
    );
  }
}

class _VerticalBarcodeStrip extends StatelessWidget {
  const _VerticalBarcodeStrip();

  static const stripWidth = 38.0;
  static const qrSize = 34.0;
  static const _ink = Color(0xFF334155);
  static const _stripeColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: stripWidth,
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(1),
              ),
              child: CustomPaint(
                painter: _HorizontalStripeBarcodePainter(
                  color: _stripeColor.withValues(alpha: 0.35),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 5),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(
                color: _ink.withValues(alpha: 0.22),
                width: 0.8,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: SizedBox(
                width: qrSize,
                height: qrSize,
                child: CustomPaint(
                  painter: _BoardingPassQrPainter(
                    color: _ink.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  _VerticalDashedLinePainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 3.0,
    this.dashGap = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    var y = 2.0;
    final x = size.width / 2;

    while (y < size.height - 2) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashLength), paint);
      y += dashLength + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.dashGap != dashGap;
}

/// 탑승권 측면 — 가로 1D 바코드(전폭 균일, 두께·간격 랜덤).
class _HorizontalStripeBarcodePainter extends CustomPainter {
  final Color color;

  _HorizontalStripeBarcodePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const horizontalInset = 1.0;
    final barWidth = size.width - horizontalInset * 2;
    final random = math.Random(17);
    var y = 1.0;

    while (y < size.height - 1) {
      final barThickness = 0.55 + random.nextDouble() * 1.6;
      canvas.drawRect(
        Rect.fromLTWH(horizontalInset, y, barWidth, barThickness),
        paint,
      );
      y += barThickness + (0.35 + random.nextDouble() * 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalStripeBarcodePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BoardingPassQrPainter extends CustomPainter {
  final Color color;

  _BoardingPassQrPainter({required this.color});

  static const _modules = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final module = size.width / _modules;
    final paint = Paint()..color = color;
    final random = math.Random(9917);

    void drawFinder(int originX, int originY) {
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final isOuter = x == 0 || x == 6 || y == 0 || y == 6;
          final isInner = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          if (!isOuter && !isInner) continue;
          canvas.drawRect(
            Rect.fromLTWH(
              (originX + x) * module,
              (originY + y) * module,
              module,
              module,
            ),
            paint,
          );
        }
      }
    }

    bool inFinderZone(int x, int y) {
      return (x < 8 && y < 8) || (x > 12 && y < 8) || (x < 8 && y > 12);
    }

    drawFinder(0, 0);
    drawFinder(14, 0);
    drawFinder(0, 14);

    for (var y = 0; y < _modules; y++) {
      for (var x = 0; x < _modules; x++) {
        if (inFinderZone(x, y)) continue;

        if (x == 6 || y == 6) {
          if ((x + y).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(x * module, y * module, module, module),
              paint,
            );
          }
          continue;
        }

        if (random.nextDouble() > 0.46) {
          final inset = module * 0.06;
          canvas.drawRect(
            Rect.fromLTWH(
              x * module + inset,
              y * module + inset,
              module - inset * 2,
              module - inset * 2,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardingPassQrPainter oldDelegate) =>
      oldDelegate.color != color;
}
