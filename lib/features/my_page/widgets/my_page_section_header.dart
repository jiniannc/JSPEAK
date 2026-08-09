import 'package:flutter/material.dart';

/// 마이페이지 섹션 명판 — 슬레이트 톤 항공 시스템 UI.
class MyPageSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const MyPageSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const iconColor = Color(0xFF475569);
  static const titleColor = Color(0xFF1E293B);
  static const subtitleColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    height: 1.25,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
