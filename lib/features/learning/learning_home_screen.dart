import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dashboard_providers.dart';
import '../../app/learning_hub_language_provider.dart';
import '../../app/scenario_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/language_palette.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../shared/widgets/cascade_entrance.dart';

/// 학습 탭 메인 — 간결한 진도 요약 + 기본 문장 / 시나리오 / 스와이프 모드 진입.
class LearningHomeScreen extends ConsumerWidget {
  const LearningHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = Active5Layout.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final language = ref.watch(learningHubLanguageProvider);

    return dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('학습 화면 로드 실패: $e')),
          data: (data) {
            final completed = data.scenarioLanguageProgress
                .fold<int>(0, (sum, e) => sum + e.completed);
            final total = data.scenarioLanguageProgress
                .fold<int>(0, (sum, e) => sum + e.total);

            final palette =
                LanguagePalette.forLanguage(language);

            return ListView(
                padding: EdgeInsets.fromLTRB(
                  metrics.pagePadding.left,
                  0,
                  metrics.pagePadding.right,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  CascadeEntrance(
                    child: _CompactProgressStrip(
                      overallPercent: data.scenarioOverallProgress,
                      completed: completed,
                      total: total,
                      languages: data.scenarioLanguageProgress,
                      selectedLanguage: language,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const CascadeEntrance(
                    delay: Duration(milliseconds: 60),
                    child: Text(
                      '학습 모드',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DashboardPalette.navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CascadeEntrance(
                    delay: const Duration(milliseconds: 120),
                    child: _ModeEntryCard(
                      shimmerIndex: 0,
                      accent: palette.primary,
                      icon: Icons.view_carousel_rounded,
                      eyebrow: 'BASIC SENTENCE',
                      title: '기본 문장 학습',
                      description:
                          '주제별 표준 문장을 듣고 녹음하며 단계별 Reward를 획득해 보세요.',
                      onTap: () => context.go('/scenarios/sentences'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CascadeEntrance(
                    delay: const Duration(milliseconds: 200),
                    child: _ModeEntryCard(
                      shimmerIndex: 1,
                      accent: DashboardPalette.teal,
                      icon: Icons.forum_rounded,
                      eyebrow: 'SCENARIO',
                      title: '시나리오 모드',
                      description: '기내 상황을 대화로 연습하고 언어별 완료 게이지를 올려 보세요.',
                      onTap: () => context.go('/scenarios/list'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CascadeEntrance(
                    delay: const Duration(milliseconds: 280),
                    child: _ModeEntryCard(
                      shimmerIndex: 2,
                      accent: const Color(0xFFE67E22),
                      icon: Icons.style_rounded,
                      eyebrow: 'WORD SWIPE',
                      title: '단어 스와이프 모드',
                      description: '주제별 단어를 스와이프하고 모르는 단어만 골라 복습하세요.',
                      onTap: () => context.go('/scenarios/swipe'),
                    ),
                  ),
                ],
              );
          },
        );
  }
}

/// 한 장에 전체 % + 언어별 미니 바를 담은 간결 진도 스트립.
class _CompactProgressStrip extends StatelessWidget {
  final double overallPercent;
  final int completed;
  final int total;
  final List<LanguageProgressSummary> languages;
  final String selectedLanguage;

  const _CompactProgressStrip({
    required this.overallPercent,
    required this.completed,
    required this.total,
    required this.languages,
    required this.selectedLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final percent = overallPercent.round().clamp(0, 100);
    final ratio = (overallPercent / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DashboardPalette.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: DashboardPalette.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _ProgressRing(percent: percent, ratio: ratio),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '나의 학습 진도',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: DashboardPalette.navy,
                        ),
                      ),
                    ),
                    Text(
                      total > 0 ? '$completed/$total' : '—',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DashboardPalette.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  '시나리오 훈련',
                  style: TextStyle(
                    fontSize: 11,
                    color: DashboardPalette.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (languages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < languages.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _MiniLangBar(
                            item: languages[i],
                            highlighted:
                                languages[i].language == selectedLanguage,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int percent;
  final double ratio;

  const _ProgressRing({required this.percent, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(
        painter: _RingPainter(ratio: ratio),
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$percent',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DashboardPalette.navy,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: '%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: DashboardPalette.navy.withValues(alpha: 0.55),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;

  _RingPainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3.5;
    final track = Paint()
      ..color = DashboardPalette.borderLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        colors: const [
          DashboardPalette.lime,
          DashboardPalette.teal,
          DashboardPalette.tealDeep,
        ],
        stops: const [0.0, 0.55, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (ratio <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

class _MiniLangBar extends StatelessWidget {
  final LanguageProgressSummary item;
  final bool highlighted;

  const _MiniLangBar({
    required this.item,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = languageLabel(item.language);
    final short = switch (item.language) {
      'English' => 'EN',
      'Japanese' => 'JP',
      'Chinese' => 'CN',
      _ => label.length >= 2 ? label.substring(0, 2) : label,
    };
    final value = item.total == 0 ? 0.0 : (item.percent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              short,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: highlighted
                    ? DashboardPalette.teal
                    : DashboardPalette.navy,
              ),
            ),
            const Spacer(),
            Text(
              '${item.percent.round()}%',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 5,
            backgroundColor: DashboardPalette.borderLight,
            color: highlighted
                ? DashboardPalette.teal
                : DashboardPalette.teal.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _ModeEntryCard extends StatefulWidget {
  final int shimmerIndex;
  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ModeEntryCard({
    required this.shimmerIndex,
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_ModeEntryCard> createState() => _ModeEntryCardState();
}

class _ModeEntryCardState extends State<_ModeEntryCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _iconLifeController;
  late final Animation<double> _iconPulse;
  late final Animation<double> _iconWobble;
  late final Animation<double> _iconBob;
  late final math.Random _shimmerRandom;
  Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    _shimmerRandom = math.Random(7919 + widget.shimmerIndex * 9973);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _iconLifeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2100 + widget.shimmerIndex * 180),
    );
    _iconPulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_iconLifeController);
    _iconWobble = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.048)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.048, end: -0.042)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.042, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_iconLifeController);
    _iconBob = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -2.2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -2.2, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_iconLifeController);
    _scheduleShimmer(initial: true);
    Future.delayed(Duration(milliseconds: 420 + widget.shimmerIndex * 240), () {
      if (mounted) _iconLifeController.repeat();
    });
  }

  void _scheduleShimmer({required bool initial}) {
    _shimmerTimer?.cancel();
    final delayMs = initial
        ? 1000 + _shimmerRandom.nextInt(1500)
        : 2500 + _shimmerRandom.nextInt(3500);
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
    _iconLifeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: DashboardPalette.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accent.withValues(alpha: 0.1),
                  DashboardPalette.cardWhite,
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 14, 18),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _iconLifeController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _iconBob.value),
                            child: Transform.scale(
                              scale: _iconPulse.value,
                              child: Transform.rotate(
                                angle: _iconWobble.value,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accent,
                            size: 27,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.eyebrow,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: widget.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: DashboardPalette.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.description,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: DashboardPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: widget.accent.withValues(alpha: 0.7),
                        size: 28,
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _LearningModeCardShimmer(
                      animation: _shimmerController,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D 휠 스냅 타겟 카드와 동일 — 45° 백색 빛줄기가 좌→우로 스르륵 흐름.
class _LearningModeCardShimmer extends StatelessWidget {
  final Animation<double> animation;

  const _LearningModeCardShimmer({required this.animation});

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
                widthFactor: 0.26,
                heightFactor: 2.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.55),
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
