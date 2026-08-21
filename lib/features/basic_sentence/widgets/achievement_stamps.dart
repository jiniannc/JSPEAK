import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/dashboard_palette.dart';

/// 읽기 / 녹음 / 마스터 성취 스탬프 클러스터.
class AchievementStampCluster extends StatelessWidget {
  final bool read;
  final bool attempted;
  final bool mastered;
  final double stampSize;
  final double width;
  /// true면 훈련 화면 등에서도 달성 즉시 바운스 재생.
  final bool animateOnActivate;

  const AchievementStampCluster({
    super.key,
    required this.read,
    required this.attempted,
    required this.mastered,
    this.stampSize = 36,
    this.width = 92,
    this.animateOnActivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final step = stampSize * 0.78;
    return SizedBox(
      width: width,
      height: stampSize + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: AchievementStamp(
              label: '귀로 익히기',
              icon: Icons.menu_book_rounded,
              active: read,
              ink: const Color(0xFF4A90D9),
              rotation: -0.12,
              size: stampSize,
              animateOnActivate: animateOnActivate,
            ),
          ),
          Positioned(
            left: step,
            top: 0,
            child: AchievementStamp(
              label: '말하기 도전',
              icon: Icons.mic_rounded,
              active: attempted,
              ink: DashboardPalette.teal,
              rotation: 0.08,
              size: stampSize,
              animateOnActivate: animateOnActivate,
            ),
          ),
          Positioned(
            left: step * 2,
            top: 2,
            child: AchievementStamp(
              label: '발음 마스터',
              icon: Icons.local_fire_department_rounded,
              active: mastered,
              ink: const Color(0xFFE67E22),
              rotation: -0.06,
              isGold: true,
              size: stampSize,
              animateOnActivate: animateOnActivate,
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementStamp extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color ink;
  final double rotation;
  final bool isGold;
  final double size;
  /// 비활성일 때 고유색을 옅게 깔아 채움 예고.
  final bool colorHint;
  /// true면 훈련 화면 위에서도 달성 즉시 바운스.
  final bool animateOnActivate;

  const AchievementStamp({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.ink,
    required this.rotation,
    this.isGold = false,
    this.size = 36,
    this.colorHint = false,
    this.animateOnActivate = false,
  });

  @override
  State<AchievementStamp> createState() => _AchievementStampState();
}

class _AchievementStampState extends State<AchievementStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;
  bool _pendingBounce = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.28, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(AchievementStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _requestBounce();
    }
  }

  bool get _isCoveredByTraining {
    final path = GoRouterState.of(context).uri.path;
    return path.contains('/sentences/play');
  }

  void _requestBounce() {
    if (widget.animateOnActivate || !_isCoveredByTraining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bounceController.forward(from: 0);
      });
    } else {
      _pendingBounce = true;
    }
  }

  void _playPendingBounceIfReady() {
    if (!_pendingBounce || _isCoveredByTraining) return;
    _pendingBounce = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bounceController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // play 화면에서 돌아오면 GoRouterState 의존으로 rebuild → 바운스 재생
    _playPendingBounceIfReady();

    final active = widget.active;
    final ink = widget.ink;
    final size = widget.size;
    final iconSize = active ? size * 0.44 : size * 0.39;
    final hint = !active && widget.colorHint;

    final inactiveFill =
        hint ? ink.withValues(alpha: 0.08) : const Color(0xFFF4F6F8);
    final inactiveBorder =
        hint ? ink.withValues(alpha: 0.22) : const Color(0xFFD5DBE3);
    final inactiveIcon =
        hint ? ink.withValues(alpha: 0.45) : const Color(0xFFB8C0CC);
    final dashColor =
        hint ? ink.withValues(alpha: 0.28) : const Color(0xFFC5CDD8);

    return Semantics(
      label: active ? '${widget.label} 스탬프 획득!' : '${widget.label} 스탬프',
      child: AnimatedBuilder(
        animation: _bounceScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceScale.value,
            child: child,
          );
        },
        child: Transform.rotate(
          angle: active ? widget.rotation : 0,
          child: AnimatedScale(
            scale: active ? 1.0 : 0.94,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: active ? 1.0 : 0.92,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: active
                      ? RadialGradient(
                          center: const Alignment(-0.35, -0.4),
                          radius: 1.05,
                          colors: widget.isGold
                              ? const [
                                  Color(0xFFFFF3C4),
                                  Color(0xFFFFB74D),
                                  Color(0xFFF57F17),
                                ]
                              : [
                                  Color.lerp(Colors.white, ink, 0.12)!,
                                  Color.lerp(Colors.white, ink, 0.42)!,
                                  ink,
                                ],
                        )
                      : null,
                  color: active ? null : inactiveFill,
                  border: Border.all(
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : inactiveBorder,
                    width: active ? 2.2 : 1.4,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: ink.withValues(
                              alpha: widget.isGold ? 0.45 : 0.32,
                            ),
                            blurRadius: widget.isGold ? 10 : 7,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.55),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!active)
                      CustomPaint(
                        size: Size(size, size),
                        painter: DashedRingPainter(color: dashColor),
                      ),
                    if (active)
                      Container(
                        width: size * 0.78,
                        height: size * 0.78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                        ),
                      ),
                    Icon(
                      widget.icon,
                      size: iconSize,
                      color: active ? Colors.white : inactiveIcon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedRingPainter extends CustomPainter {
  final Color color;

  DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    final inset = size.width * 0.11;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    const dashCount = 12;
    const sweep = (3.14159265 * 2) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.45, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 스탬프 획득 방법을 보여주는 글래스 가이드 카드.
class StampEarnGuideCard extends StatelessWidget {
  const StampEarnGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFFF7FAFF),
              const Color(0xFFFFF8F0).withValues(alpha: 0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: DashboardPalette.navy.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: Color(0xFFE67E22),
                ),
                SizedBox(width: 6),
                Text(
                  '스탬프를 모아 챕터를 완성해요',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            _StampGuideRow(
              label: '귀로 익히기',
              hint: '듣기 · 뜻 확인',
              icon: Icons.menu_book_rounded,
              ink: Color(0xFF4A90D9),
            ),
            SizedBox(height: 8),
            _StampGuideRow(
              label: '말하기 도전',
              hint: '소리 내어 따라 읽기',
              icon: Icons.mic_rounded,
              ink: DashboardPalette.teal,
            ),
            SizedBox(height: 8),
            _StampGuideRow(
              label: '발음 마스터',
              hint: '80점 돌파 성공',
              icon: Icons.local_fire_department_rounded,
              ink: Color(0xFFE67E22),
              isGold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StampGuideRow extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color ink;
  final bool isGold;

  const _StampGuideRow({
    required this.label,
    required this.hint,
    required this.icon,
    required this.ink,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AchievementStamp(
          label: label,
          icon: icon,
          active: true,
          ink: ink,
          rotation: isGold ? -0.05 : 0.06,
          isGold: isGold,
          size: 28,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: DashboardPalette.textMuted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 훈련 화면용 컴팩트 스탬프 안내 칩.
class StampEarnHintStrip extends StatelessWidget {
  final bool read;
  final bool attempted;
  final bool mastered;

  const StampEarnHintStrip({
    super.key,
    required this.read,
    required this.attempted,
    required this.mastered,
  });

  @override
  Widget build(BuildContext context) {
    String tip;
    if (!read) {
      tip = '듣기 · 뜻 확인으로 귀로 익히기';
    } else if (!attempted) {
      tip = '소리 내어 따라 읽으면 말하기 도전';
    } else if (!mastered) {
      tip = '80점 돌파하면 발음 마스터!';
    } else {
      tip = '이 문장 스탬프를 모두 모았어요';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AchievementStampCluster(
            read: read,
            attempted: attempted,
            mastered: mastered,
            stampSize: 26,
            width: 68,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.navy,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
