import 'package:flutter/foundation.dart';

/// 여권 칭호 뱃지 카탈로그 1건 — 정적 메타데이터(이미지·타이틀·획득 조건 설명).
@immutable
class TitleBadgeCatalogEntry {
  final String id;
  final String title;
  final String description;
  final String imagePath;

  /// PNG 가로 ÷ 세로 — height 기준 레이아웃 시 width = height × aspectRatio.
  final double aspectRatio;

  const TitleBadgeCatalogEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    this.aspectRatio = 1,
  });
}

/// 9가지 칭호 뱃지 정의 (여권 PAGE 1 · 칭호 스탬프북에 표시되는 순서).
const List<TitleBadgeCatalogEntry> kTitleBadgeCatalog = [
  TitleBadgeCatalogEntry(
    id: 'start',
    title: '시작이 반이다',
    description: '단어·문장·시나리오 중 어떤 학습 모드든 하나만 시작해도 획득할 수 있어요.',
    imagePath: 'assets/images/badge_start.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'omotenashi',
    title: '오모테나시 마스터',
    description: '일본어 문장 스피킹 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_omotenashi.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'toneDestroyer',
    title: '성조파괴자',
    description: '중국어 문장 스피킹 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_tonedestroyer.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'perfectVoice',
    title: '퍼펙트 보이스',
    description: '영어 문장 스피킹 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_perfectvoice.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'guardian',
    title: '돌발상황 가디언',
    description: '영어 시나리오 롤플레잉 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_guardian.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'japaneseMaster',
    title: '전천후 일어 해결사',
    description: '일본어 시나리오 롤플레잉 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_japanesemaster.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'chineseMaster',
    title: '중국어 기내 회화통',
    description: '중국어 시나리오 롤플레잉 모드를 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_chinesemaster.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'walkingDictionary',
    title: '걸어다니는 사전',
    description: '영어·일본어·중국어 단어 스와이프를 모두 마스터하면 획득할 수 있어요.',
    imagePath: 'assets/images/badge_walkingdictionary.png',
  ),
  TitleBadgeCatalogEntry(
    id: 'firstClass',
    title: '퍼스트 클래스 멀티 크루',
    description: '위 8개 칭호를 모두 획득하면 해제되는 최고 등급 칭호예요.',
    imagePath: 'assets/images/badge_firstclass.png',
    aspectRatio: 1560 / 1024,
  ),
];

/// 칭호 뱃지 런타임 상태 — 카탈로그 메타데이터 + 획득 여부/일자/진도율.
@immutable
class TitleBadge {
  final String id;
  final String title;
  final String description;
  final String imagePath;
  final double aspectRatio;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  /// 0 ~ 100 — 미획득 상태의 달성 진도율 (획득 시 100).
  final double progressPercent;

  const TitleBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    this.aspectRatio = 1,
    required this.isUnlocked,
    this.unlockedAt,
    this.progressPercent = 0,
  });

  /// 스탬프 height 기준 렌더 폭.
  double stampWidthForHeight(double height) => height * aspectRatio;

  TitleBadge copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progressPercent,
  }) {
    return TitleBadge(
      id: id,
      title: title,
      description: description,
      imagePath: imagePath,
      aspectRatio: aspectRatio,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progressPercent: progressPercent ?? this.progressPercent,
    );
  }
}
