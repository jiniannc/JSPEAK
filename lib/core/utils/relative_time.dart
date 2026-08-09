/// 상대 시간 한국어 표기.
String formatRelativeStudiedAt(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final current = now ?? DateTime.now();
  final diff = current.difference(at);

  if (diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';

  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  return '$mm.$dd';
}
