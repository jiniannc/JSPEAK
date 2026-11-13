import 'package:flutter/foundation.dart';

/// 디버그/프로파일에서만 출력되는 앱 공통 로그.
abstract final class AppLog {
  static void debug(String tag, String message, [Object? error, StackTrace? st]) {
    _print('DEBUG', tag, message, error, st);
  }

  static void warn(String tag, String message, [Object? error, StackTrace? st]) {
    _print('WARN', tag, message, error, st);
  }

  static void _print(
    String level,
    String tag,
    String message,
    Object? error,
    StackTrace? st,
  ) {
    if (!kDebugMode && !kProfileMode) return;
    final buffer = StringBuffer('[$level][$tag] $message');
    if (error != null) {
      buffer.write('\n  $error');
    }
    if (st != null) {
      buffer.write('\n$st');
    }
    debugPrint(buffer.toString());
  }
}
