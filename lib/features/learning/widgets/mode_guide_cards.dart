import 'package:flutter/material.dart';

import '../../basic_sentence/widgets/achievement_stamps.dart';
import '../../dashboard/dashboard_palette.dart';

/// 닫힌 안내 카드를 다시 여는 칩.
class ModeGuideReopenButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onPressed;
  final String label;
  /// true면 그림자·강조색을 줄인 인라인용 톤.
  final bool compact;

  const ModeGuideReopenButton({
    super.key,
    required this.accent,
    required this.onPressed,
    this.label = '학습 안내',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = compact
        ? const Color(0xFF9AA3B2)
        : accent;
    final border = compact
        ? const Color(0xFFDCE1E8)
        : accent.withValues(alpha: 0.28);
    final bg = compact
        ? const Color(0xFFF3F5F8).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.92);

    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
        child: Ink(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 5 : 7,
            compact ? 8 : 12,
            compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(compact ? 14 : 20),
            border: Border.all(color: border),
            boxShadow: compact
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: compact ? 12 : 13,
                color: compact ? fg : accent,
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: accent.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (compact) return chip;
    return Align(alignment: Alignment.centerRight, child: chip);
  }
}

/// 시나리오 모드 — 대화형 훈련임을 한눈에 보여주는 안내 카드.
class ScenarioModeGuideCard extends StatelessWidget {
  final VoidCallback? onDismiss;

  const ScenarioModeGuideCard({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return _ModeGuideShell(
      gradient: const [
        Color(0xFFE8F8F8),
        Color(0xFFF5FFFE),
        Color(0xFFFFFBF0),
      ],
      accent: DashboardPalette.teal,
      onDismiss: onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideEyebrow(
                      icon: Icons.flight_takeoff_rounded,
                      label: 'HOW IT WORKS',
                      color: DashboardPalette.teal,
                    ),
                    SizedBox(height: 6),
                    Text(
                      '기내 상황을 대화로 연습해요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: DashboardPalette.navy,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '승객 대사를 듣고, 내 차례에 말해 보며\n실전 응대 감각을 키워요.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: DashboardPalette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _ScenarioHeroArt(),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _GuideStepTile(
                  step: '1',
                  title: '상황 선택',
                  hint: '탑승·서비스 등',
                  icon: Icons.map_rounded,
                  color: Color(0xFF5B9BD5),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _GuideStepTile(
                  step: '2',
                  title: '대화 진행',
                  hint: '듣고 응답하기',
                  icon: Icons.forum_rounded,
                  color: DashboardPalette.teal,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _GuideStepTile(
                  step: '3',
                  title: '발음 체크',
                  hint: '점수·피드백',
                  icon: Icons.graphic_eq_rounded,
                  color: Color(0xFFE67E22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 단어 스와이프 모드 — 좌·우 스와이프 학습을 보여주는 안내 카드.
class WordSwipeModeGuideCard extends StatelessWidget {
  final VoidCallback? onDismiss;

  const WordSwipeModeGuideCard({super.key, this.onDismiss});

  static const Color _known = DashboardPalette.teal;
  static const Color _unknown = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    return _ModeGuideShell(
      gradient: const [
        Color(0xFFFFF5F3),
        Color(0xFFFFFBFA),
        Color(0xFFF0FAF9),
      ],
      accent: const Color(0xFFE67E22),
      onDismiss: onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideEyebrow(
                      icon: Icons.style_rounded,
                      label: 'HOW IT WORKS',
                      color: Color(0xFFE67E22),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '카드를 스와이프하며 단어를 익혀요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: DashboardPalette.navy,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '아는 단어와 모르는 단어를 구분하고,\n나만의 단어장을 만들어 복습해요.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: DashboardPalette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _SwipeHeroArt(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SwipeActionHint(
                  direction: '왼쪽',
                  title: '헷갈려요',
                  icon: Icons.thumb_down_alt_rounded,
                  color: _unknown,
                  arrowIcon: Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SwipeActionHint(
                  direction: '오른쪽',
                  title: '외웠어요',
                  icon: Icons.thumb_up_alt_rounded,
                  color: _known,
                  arrowIcon: Icons.arrow_forward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 기본 문장 학습 — 3D 휠 + 스탬프 획득을 한 장에 안내.
class BasicSentenceModeGuideCard extends StatelessWidget {
  final VoidCallback? onDismiss;

  const BasicSentenceModeGuideCard({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return _ModeGuideShell(
      gradient: const [
        Color(0xFFEEF5FF),
        Color(0xFFF8FBFF),
        Color(0xFFFFF8F0),
      ],
      accent: const Color(0xFF4A90D9),
      onDismiss: onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideEyebrow(
                      icon: Icons.view_carousel_rounded,
                      label: 'HOW IT WORKS',
                      color: Color(0xFF4A90D9),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '서비스 외국어 표준 문장을 학습해요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: DashboardPalette.navy,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '표준 문장을 익히고 소리 내어 따라 말해보세요.\n내 발음 점수를 바로 분석해 드립니다.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: DashboardPalette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _WheelHeroArt(),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4A90D9).withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '주제마다 스탬프 3개를 모아요',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: DashboardPalette.navy,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StampExplainTile(
                        stamp: AchievementStamp(
                          label: '귀로 익히기',
                          icon: Icons.menu_book_rounded,
                          active: true,
                          ink: const Color(0xFF4A90D9),
                          rotation: -0.08,
                          size: 26,
                        ),
                        title: '귀로 익히기',
                        hint: '듣기 · 뜻 확인',
                        color: const Color(0xFF4A90D9),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StampExplainTile(
                        stamp: AchievementStamp(
                          label: '말하기 도전',
                          icon: Icons.mic_rounded,
                          active: true,
                          ink: DashboardPalette.teal,
                          rotation: 0.06,
                          size: 26,
                        ),
                        title: '말하기 도전',
                        hint: '소리 내어 따라 읽기',
                        color: DashboardPalette.teal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StampExplainTile(
                        stamp: AchievementStamp(
                          label: '발음 마스터',
                          icon: Icons.local_fire_department_rounded,
                          active: true,
                          ink: const Color(0xFFE67E22),
                          rotation: -0.05,
                          isGold: true,
                          size: 26,
                        ),
                        title: '발음 마스터',
                        hint: '80점 돌파 성공',
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StampExplainTile extends StatelessWidget {
  final Widget stamp;
  final String title;
  final String hint;
  final Color color;

  const _StampExplainTile({
    required this.stamp,
    required this.title,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        stamp,
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          hint,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: DashboardPalette.textMuted,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ModeGuideShell extends StatefulWidget {
  final List<Color> gradient;
  final Color accent;
  final Widget child;
  final VoidCallback? onDismiss;

  const _ModeGuideShell({
    required this.gradient,
    required this.accent,
    required this.child,
    this.onDismiss,
  });

  @override
  State<_ModeGuideShell> createState() => _ModeGuideShellState();
}

class _ModeGuideShellState extends State<_ModeGuideShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.9, curve: Curves.easeOutBack),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.topCenter,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              14,
              widget.onDismiss != null ? 8 : 14,
              8,
              14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradient,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: DashboardPalette.navy.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onDismiss != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: widget.onDismiss,
                      tooltip: '안내 닫기',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: DashboardPalette.navy.withValues(alpha: 0.45),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideEyebrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _GuideEyebrow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  final String step;
  final String title;
  final String hint;
  final IconData icon;
  final Color color;

  const _GuideStepTile({
    required this.step,
    required this.title,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(Colors.white, color, 0.15)!,
                      color.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DashboardPalette.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: DashboardPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionHint extends StatelessWidget {
  final String direction;
  final String title;
  final IconData icon;
  final IconData arrowIcon;
  final Color color;

  const _SwipeActionHint({
    required this.direction,
    required this.title,
    required this.icon,
    required this.arrowIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      arrowIcon,
                      size: 11,
                      color: color.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      direction,
                      style: TextStyle(
                        fontFamily: 'SUIT',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'SUIT',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
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

/// 시나리오 히어로 일러스트 — 기내 + 말풍선 + 마이크.
/// 3D 휠 히어로 일러스트 — 겹친 문장 카드 + 스와이프 화살표.
class _WheelHeroArt extends StatelessWidget {
  const _WheelHeroArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Opacity(
              opacity: 0.45,
              child: Transform.scale(
                scale: 0.88,
                child: _WheelMiniCard(
                  text: 'May I…',
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Opacity(
              opacity: 0.5,
              child: Transform.scale(
                scale: 0.88,
                child: _WheelMiniCard(
                  text: 'Please…',
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Positioned(
            top: 22,
            child: Container(
              width: 86,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4A90D9).withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90D9).withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    'Could you…',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DashboardPalette.navy,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 11, color: Color(0xFF4A90D9)),
                      SizedBox(width: 3),
                      Icon(Icons.mic_rounded,
                          size: 11, color: DashboardPalette.teal),
                      SizedBox(width: 3),
                      Icon(Icons.local_fire_department_rounded,
                          size: 11, color: Color(0xFFE67E22)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            right: -2,
            top: 8,
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Color(0xFF4A90D9),
            ),
          ),
          const Positioned(
            right: -2,
            bottom: 8,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF4A90D9),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelMiniCard extends StatelessWidget {
  final String text;
  final Color color;

  const _WheelMiniCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: DashboardPalette.textMuted,
        ),
      ),
    );
  }
}

class _ScenarioHeroArt extends StatelessWidget {
  const _ScenarioHeroArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: DashboardPalette.teal.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: DashboardPalette.teal.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_rounded, size: 12, color: Color(0xFF5B9BD5)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Passenger',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: DashboardPalette.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.flight_rounded, size: 11, color: DashboardPalette.teal),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 78),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Excuse me…',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: DashboardPalette.navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 72),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DashboardPalette.teal,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DashboardPalette.teal.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Of course!',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tap to speak…',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: DashboardPalette.textMuted
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE67E22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스와이프 히어로 일러스트 — 겹친 카드 + 좌우 화살표.
class _SwipeHeroArt extends StatelessWidget {
  const _SwipeHeroArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            top: 10,
            child: Transform.rotate(
              angle: -0.14,
              child: _MiniWordCard(
                color: const Color(0xFFE53935).withValues(alpha: 0.15),
                border: const Color(0xFFE53935).withValues(alpha: 0.35),
                label: '?',
                labelColor: const Color(0xFFE53935),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 8,
            child: Transform.rotate(
              angle: 0.16,
              child: _MiniWordCard(
                color: DashboardPalette.teal.withValues(alpha: 0.14),
                border: DashboardPalette.teal.withValues(alpha: 0.35),
                label: '✓',
                labelColor: DashboardPalette.teal,
              ),
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: 58,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.translate_rounded, size: 20, color: Color(0xFFE67E22)),
                  SizedBox(height: 6),
                  Text(
                    'stroller',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DashboardPalette.navy,
                    ),
                  ),
                  Text(
                    '유모차',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: DashboardPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 40,
            child: _BounceArrow(
              icon: Icons.arrow_back_rounded,
              color: const Color(0xFFE53935),
              flip: true,
            ),
          ),
          Positioned(
            right: 0,
            top: 40,
            child: _BounceArrow(
              icon: Icons.arrow_forward_rounded,
              color: DashboardPalette.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWordCard extends StatelessWidget {
  final Color color;
  final Color border;
  final String label;
  final Color labelColor;

  const _MiniWordCard({
    required this.color,
    required this.border,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: labelColor,
        ),
      ),
    );
  }
}

class _BounceArrow extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool flip;

  const _BounceArrow({
    required this.icon,
    required this.color,
    this.flip = false,
  });

  @override
  State<_BounceArrow> createState() => _BounceArrowState();
}

class _BounceArrowState extends State<_BounceArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = (widget.flip ? -1 : 1) * (3 + _controller.value * 4);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: 14, color: widget.color),
      ),
    );
  }
}
