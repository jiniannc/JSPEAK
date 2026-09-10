/// 앱 전역 설정.
///
/// 콘텐츠 동기화 URL은 빌드 시점에 주입한다:
/// ```
/// flutter build apk --dart-define=CONTENT_URL=https://script.google.com/macros/s/XXXX/exec
/// ```
/// 나중에 Firebase Hosting의 content.json 등으로 바꿔도
/// 이 값만 교체하면 되고 앱 코드는 수정할 필요가 없다.
class AppConfig {
  AppConfig._();

  static const String contentUrl = String.fromEnvironment(
    'CONTENT_URL',
    defaultValue: '',
  );

  /// 빌드 시 .../exe 오타를 .../exec 로 보정한다.
  static String get normalizedContentUrl {
    if (contentUrl.isEmpty) return contentUrl;
    if (contentUrl.endsWith('/exe') && !contentUrl.endsWith('/exec')) {
      return '${contentUrl}c';
    }
    return contentUrl;
  }

  static bool get isConfigured => normalizedContentUrl.isNotEmpty;

  static const String appName = 'JSPEAK';
  static const String appSubtitle = 'Global Communication Onboard';

  /// 앱 표시 버전 (마이페이지 · 업데이트 확인).
  static const String appVersion = '1.2.0';
}
