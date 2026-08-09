import 'package:flutter/material.dart';

/// 왼쪽 화면 끝에서 오른쪽으로 스와이프하면 콜백을 호출한다.
class LearningHubEdgeBack extends StatefulWidget {
  final bool enabled;
  final VoidCallback onBack;
  final Widget child;

  const LearningHubEdgeBack({
    super.key,
    required this.enabled,
    required this.onBack,
    required this.child,
  });

  static const edgeWidth = 28.0;
  static const triggerDistance = 72.0;

  @override
  State<LearningHubEdgeBack> createState() => _LearningHubEdgeBackState();
}

class _LearningHubEdgeBackState extends State<LearningHubEdgeBack> {
  double _drag = 0;

  void _resetDrag() => _drag = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx <= 0) {
      _resetDrag();
      return;
    }
    _drag += details.delta.dx;
    if (_drag >= LearningHubEdgeBack.triggerDistance) {
      _resetDrag();
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.enabled)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: LearningHubEdgeBack.edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: (_) => _resetDrag(),
              onHorizontalDragCancel: _resetDrag,
            ),
          ),
      ],
    );
  }
}
