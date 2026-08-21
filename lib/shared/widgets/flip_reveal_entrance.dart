import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 입체 한 바퀴 플립 리빌 — 가로축(X) 원근 회전 + 스케일 착지.
///
/// 가로로 긴 탑승권이 수평 모서리 기준으로 뒤집혀, 엣지 순간에
/// 가로 선이 된다. [replayToken]이 바뀌면 애니메이션만 다시 재생한다.
/// [back]이 있으면 뒷면이 보이는 구간에서 미러된 앞면 대신 그 위젯을 그린다.
class FlipRevealEntrance extends StatefulWidget {
  final Widget child;
  final Widget? back;
  final Duration delay;
  final Duration duration;
  final int replayToken;

  const FlipRevealEntrance({
    super.key,
    required this.child,
    this.back,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 540),
    this.replayToken = 0,
  });

  @override
  State<FlipRevealEntrance> createState() => _FlipRevealEntranceState();
}

class _FlipRevealEntranceState extends State<FlipRevealEntrance>
    with SingleTickerProviderStateMixin {
  static const _perspective = 0.0017;
  static const _startScale = 0.86;

  late final AnimationController _controller;
  Timer? _delayTimer;
  int _playGen = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _play();
  }

  @override
  void didUpdateWidget(covariant FlipRevealEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.replayToken != oldWidget.replayToken) {
      _play();
    }
  }

  void _play() {
    _delayTimer?.cancel();
    _controller.stop();
    _controller.value = 0;
    final gen = ++_playGen;
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted && gen == _playGen) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final spinT = Curves.easeInOutCubic.transform(t);
        final settleT = Curves.easeOutBack.transform(t);

        // 3π → 0: 뒷면으로 시작해 한 바퀴 더 돈 뒤 앞면으로 착지.
        final angleX = (1 - spinT) * math.pi * 3;
        final scale = _startScale +
            (1 - _startScale) * settleT.clamp(0.0, 1.12);
        final opacity = Curves.easeOut.transform((t / 0.14).clamp(0.0, 1.0));
        final facingFront = math.cos(angleX) >= 0;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, _perspective)
          ..rotateX(angleX);

        return Opacity(
          opacity: opacity,
          child: IgnorePointer(
            ignoring: t < 0.92,
            child: Transform(
              alignment: Alignment.center,
              transform: matrix,
              filterQuality: FilterQuality.medium,
              child: Transform.scale(
                scale: scale,
                child: _buildFace(
                  child: child!,
                  facingFront: facingFront,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFace({
    required Widget child,
    required bool facingFront,
  }) {
    final back = widget.back;
    if (back == null) return child;

    return Stack(
      children: [
        Visibility(
          visible: facingFront,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: facingFront ? 0 : 1,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationX(math.pi),
                child: back,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
