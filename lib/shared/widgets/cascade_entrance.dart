import 'dart:async';

import 'package:flutter/material.dart';

/// 애플 월렛 스타일 순차 진입 — Y+24 → 0, opacity 0 → 1, easeOutCubic.
///
/// 화면 진입 시 [delay]만큼 대기한 뒤 [duration] 동안 재생된다.
/// [replayToken]이 바뀌면 같은 State를 유지한 채 애니메이션만 다시 재생한다.
class CascadeEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final int replayToken;

  const CascadeEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
    this.replayToken = 0,
  });

  @override
  State<CascadeEntrance> createState() => _CascadeEntranceState();
}

class _CascadeEntranceState extends State<CascadeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  Timer? _delayTimer;
  int _playGen = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _play();
  }

  @override
  void didUpdateWidget(covariant CascadeEntrance oldWidget) {
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
