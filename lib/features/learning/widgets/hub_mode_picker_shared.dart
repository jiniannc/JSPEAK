import 'package:flutter/material.dart';

import '../../dashboard/dashboard_palette.dart';
import '../../shell/floating_island_nav_bar.dart';
import 'mode_guide_overlay.dart';

/// 피커 앵커 — root Navigator Overlay 좌표.
({Offset anchor, Size size, OverlayState overlay})? popupAnchorFor(
  BuildContext context, {
  GlobalKey? anchorKey,
}) {
  final ctx = anchorKey?.currentContext ?? context;
  final box = ctx.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize || !box.attached) return null;

  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) return null;
  final anchor = box.localToGlobal(Offset.zero);
  return (anchor: anchor, size: box.size, overlay: overlay);
}

/// 선택 팝업 헤더 — 타이틀 행 오른쪽 ⓘ.
class HubModePickerHeader extends StatelessWidget {
  const HubModePickerHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.guideBuilder,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget Function(VoidCallback onDismiss)? guideBuilder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.045),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
        child: Row(
          children: [
            Icon(icon, size: 14, color: accent.withValues(alpha: 0.88)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: DashboardPalette.navy,
                ),
              ),
            ),
            if (guideBuilder != null)
              HubPickerGuideInfoMark(
                accent: accent,
                guideBuilder: guideBuilder!,
              ),
          ],
        ),
      ),
    );
  }
}

/// 심플 ⓘ — How it works 안내.
class HubPickerGuideInfoMark extends StatefulWidget {
  const HubPickerGuideInfoMark({
    super.key,
    required this.accent,
    required this.guideBuilder,
  });

  final Color accent;
  final Widget Function(VoidCallback onDismiss) guideBuilder;

  @override
  State<HubPickerGuideInfoMark> createState() => _HubPickerGuideInfoMarkState();
}

class _HubPickerGuideInfoMarkState extends State<HubPickerGuideInfoMark> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleOverlay() {
    if (_entry != null) {
      _removeOverlay();
      return;
    }

    final resolved = popupAnchorFor(context);
    if (resolved == null) return;

    final overlay = resolved.overlay;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return ModeGuideOverlayPanel(
          anchor: resolved.anchor,
          anchorSize: resolved.size,
          guide: widget.guideBuilder(() {
            entry.remove();
            if (_entry == entry) _entry = null;
          }),
          onDismiss: () {
            entry.remove();
            if (_entry == entry) _entry = null;
          },
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleOverlay,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'ⓘ',
            style: TextStyle(
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w500,
              color: widget.accent.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}

/// 학습 전 — 프로그레스 링 대신 표시하는 ▶ 시작 cue.
class HubPickerStartCue extends StatelessWidget {
  const HubPickerStartCue({
    super.key,
    required this.accent,
    this.label = '시작',
  });

  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: accent.withValues(alpha: 0.9),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: accent.withValues(alpha: 0.92),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 피커 팝업 위치 계산 공통값.
class HubPickerLayout {
  const HubPickerLayout._();

  static const preferredPopupWidth = 292.0;
  static const screenMargin = 14.0;
  static const anchorGap = 8.0;

  static double bottomObstruction(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return pad.bottom + FloatingIslandNavBar.reservedHeight(context);
  }
}
