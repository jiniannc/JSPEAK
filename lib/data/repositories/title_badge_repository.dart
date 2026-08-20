import '../datasources/local/title_badge_local_datasource.dart';

/// 칭호 뱃지 획득 일자 영속화 담당.
class TitleBadgeRepository {
  TitleBadgeRepository(this._local);

  final TitleBadgeLocalDataSource _local;

  Future<Map<String, DateTime>> loadUnlockDates() => _local.loadUnlockDates();

  Future<void> saveUnlockDates(Map<String, DateTime> dates) =>
      _local.saveUnlockDates(dates);

  Future<List<String>> loadPendingCelebrations() =>
      _local.loadPendingCelebrations();

  Future<void> savePendingCelebrations(List<String> ids) =>
      _local.savePendingCelebrations(ids);
}
