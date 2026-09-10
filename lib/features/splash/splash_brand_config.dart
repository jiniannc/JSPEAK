/// 스플래시 브랜드 미디어 설정.
///
/// 현재는 PNG 로고 + 점 애니메이션. 추후 Lottie/영상으로 교체할 때
/// [kind]와 asset 경로만 바꾸면 [SplashBrand] 위젯이 그대로 재사용된다.
enum SplashBrandKind {
  image,
  lottie,
  video,
}

class SplashBrandConfig {
  SplashBrandConfig._();

  static const kind = SplashBrandKind.lottie;

  static const imageAsset = 'assets/images/JSPEAKLOGO1.png';

  static const lottieAsset = 'assets/images/JSPEAKSPLASH.json';

  /// 영상 전환 시 예: `assets/video/splash_intro.mp4`
  static const videoAsset = '';

  /// 스플래시 최소 표시 시간 (너무 짧으면 로고가 번쩍하고 사라짐).
  static const minDisplayDuration = Duration(milliseconds: 1600);

  static const fadeOutDuration = Duration(milliseconds: 420);
}
