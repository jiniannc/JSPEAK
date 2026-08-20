import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/title_badge_local_datasource.dart';
import '../data/models/title_badge.dart';
import '../data/repositories/title_badge_repository.dart';
import 'my_page_report_providers.dart';

final titleBadgeLocalDataSourceProvider = Provider<TitleBadgeLocalDataSource>(
  (ref) => TitleBadgeLocalDataSource(),
);

final titleBadgeRepositoryProvider = Provider<TitleBadgeRepository>((ref) {
  return TitleBadgeRepository(ref.watch(titleBadgeLocalDataSourceProvider));
});

/// 뱃지 1건의 해제 여부 + 진도율(0~100) 신호.
class TitleBadgeSignal {
  final bool unlocked;
  final double progressPercent;

  const TitleBadgeSignal({
    required this.unlocked,
    required this.progressPercent,
  });
}

double _pct(int done, int total) {
  if (total <= 0) return 0;
  return (done / total * 100).clamp(0, 100);
}

Map<String, TitleBadgeSignal> _computeSignals(MyPageProgressSignals? s) {
  if (s == null) return const {};

  final englishMastered = s.english.stampSummary.masteredCount;
  final englishTotal = s.english.stampSummary.total;
  final japaneseMastered = s.japanese.stampSummary.masteredCount;
  final japaneseTotal = s.japanese.stampSummary.total;
  final chineseMastered = s.chinese.stampSummary.masteredCount;
  final chineseTotal = s.chinese.stampSummary.total;

  final englishBasicDone = englishTotal > 0 && englishMastered >= englishTotal;
  final japaneseBasicDone =
      japaneseTotal > 0 && japaneseMastered >= japaneseTotal;
  final chineseBasicDone = chineseTotal > 0 && chineseMastered >= chineseTotal;

  final englishScenarioDone =
      s.english.scenarioTotal > 0 && s.english.scenarioPercent >= 99.9;
  final japaneseScenarioDone =
      s.japanese.scenarioTotal > 0 && s.japanese.scenarioPercent >= 99.9;
  final chineseScenarioDone =
      s.chinese.scenarioTotal > 0 && s.chinese.scenarioPercent >= 99.9;

  final globalSwipeDone =
      s.globalSwipeTotal > 0 && s.globalSwipeKnown >= s.globalSwipeTotal;
  final globalSwipePercent = _pct(s.globalSwipeKnown, s.globalSwipeTotal);

  final coreUnlocked = <bool>[
    s.anyChapterCleared,
    japaneseBasicDone,
    chineseBasicDone,
    englishBasicDone,
    englishScenarioDone,
    japaneseScenarioDone,
    chineseScenarioDone,
    globalSwipeDone,
  ];
  final coreDoneCount = coreUnlocked.where((v) => v).length;
  final firstClassUnlocked = coreUnlocked.every((v) => v);

  return {
    'start': TitleBadgeSignal(
      unlocked: s.anyChapterCleared,
      progressPercent: s.anyChapterCleared ? 100 : 0,
    ),
    'omotenashi': TitleBadgeSignal(
      unlocked: japaneseBasicDone,
      progressPercent: _pct(japaneseMastered, japaneseTotal),
    ),
    'toneDestroyer': TitleBadgeSignal(
      unlocked: chineseBasicDone,
      progressPercent: _pct(chineseMastered, chineseTotal),
    ),
    'perfectVoice': TitleBadgeSignal(
      unlocked: englishBasicDone,
      progressPercent: _pct(englishMastered, englishTotal),
    ),
    'guardian': TitleBadgeSignal(
      unlocked: englishScenarioDone,
      progressPercent: s.english.scenarioPercent.clamp(0, 100),
    ),
    'japaneseMaster': TitleBadgeSignal(
      unlocked: japaneseScenarioDone,
      progressPercent: s.japanese.scenarioPercent.clamp(0, 100),
    ),
    'chineseMaster': TitleBadgeSignal(
      unlocked: chineseScenarioDone,
      progressPercent: s.chinese.scenarioPercent.clamp(0, 100),
    ),
    'walkingDictionary': TitleBadgeSignal(
      unlocked: globalSwipeDone,
      progressPercent: globalSwipePercent,
    ),
    'firstClass': TitleBadgeSignal(
      unlocked: firstClassUnlocked,
      progressPercent: coreDoneCount / 8 * 100,
    ),
  };
}

/// 카탈로그 각 뱃지의 현재 해제 여부·진도율 (언어 선택과 무관 · 3개 언어 통합 계산).
final titleBadgeSignalsProvider = Provider<Map<String, TitleBadgeSignal>>((
  ref,
) {
  final signals = ref.watch(myPageProgressSignalsProvider);
  return _computeSignals(signals);
});

/// QA용 — CREW LEARNING PASSPORT 헤더 스위치로 전체 칭호 UI 해제 상태를 미리보기.
class TitleBadgeDebugUnlockAllController extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;
}

final titleBadgeDebugUnlockAllProvider =
    NotifierProvider<TitleBadgeDebugUnlockAllController, bool>(
  TitleBadgeDebugUnlockAllController.new,
);

class TitleBadgeUnlockState {
  final Map<String, DateTime> unlockedAt;
  final List<String> pendingCelebrations;
  final List<String> pendingBanners;

  const TitleBadgeUnlockState({
    this.unlockedAt = const {},
    this.pendingCelebrations = const [],
    this.pendingBanners = const [],
  });

  TitleBadgeUnlockState copyWith({
    Map<String, DateTime>? unlockedAt,
    List<String>? pendingCelebrations,
    List<String>? pendingBanners,
  }) {
    return TitleBadgeUnlockState(
      unlockedAt: unlockedAt ?? this.unlockedAt,
      pendingCelebrations: pendingCelebrations ?? this.pendingCelebrations,
      pendingBanners: pendingBanners ?? this.pendingBanners,
    );
  }
}

/// 칭호 뱃지 해제 시점을 영구 저장하고, 신규 해제 뱃지를 축하 애니메이션 큐로 전달.
class TitleBadgeUnlockController extends Notifier<TitleBadgeUnlockState> {
  bool _bootstrapped = false;
  Map<String, DateTime> _baseline = {};
  List<String> _pendingCelebrations = [];
  List<String> _pendingBanners = [];

  @override
  TitleBadgeUnlockState build() {
    if (!_bootstrapped) {
      _bootstrap();
      return const TitleBadgeUnlockState();
    }
    final signals = ref.watch(titleBadgeSignalsProvider);
    return _reconcile(signals);
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(titleBadgeRepositoryProvider);
    _baseline = await repo.loadUnlockDates();
    _pendingCelebrations = await repo.loadPendingCelebrations();
    _bootstrapped = true;
    state = _reconcile(ref.read(titleBadgeSignalsProvider));
  }

  TitleBadgeUnlockState _reconcile(Map<String, TitleBadgeSignal> signals) {
    final merged = Map<String, DateTime>.from(_baseline);
    final newlyUnlocked = <String>[];
    for (final entry in signals.entries) {
      if (entry.value.unlocked && !merged.containsKey(entry.key)) {
        merged[entry.key] = DateTime.now();
        newlyUnlocked.add(entry.key);
      }
    }
    if (newlyUnlocked.isNotEmpty) {
      _baseline = merged;
      _pendingCelebrations = [
        ..._pendingCelebrations,
        ...newlyUnlocked.where((id) => !_pendingCelebrations.contains(id)),
      ];
      _pendingBanners = [
        ..._pendingBanners,
        ...newlyUnlocked.where((id) => !_pendingBanners.contains(id)),
      ];
      final repo = ref.read(titleBadgeRepositoryProvider);
      unawaited(repo.saveUnlockDates(merged));
      unawaited(repo.savePendingCelebrations(_pendingCelebrations));
    }
    return TitleBadgeUnlockState(
      unlockedAt: merged,
      pendingCelebrations: List.unmodifiable(_pendingCelebrations),
      pendingBanners: List.unmodifiable(_pendingBanners),
    );
  }

  /// 상단 배너를 이미 보여준 뱃지를 대기열에서 제거.
  void acknowledgeBanner(String badgeId) {
    _pendingBanners = _pendingBanners.where((id) => id != badgeId).toList();
    state = state.copyWith(pendingBanners: List.unmodifiable(_pendingBanners));
  }

  /// 마이페이지 축하 다이얼로그가 담당하므로 배너는 내린다.
  void dismissBanners() {
    if (_pendingBanners.isEmpty) return;
    _pendingBanners = [];
    state = state.copyWith(pendingBanners: const []);
  }

  /// 축하 다이얼로그를 이미 보여준 뱃지를 대기열에서 제거.
  void acknowledgeCelebration(String badgeId) {
    _pendingCelebrations =
        _pendingCelebrations.where((id) => id != badgeId).toList();
    unawaited(
      ref.read(titleBadgeRepositoryProvider).savePendingCelebrations(
            _pendingCelebrations,
          ),
    );
    state = state.copyWith(
      pendingCelebrations: List.unmodifiable(_pendingCelebrations),
    );
  }
}

final titleBadgeUnlockProvider =
    NotifierProvider<TitleBadgeUnlockController, TitleBadgeUnlockState>(
  TitleBadgeUnlockController.new,
);

/// 카탈로그 메타데이터 + 해제 여부 + 진도율 + 해제일을 합친 최종 뱃지 목록.
final titleBadgesProvider = Provider<List<TitleBadge>>((ref) {
  final debugUnlockAll = ref.watch(titleBadgeDebugUnlockAllProvider);
  final signals = ref.watch(titleBadgeSignalsProvider);
  final unlockState = ref.watch(titleBadgeUnlockProvider);
  final previewUnlockedAt = DateTime.now();

  return kTitleBadgeCatalog.map((entry) {
    final signal = signals[entry.id];
    final unlocked = debugUnlockAll || (signal?.unlocked ?? false);
    return TitleBadge(
      id: entry.id,
      title: entry.title,
      description: entry.description,
      imagePath: entry.imagePath,
      aspectRatio: entry.aspectRatio,
      isUnlocked: unlocked,
      unlockedAt: unlocked
          ? (unlockState.unlockedAt[entry.id] ?? previewUnlockedAt)
          : null,
      progressPercent: unlocked ? 100 : (signal?.progressPercent ?? 0),
    );
  }).toList();
});
