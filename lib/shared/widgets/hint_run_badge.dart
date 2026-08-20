import 'package:flutter/material.dart';

/// 빈칸·힌트 칩을 1:1로 짝지을 때 쓰는 작은 번호 배지.
class HintRunBadge extends StatelessWidget {
  final int number;
  final Color color;
  final double size;

  const HintRunBadge({
    super.key,
    required this.number,
    required this.color,
    this.size = 15,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = size <= 13 ? 8.0 : 9.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
