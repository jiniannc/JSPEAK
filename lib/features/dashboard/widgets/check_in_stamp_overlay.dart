import 'package:flutter/material.dart';

/// 체크인 성공 시 중앙 도장 스탬프 팝업 (약 1초).
Future<void> showCheckInStampOverlay(BuildContext context, DateTime date) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _CheckInStampOverlay(date: date);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.elasticOut,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.35, end: 1).animate(scale),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _CheckInStampOverlay extends StatefulWidget {
  final DateTime date;

  const _CheckInStampOverlay({required this.date});

  @override
  State<_CheckInStampOverlay> createState() => _CheckInStampOverlayState();
}

class _CheckInStampOverlayState extends State<_CheckInStampOverlay> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String get _stampLabel {
    final y = widget.date.year;
    final m = widget.date.month.toString().padLeft(2, '0');
    final d = widget.date.day.toString().padLeft(2, '0');
    return '$y.$m.$d\nFLIGHT CLEARED ✔';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Transform.rotate(
          angle: -0.08,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.55),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 36,
                  color: Color(0xFF475569),
                ),
                const SizedBox(height: 10),
                Text(
                  _stampLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
