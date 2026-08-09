import 'package:flutter/material.dart';

/// 애플 월렛 스타일 순차 진입 — Y+24 → 0, opacity 0 → 1, easeOutCubic.
///
/// 화면 진입 시 [delay]만큼 대기한 뒤 [duration] 동안 단 한 번만 재생된다.
/// 부모 리빌드(provider 갱신 등)로 인해 위젯 트리 구조가 유지되는 한
/// [State]가 보존되어 애니메이션이 다시 실행되지 않는다.
class CascadeEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const CascadeEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
  });

  @override
  State<CascadeEntrance> createState() => _CascadeEntranceState();
}

class _CascadeEntranceState extends State<CascadeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - _curved.value) * widget.offsetY),
            child: child,
          ),
        );
      },
    );
  }
}
