import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/crew_check_in_provider.dart';
import '../dashboard_palette.dart';
import '../../../shared/widgets/compact_language_switcher.dart';
import 'check_in_stamp_overlay.dart';
import 'crew_flight_log_dialog.dart';

/// 홈 상단 — 인터랙티브 크루 비행 체크인 배너.
class CrewCheckInBanner extends ConsumerStatefulWidget {
  const CrewCheckInBanner({super.key});

  @override
  ConsumerState<CrewCheckInBanner> createState() => _CrewCheckInBannerState();
}

class _CrewCheckInBannerState extends ConsumerState<CrewCheckInBanner> {
  bool _checkingIn = false;

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
      loading: () => SizedBox(
        height: CompactLanguageDropdown.pillHeight,
        child: DecoratedBox(
          decoration: CompactLanguageDropdown.pillDecoration(),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => DecoratedBox(
        decoration: CompactLanguageDropdown.pillDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            '체크인 정보를 불러오지 못했습니다: $e',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DashboardPalette.textMuted,
              height: 1,
            ),
          ),
        ),
      ),
      data: (data) {
        final checkedIn = data.isCheckedInToday;
        final streakLabel = data.consecutiveStreak > 0
            ? data.consecutiveStreak
            : 1;

        return DecoratedBox(
          decoration: CompactLanguageDropdown.pillDecoration(
            isOpen: checkedIn,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _checkingIn ? null : () => _onBannerTap(data),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checkedIn ? '✓' : '👋',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: checkedIn
                                ? DashboardPalette.navy
                                : DashboardPalette.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                checkedIn
                                    ? '오늘 체크인 완료 · ${streakLabel}일 연속'
                                    : '환영합니다! 출석 체크하고 오늘 학습을 시작해볼까요?',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: DashboardPalette.navy,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                checkedIn
                                    ? '출석 스탬프가 여권에 기록되었습니다.'
                                    : '오늘의 훈련을 시작하고 출석 도장을 찍어보세요.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: DashboardPalette.textMuted
                                      .withValues(alpha: 0.92),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (_checkingIn)
                  const SizedBox(
                    width: CompactLanguageDropdown.pillHeight,
                    height: CompactLanguageDropdown.pillHeight,
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  _CheckInPillIconAction(
                    icon: checkedIn
                        ? Icons.event_note_outlined
                        : Icons.approval_outlined,
                    tooltip: checkedIn ? '출석 기록 보기' : '출석 체크인',
                    onTap: checkedIn
                        ? () => _openCalendar(data)
                        : _performCheckIn,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 언어 pill과 동일 표면 — 중첩 pill 아이콘 CTA.
class _CheckInPillIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CheckInPillIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: CompactLanguageDropdown.pillDecoration(isOpen: true),
            child: SizedBox(
              width: CompactLanguageDropdown.pillHeight,
              height: CompactLanguageDropdown.pillHeight,
              child: Icon(
                icon,
                size: 17,
                color: DashboardPalette.navy.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
