import 'package:flutter/material.dart';

import '../../dashboard/dashboard_palette.dart';
import 'mode_guide_cards.dart';

enum _HubGuideMode { wordSwipe, basicSentence, scenario }

/// 학습 허브 상단 — 3모드 How it works를 한 줄 요약으로.
class LearningHubGuideStrip extends StatelessWidget {
  final VoidCallback onDismiss;

  const LearningHubGuideStrip({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return _HubGuidePanel(onDismiss: onDismiss);
  }
}

class _HubGuidePanel extends StatefulWidget {
  final VoidCallback onDismiss;

  const _HubGuidePanel({required this.onDismiss});

  @override
  State<_HubGuidePanel> createState() => _HubGuidePanelState();
}

class _HubGuidePanelState extends State<_HubGuidePanel> {
  _HubGuideMode? _expandedMode;

  static const _shadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  void _toggleMode(_HubGuideMode mode) {
    setState(() {
      _expandedMode = _expandedMode == mode ? null : mode;
    });
  }

  void _collapseMode() => setState(() => _expandedMode = null);

  Widget _expandedGuide(_HubGuideMode mode) {
    final onCollapse = _collapseMode;
    return switch (mode) {
      _HubGuideMode.wordSwipe => WordSwipeModeGuideCard(
          key: const ValueKey('hub_guide_word'),
          onDismiss: onCollapse,
        ),
      _HubGuideMode.basicSentence => BasicSentenceModeGuideCard(
          key: const ValueKey('hub_guide_sentence'),
          onDismiss: onCollapse,
        ),
      _HubGuideMode.scenario => ScenarioModeGuideCard(
          key: const ValueKey('hub_guide_scenario'),
          onDismiss: onCollapse,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        boxShadow: _shadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '학습 순서 안내',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onDismiss,
                tooltip: '안내 닫기',
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: DashboardPalette.navy.withValues(alpha: 0.45),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '각 비행 단계 카드에서 ① 단어 → ② 문장 스피킹 → ③ 시나리오 롤플레잉 순으로 연습해요.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: DashboardPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HubGuideModeTile(
                    step: '1',
                    title: '단어 스와이프',
                    hint: '안다/모른다 → 복습',
                    icon: Icons.style_rounded,
                    color: const Color(0xFFE67E22),
                    selected: _expandedMode == _HubGuideMode.wordSwipe,
                    onTap: () => _toggleMode(_HubGuideMode.wordSwipe),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HubGuideModeTile(
                    step: '2',
                    title: '문장 스피킹',
                    hint: '듣기·말하기·마스터',
                    icon: Icons.view_carousel_rounded,
                    color: const Color(0xFF4A90D9),
                    selected: _expandedMode == _HubGuideMode.basicSentence,
                    onTap: () => _toggleMode(_HubGuideMode.basicSentence),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HubGuideModeTile(
                    step: '3',
                    title: '시나리오 롤플레잉',
                    hint: '대화로 실전 연습',
                    icon: Icons.forum_rounded,
                    color: DashboardPalette.teal,
                    selected: _expandedMode == _HubGuideMode.scenario,
                    onTap: () => _toggleMode(_HubGuideMode.scenario),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expandedMode == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12, right: 8),
                    child: _expandedGuide(_expandedMode!),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HubGuideModeTile extends StatelessWidget {
  final String step;
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _HubGuideModeTile({
    required this.step,
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.14 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.55) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(icon, size: 16, color: color),
                  const Spacer(),
                  AnimatedRotation(
                    turns: selected ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: color.withValues(alpha: selected ? 0.85 : 0.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: DashboardPalette.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
