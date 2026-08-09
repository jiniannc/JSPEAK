import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/utils/relative_time.dart';

void main() {
  final now = DateTime(2026, 7, 14, 15, 0);

  test('relative studied at formats', () {
    expect(formatRelativeStudiedAt(now.subtract(const Duration(seconds: 20)), now: now), '방금 전');
    expect(formatRelativeStudiedAt(now.subtract(const Duration(minutes: 12)), now: now), '12분 전');
    expect(formatRelativeStudiedAt(now.subtract(const Duration(hours: 3)), now: now), '3시간 전');
    expect(formatRelativeStudiedAt(now.subtract(const Duration(days: 2)), now: now), '2일 전');
    expect(formatRelativeStudiedAt(DateTime(2026, 6, 3, 10), now: now), '06.03');
    expect(formatRelativeStudiedAt(null, now: now), '');
  });
}
