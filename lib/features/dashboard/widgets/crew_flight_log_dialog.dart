import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/datasources/local/learning_local_datasource.dart';
import '../../../shared/widgets/glass_surface.dart';

/// 글래스모피즘 크루 비행 일지 달력 모달.
class CrewFlightLogDialog extends StatelessWidget {
  final DateTime month;
  final Set<String> completionDates;
  final int consecutiveStreak;
  final int monthlyCheckIns;

  const CrewFlightLogDialog({
    super.key,
    required this.month,
    required this.completionDates,
    required this.consecutiveStreak,
    required this.monthlyCheckIns,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime month,
    required Set<String> completionDates,
    required int consecutiveStreak,
    required int monthlyCheckIns,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => CrewFlightLogDialog(
        month: month,
        completionDates: completionDates,
        consecutiveStreak: consecutiveStreak,
        monthlyCheckIns: monthlyCheckIns,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${month.month}월';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: GlassSurfaceStyle.surfaceDecoration(
              radius: 20,
              opacity: 0.82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '✈️ CREW FLIGHT LOG ($monthLabel 비행 일지)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: GlassSurfaceStyle.titleColor,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: GlassSurfaceStyle.subtitleColor
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FlightLogCalendar(
                    month: month,
                    completionDates: completionDates,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: GlassSurfaceStyle.badgeBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '이번 달 비행 횟수: $monthlyCheckIns일 / 연속 출석: $consecutiveStreak일',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GlassSurfaceStyle.iconColor,
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

class _FlightLogCalendar extends StatelessWidget {
  final DateTime month;
  final Set<String> completionDates;

  const _FlightLogCalendar({
    required this.month,
    required this.completionDates,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday - DateTime.monday;
    final totalCells = startOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          children: _weekdays
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: GlassSurfaceStyle.subtitleColor,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNumber = cellIndex - startOffset + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 52));
                }

                final date = DateTime(month.year, month.month, dayNumber);
                final cleared = completionDates.contains(learningDateKey(date));
                final isToday = _isSameDay(date, DateTime.now());

                return Expanded(
                  child: _CalendarDayCell(
                    day: dayNumber,
                    cleared: cleared,
                    isToday: isToday,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool cleared;
  final bool isToday;

  const _CalendarDayCell({
    required this.day,
    required this.cleared,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cleared
                  ? const Color(0xFF1E293B).withValues(alpha: 0.12)
                  : (isToday
                      ? GlassSurfaceStyle.badgeBackground
                      : Colors.transparent),
              border: Border.all(
                color: cleared
                    ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                    : (isToday
                        ? GlassSurfaceStyle.dividerColor.withValues(alpha: 0.5)
                        : Colors.transparent),
                width: cleared || isToday ? 1 : 0,
              ),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cleared
                      ? GlassSurfaceStyle.deepSlate
                      : GlassSurfaceStyle.titleColor,
                ),
              ),
            ),
          ),
          if (cleared) ...[
            const SizedBox(height: 2),
            const Text(
              'CLEARED',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: GlassSurfaceStyle.iconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
