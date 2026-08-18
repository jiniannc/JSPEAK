import 'package:flutter/material.dart';

/// 언어 코드(시트의 값) → 한국어 표시명.
const Map<String, String> languageLabels = {
  'English': '영어',
  'Japanese': '일본어',
  'Chinese': '중국어',
};

String languageLabel(String language) => languageLabels[language] ?? language;

/// 학습 허브 챕터 카드 — 언어별 챕터 번호 라벨.
String hubChapterLabel(String language, int chapterNo) {
  return switch (language) {
    'Japanese' => 'チャプター$chapterNo',
    'Chinese' => '第$chapterNo章',
    _ => 'Chapter $chapterNo',
  };
}

/// 언어별 대표 아이콘(간단한 국기 이모지). 나중에 assets/icons 이미지로 교체 가능.
const Map<String, String> languageEmoji = {
  'English': '🇺🇸',
  'Japanese': '🇯🇵',
  'Chinese': '🇨🇳',
};

/// 카테고리명 → Material 아이콘 매핑. 시트에 새 카테고리가 생기면 여기에 추가.
const Map<String, IconData> categoryIcons = {
  '탑승 안내': Icons.airplane_ticket_outlined,
  '환자 승객 응대': Icons.medical_services_outlined,
  '좌석 안내': Icons.event_seat_outlined,
  '짐 보관 안내': Icons.luggage_outlined,
  '개별 브리핑': Icons.record_voice_over_outlined,
  '비상구열 브리핑': Icons.exit_to_app_outlined,
  '안전 업무': Icons.health_and_safety_outlined,
  '식사 서비스': Icons.restaurant_outlined,
  '입국 서류': Icons.description_outlined,
  '유상 판매': Icons.fastfood_outlined,
  '면세품 판매': Icons.shopping_bag_outlined,
  '불법 행위 승객 핸들링': Icons.local_police_outlined,
  '불만 승객 핸들링': Icons.sentiment_dissatisfied_outlined,
  '기타': Icons.more_horiz,
};

IconData categoryIcon(String category) =>
    categoryIcons[category] ?? Icons.chat_bubble_outline;

/// 카테고리 카드용 이모지 (홈 그리드).
const Map<String, String> categoryEmojis = {
  '탑승 안내': '✈️',
  '좌석 안내': '💺',
  '짐 보관 안내': '🎒',
  '식사 서비스': '🍷',
  '유상 판매': '🍷',
  '면세품 판매': '🛍️',
  '환자 승객 응대': '🚨',
  '안전 업무': '🚨',
  '비상구열 브리핑': '🚨',
  '개별 브리핑': '📢',
  '입국 서류': '📑',
  '불법 행위 승객 핸들링': '🚨',
  '불만 승객 핸들링': '💬',
  '기타': '✨',
};

String categoryEmoji(String category) =>
    categoryEmojis[category] ?? '💬';

/// 시나리오 주제 탭 — flight_stage를 4개 그룹으로 묶는다.
const scenarioSubjectTabs = <({String? id, String label})>[
  (id: null, label: '전체'),
  (id: 'boarding', label: '탑승 안내 (Boarding)'),
  (id: 'inflight', label: '기내 서비스'),
  (id: 'safety', label: '이착륙/비상'),
];

const _boardingStages = {
  '탑승 안내',
  '좌석 안내',
  '짐 보관 안내',
  '입국 서류',
};

const _inflightStages = {
  '식사 서비스',
  '유상 판매',
  '면세품 판매',
  '불만 승객 핸들링',
  '기타',
};

const _safetyStages = {
  '환자 승객 응대',
  '비상구열 브리핑',
  '안전 업무',
  '불법 행위 승객 핸들링',
  '개별 브리핑',
};

String? scenarioSubjectGroup(String flightStage) {
  final s = flightStage.trim();
  if (_boardingStages.contains(s)) return 'boarding';
  if (_inflightStages.contains(s)) return 'inflight';
  if (_safetyStages.contains(s)) return 'safety';
  return null;
}

bool scenarioMatchesSubject(String flightStage, String? subjectId) {
  if (subjectId == null) return true;
  return scenarioSubjectGroup(flightStage) == subjectId;
}
