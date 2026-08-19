import 'dart:ui';

import 'package:flutter/material.dart';

/// HUB · 마이페이지 · 홈 공통 True Glassmorphism (시나리오 모드 동일 스펙).
abstract final class GlassSurfaceStyle {
  static const shadowColor = Color(0x0C000000);
  static const fillAlpha = 0.75;
  static const borderAlpha = 0.8;
  static const borderWidth = 1.2;
  static const blurSigma = 12.0;

  /// 플로팅 아일랜드 네비 — 학습 모드 칩과 같은 프로스티드 글래스.
  static const floatingIslandBlur = 14.0;
  static const floatingIslandFillAlpha = 0.20;
  static const floatingIslandBorderAlpha = 0.34;

  /// 구분선·보조 선 (카드 외곽 유리 테두리와 별도).
  static const dividerColor = Color(0xFFCBD5E1);
  static const iconColor = Color(0xFF475569);
  static const titleColor = Color(0xFF1E293B);
  static const subtitleColor = Color(0xFF64748B);
  static const badgeBackground = Color(0xFFF1F5F9);
  static const deepSlate = Color(0xFF1E293B);
  static const outlineText = Color(0xFF334155);

  /// 홈 CTA pill — 42dp × radius 21.
  static const ctaHeight = 42.0;
  static const ctaRadius = 21.0;

  /// 홈 카드 — 클린 에어로 글래스 부유 그림자.
  static List<BoxShadow> cleanElevationShadow({double blur = 18}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: blur,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> cardShadow({double radius = 16}) => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static BoxDecoration surfaceDecoration({
    double radius = 16,
    double opacity = fillAlpha,
    bool showBorder = true,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: borderAlpha),
                width: borderWidth,
              )
            : null,
      );

  /// CTA · 딥 다크 글래스 pill (체크인, 듣기, 이어서 하기, 바로 도전).
  static BoxDecoration deepDarkGlassButton({
    double radius = ctaRadius,
    double opacity = 0.92,
  }) =>
      BoxDecoration(
        color: deepSlate.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      );

  /// 보조 CTA · 라이트 글래스 pill (발음 연습 등).
  static BoxDecoration lightGlassButton({
    double radius = ctaRadius,
    double opacity = 0.65,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.0,
        ),
      );

  /// @deprecated 호환용 — `surfaceDecoration` 사용.
  static BoxDecoration decoration({
    double radius = 16,
    double opacity = fillAlpha,
  }) =>
      surfaceDecoration(radius: radius, opacity: opacity);
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final double opacity;
  final bool showBorder;
  final double? blurSigma;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 16,
    this.opacity = GlassSurfaceStyle.fillAlpha,
    this.showBorder = true,
    this.blurSigma,
  });

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma ?? GlassSurfaceStyle.blurSigma;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: GlassSurfaceStyle.cardShadow(radius: radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: GlassSurfaceStyle.surfaceDecoration(
              radius: radius,
              opacity: opacity,
              showBorder: showBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 프리미엄 3D 럭셔리 글래스 카드 — 대각선 스펙ular 림 + 앰비언트 글로우 + 블러.
class LuxuryGlassCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final List<BoxShadow> ambientGlow;
  final double radius;
  final double blurSigma;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const LuxuryGlassCard({
    super.key,
    required this.child,
    required this.gradientColors,
    required this.ambientGlow,
    this.radius = 18,
    this.blurSigma = 16,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  static const _rimBegin = Color(0xF2FFFFFF);
  static const _rimEnd = Color(0x1FFFFFFF);

  @override
  Widget build(BuildContext context) {
    const rimWidth = 1.2;
    final innerRadius = radius - rimWidth;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: ambientGlow,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_rimBegin, _rimEnd],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(rimWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: begin,
                    end: end,
                  ),
                  borderRadius: BorderRadius.circular(innerRadius),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 홈 Live Ticket Wallet — 클린 에어로 글래스 + 절취선.
class TicketWalletCard extends StatelessWidget {
  final List<Color> meshGradientColors;
  final List<BoxShadow> ambientShadow;
  final Widget body;
  final Widget footer;
  final double radius;
  final double blurSigma;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;

  const TicketWalletCard({
    super.key,
    required this.meshGradientColors,
    this.ambientShadow = const [],
    required this.body,
    required this.footer,
    this.radius = 18,
    this.blurSigma = 16,
    this.gradientBegin = Alignment.centerLeft,
    this.gradientEnd = Alignment.centerRight,
  });

  /// 단색 틴트 호환 생성자.
  factory TicketWalletCard.tint({
    Key? key,
    required Color tintColor,
    required Widget body,
    required Widget footer,
    List<BoxShadow>? ambientShadow,
    double radius = 18,
    double blurSigma = 16,
  }) {
    return TicketWalletCard(
      key: key,
      meshGradientColors: [
        tintColor.withValues(alpha: 0.85),
        tintColor.withValues(alpha: 0.50),
      ],
      ambientShadow:
          ambientShadow ?? GlassSurfaceStyle.cleanElevationShadow(),
      body: body,
      footer: footer,
      radius: radius,
      blurSigma: blurSigma,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shadows = ambientShadow.isEmpty
        ? GlassSurfaceStyle.cleanElevationShadow()
        : ambientShadow;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                colors: meshGradientColors,
                begin: gradientBegin,
                end: gradientEnd,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                const TicketPerforationDivider(),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 보딩패스 절취선 — 본문과 CTA 사이 가로 점선.
class TicketPerforationDivider extends StatelessWidget {
  const TicketPerforationDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 1),
            painter: HorizontalDashedLinePainter(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          );
        },
      ),
    );
  }
}

/// 가로 점선 (티켓 절취선).
class HorizontalDashedLinePainter extends CustomPainter {
  final Color color;

  HorizontalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;

    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant HorizontalDashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 수채화 글래스 카드 — 투명 화이트 베이스 + 옅은 테마 틴트 + 블러.
class WatercolorGlassCard extends StatelessWidget {
  final Widget child;
  final Color tintColor;
  final double tintOpacity;
  final double radius;
  final double blurSigma;
  final double baseWhiteOpacity;

  const WatercolorGlassCard({
    super.key,
    required this.child,
    required this.tintColor,
    this.tintOpacity = 0.1,
    this.radius = 18,
    this.blurSigma = 16,
    this.baseWhiteOpacity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: baseWhiteOpacity);
    final tint = tintColor.withValues(alpha: tintOpacity);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: GlassSurfaceStyle.cardShadow(radius: radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(tint, base),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 비비드 틴티드 글래스 카드 — 컬러 그라디언트 배경 + 강한 블러 + 백색 하이라이트 테두리.
/// (홈 카드 스택 전용: 딥 인디고 / 에메랄드-시안 / 바이올렛-로즈)
class TintedGlassCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double radius;
  final double blurSigma;
  final Color borderColor;
  final double borderWidth;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const TintedGlassCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.radius = 18,
    this.blurSigma = 16,
    this.borderColor = const Color(0x4DFFFFFF),
    this.borderWidth = 1.2,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: GlassSurfaceStyle.cardShadow(radius: radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: begin,
                end: end,
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 비비드 시안 글래스 CTA pill (딥 인디고 카드의 메인 버튼용).
class GlassVividCtaButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double radius;
  final double fontSize;
  final double horizontalPadding;
  final double iconSize;
  final List<Color> gradientColors;

  const GlassVividCtaButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
    this.width,
    this.height,
    this.radius = GlassSurfaceStyle.ctaRadius,
    this.fontSize = 12,
    this.horizontalPadding = 12,
    this.iconSize = 15,
    this.gradientColors = const [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: iconSize, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onPressed == null) return button;

    return GlassPressableScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: button,
    );
  }
}

/// 홈 CTA — 맑은 반투명 화이트 프로스트 글래스 pill.
class LuxuryFloatingGlassButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final Color labelColor;
  final double? width;
  final double? height;
  final double radius;
  final double fontSize;
  final double horizontalPadding;
  final double iconSize;

  const LuxuryFloatingGlassButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
    this.labelColor = const Color(0xFF0F172A),
    this.width,
    this.height,
    this.radius = GlassSurfaceStyle.ctaRadius,
    this.fontSize = 12,
    this.horizontalPadding = 12,
    this.iconSize = 15,
  });

  Widget _buildInner() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: iconSize, color: labelColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: labelColor,
                letterSpacing: 0.1,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: GlassSurfaceStyle.cleanElevationShadow(blur: 8),
        ),
        child: height != null
            ? Center(child: _buildInner())
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildInner(),
              ),
      ),
    );

    if (onPressed == null) return button;

    return GlassPressableScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: button,
    );
  }
}

/// @deprecated — [LuxuryFloatingGlassButton] 사용.
class FrostedGlassCtaButton extends LuxuryFloatingGlassButton {
  const FrostedGlassCtaButton({
    super.key,
    required super.label,
    super.leadingIcon,
    super.onPressed,
    super.width,
    super.height,
    super.radius = GlassSurfaceStyle.ctaRadius,
    super.fontSize = 12,
    super.horizontalPadding = 12,
    super.iconSize = 15,
  });
}

/// 글래스 버튼 탭 시 0.96 스케일 미세 피드백.
class GlassPressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const GlassPressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(21)),
  });

  @override
  State<GlassPressableScale> createState() => _GlassPressableScaleState();
}

class _GlassPressableScaleState extends State<GlassPressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              widget.onTap!();
            }
          : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 홈 주요 CTA — 딥 다크 글래스 pill.
class GlassDeepDarkCtaButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double radius;
  final double fontSize;
  final double horizontalPadding;
  final double? verticalPadding;
  final double iconSize;
  final FontWeight fontWeight;

  const GlassDeepDarkCtaButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
    this.width,
    this.height,
    this.radius = GlassSurfaceStyle.ctaRadius,
    this.fontSize = 14,
    this.horizontalPadding = 16,
    this.verticalPadding,
    this.iconSize = 16,
    this.fontWeight = FontWeight.w700,
  });

  Widget _buildInner() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: height == null ? (verticalPadding ?? 8) : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: iconSize, color: Colors.white),
            SizedBox(width: iconSize >= 15 ? 5 : 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: Colors.white,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: GlassSurfaceStyle.deepDarkGlassButton(radius: radius),
        child: height != null
            ? Center(child: _buildInner())
            : _buildInner(),
      ),
    );

    if (onPressed == null) return button;

    return GlassPressableScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: button,
    );
  }
}

/// 홈 보조 CTA — 라이트 글래스 pill.
class GlassLightCtaButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double radius;
  final double fontSize;
  final double horizontalPadding;
  final double? verticalPadding;
  final double iconSize;
  final FontWeight fontWeight;

  const GlassLightCtaButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
    this.width,
    this.height,
    this.radius = GlassSurfaceStyle.ctaRadius,
    this.fontSize = 14,
    this.horizontalPadding = 16,
    this.verticalPadding,
    this.iconSize = 16,
    this.fontWeight = FontWeight.w600,
  });

  Widget _buildInner() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: height == null ? (verticalPadding ?? 8) : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: iconSize,
              color: GlassSurfaceStyle.outlineText,
            ),
            SizedBox(width: iconSize >= 15 ? 5 : 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: GlassSurfaceStyle.outlineText,
                letterSpacing: 0.1,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: GlassSurfaceStyle.lightGlassButton(radius: radius),
        child: height != null
            ? Center(child: _buildInner())
            : _buildInner(),
      ),
    );

    if (onPressed == null) return button;

    return GlassPressableScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: button,
    );
  }
}
