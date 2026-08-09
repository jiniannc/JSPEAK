import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/crew_check_in_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import 'check_in_stamp_overlay.dart';
import 'crew_flight_log_dialog.dart';

/// 홈 상단 — 인터랙티브 크루 비행 체크인 배너.
class CrewCheckInBanner extends ConsumerStatefulWidget {
  const CrewCheckInBanner({super.key});

  @override
  ConsumerState<CrewCheckInBanner> createState() => _CrewCheckInBannerState();
}

class _CrewCheckInBannerState extends ConsumerState<CrewCheckInBanner>
    with SingleTickerProviderStateMixin {
  bool _checkingIn = false;
  late final AnimationController _shimmerController;
  late final math.Random _shimmerRandom;
  Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    _shimmerRandom = math.Random(4242);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scheduleShimmer(initial: true);
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
    super.dispose();
  }

  Future<void> _openCalendar(CrewCheckInData data) {
    return CrewFlightLogDialog.show(
      context,
      month: data.anchor,
      completionDates: data.completionDates,
      consecutiveStreak: data.consecutiveStreak,
      monthlyCheckIns: data.monthlyCheckIns,
    );
  }

  Future<void> _performCheckIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);

    try {
      final didCheckIn =
          await ref.read(crewCheckInProvider.notifier).checkIn();
      if (!mounted || !didCheckIn) return;
      await showCheckInStampOverlay(context, DateTime.now());
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _onBannerTap(CrewCheckInData data) async {
    if (data.isCheckedInToday) {
      await _openCalendar(data);
    } else {
      await _performCheckIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkInAsync = ref.watch(crewCheckInProvider);

    return checkInAsync.when(
      loading: () => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => GlassSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '체크인 정보를 불러오지 못했습니다: $e',
            style: const TextStyle(color: GlassSurfaceStyle.subtitleColor),
          ),
        ),
      ),
      data: (data) {
        final checkedIn = data.isCheckedInToday;
        final streakLabel = data.consecutiveStreak > 0
            ? data.consecutiveStreak
            : 1;

        return Material(
          color: Colors.transparent,
          child: GlassSurface(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  DecoratedBox(
                    decoration: checkedIn
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6366F1)
                                    .withValues(alpha: 0.06),
                                const Color(0xFF1E293B).withValues(alpha: 0.04),
                              ],
                            ),
                          )
                        : const BoxDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _checkingIn
                                  ? null
                                  : () => _onBannerTap(data),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: checkedIn
                                          ? const Color(0xFF6366F1)
                                              .withValues(alpha: 0.12)
                                          : GlassSurfaceStyle.badgeBackground,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      checkedIn
                                          ? Icons.verified_rounded
                                          : Icons.calendar_month_rounded,
                                      size: 21,
                                      color: checkedIn
                                          ? const Color(0xFF4338CA)
                                          : GlassSurfaceStyle.iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (checkedIn)
                                          Text.rich(
                                            TextSpan(
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: GlassSurfaceStyle
                                                    .titleColor,
                                                height: 1.25,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text: '✨ 오늘 체크인 완료! ',
                                                ),
                                                TextSpan(
                                                  text:
                                                      '(연속 $streakLabel일째)',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: GlassSurfaceStyle
                                                        .subtitleColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          const Text(
                                            '환영합니다! 출석 체크하고 오늘 학습을 시작해볼까요?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  GlassSurfaceStyle.titleColor,
                                              height: 1.25,
                                            ),
                                          ),
                                        const SizedBox(height: 3),
                                        Text(
                                          checkedIn
                                              ? '오늘의 출석 스탬프가 여권에 기록되었습니다.'
                                              : '오늘의 훈련을 시작하고 출석 도장을 찍어보세요.',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                GlassSurfaceStyle.subtitleColor,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_checkingIn)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (checkedIn)
                            _SlateChipButton(
                              label: '달력 보기 📅',
                              onTap: () => _openCalendar(data),
                            )
                          else
                            GlassDeepDarkCtaButton(
                              label: '체크인 ▶',
                              radius: 20,
                              fontSize: 11,
                              horizontalPadding: 12,
                              verticalPadding: 8,
                              onPressed: _performCheckIn,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _CheckInBannerShimmer(
                        animation: _shimmerController,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 학습 모드 카드와 동일 — 45° 백색 빛줄기가 좌→우로 흐름.
class _CheckInBannerShimmer extends StatelessWidget {
  final Animation<double> animation;

  const _CheckInBannerShimmer({required this.animation});

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

class _SlateChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SlateChipButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: GlassSurfaceStyle.badgeBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: GlassSurfaceStyle.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
