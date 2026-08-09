import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/learning_local_datasource.dart';
import 'dashboard_providers.dart';

/// 홈 크루 체크인 상태.
class CrewCheckInData {
  final bool isCheckedInToday;
  final int consecutiveStreak;
  final int monthlyCheckIns;
  final Set<String> completionDates;
  final DateTime anchor;

  const CrewCheckInData({
    required this.isCheckedInToday,
    required this.consecutiveStreak,
    required this.monthlyCheckIns,
    required this.completionDates,
    required this.anchor,
  });

  factory CrewCheckInData.fromStats(LearningStats stats, DateTime anchor) {
    final todayKey = learningDateKey(anchor);
    return CrewCheckInData(
      isCheckedInToday: stats.completionDates.contains(todayKey),
      consecutiveStreak: consecutiveStreakFor(anchor, stats.completionDates),
      monthlyCheckIns: monthlyCheckInsFor(anchor, stats.completionDates),
      completionDates: stats.completionDates,
      anchor: anchor,
    );
  }
}

class CrewCheckInController extends AsyncNotifier<CrewCheckInData> {
  LearningLocalDataSource get _local =>
      ref.read(learningLocalDataSourceProvider);

  @override
  Future<CrewCheckInData> build() async {
    final stats = await _local.load();
    return CrewCheckInData.fromStats(stats, DateTime.now());
  }

  Future<bool> checkIn() async {
    final repo = ref.read(learningRepositoryProvider);
    final before = state.asData?.value;
    if (before?.isCheckedInToday ?? false) return false;

    await repo.recordCheckIn();
    ref.invalidate(dashboardProvider);
    ref.invalidateSelf();
    await future;
    return true;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final crewCheckInProvider =
    AsyncNotifierProvider<CrewCheckInController, CrewCheckInData>(
  CrewCheckInController.new,
);
