import 'package:intl/intl.dart';

import 'relative_time.dart';

/// 사용자에게 보여줄 동기화 실패 메시지.
String formatContentSyncError(Object error) {
  if (error is StateError) {
    return error.message;
  }
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out')) {
    return '네트워크에 연결할 수 없습니다. 저장된 데이터를 사용 중입니다.';
  }
  if (lower.contains('handshake') || lower.contains('certificate')) {
    return '보안 연결에 실패했습니다. 저장된 데이터를 사용 중입니다.';
  }
  if (raw.contains('비어 있어')) {
    return raw;
  }
  return '동기화에 실패했습니다. 저장된 데이터를 사용 중입니다.';
}

/// 마지막 성공 동기화 시각 (UI 한 줄).
String formatLastContentSync(DateTime? syncedAt, {DateTime? now}) {
  if (syncedAt == null) {
    return '마지막 동기화 기록이 없습니다';
  }
  final relative = formatRelativeStudiedAt(syncedAt, now: now);
  final absolute =
      DateFormat('yyyy-MM-dd HH:mm').format(syncedAt.toLocal());
  return '마지막 동기화: $relative ($absolute)';
}

/// 오래된 로컬 콘텐츠 경고 (기본 7일).
bool isContentSyncStale(DateTime? syncedAt, {DateTime? now, int days = 7}) {
  if (syncedAt == null) return true;
  final current = now ?? DateTime.now();
  return current.difference(syncedAt).inDays >= days;
}
