import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dashboard_providers.dart';
import '../../app/learning_tour_providers.dart';
import '../../app/scenario_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/language_palette.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/scenario.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../shared/widgets/score_celebration_overlay.dart';
import 'scenario_tour.dart';
import 'widgets/scenario_chat_bubble.dart';
import 'widgets/scenario_glass_header.dart';

/// 대화식 실전 훈련 — 미니멀 채팅 + 플로팅 컨트롤.
class ScenarioTrainingScreen extends ConsumerStatefulWidget {
  final Scenario scenario;

  const ScenarioTrainingScreen({super.key, required this.scenario});

  @override
  ConsumerState<ScenarioTrainingScreen> createState() =>
      _ScenarioTrainingScreenState();
}

class _ScenarioTrainingScreenState extends ConsumerState<ScenarioTrainingScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _typingController = TextEditingController();
  final _typingFocus = FocusNode();

  late final AnimationController _shakeController;

  final ScenarioTourTargetKeys _tourKeys = ScenarioTourTargetKeys();
  bool _tourScheduled = false;
  bool _initialTourFinished = false;

  LanguagePalette get _palette =>
      LanguagePalette.forLanguage(widget.scenario.language);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scenarioTrainingProvider.notifier).init(widget.scenario);
      _scheduleInitialTour();
    });
  }

  String? _tourContextBubbleId(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    for (final msg in messages) {
      if (msg.kind == ChatBubbleKind.passenger) return msg.id;
    }
    return messages.first.id;
  }

  bool _canShowScenarioTour() {
    final training = ref.read(scenarioTrainingProvider);
    if (training.isCompleted) return false;
    final currentLine = ref.read(scenarioTrainingProvider.notifier).currentLine;
    final isCrewTurn = currentLine?.isCrew == true;
    if (!isCrewTurn) return false;
    return training.messages.isNotEmpty;
  }

  Future<void> _scheduleInitialTour() async {
    if (_tourScheduled || _initialTourFinished || !mounted) return;

    final completed = await ref
        .read(learningTourLocalDataSourceProvider)
        .hasCompletedScenarioTour();
    if (!mounted || completed) {
      _initialTourFinished = true;
      return;
    }

    _tourScheduled = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (!_canShowScenarioTour()) {
      _tourScheduled = false;
      return;
    }

    _initialTourFinished = true;
    await _startScenarioTour(force: false);
  }

  Future<void> _startScenarioTour({required bool force}) async {
    if (!mounted || ScenarioTour.isShowing) return;
    if (!force && !_canShowScenarioTour()) return;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || ScenarioTour.isShowing) return;

    await ScenarioTour.show(
      context: context,
      keys: _tourKeys,
      onComplete: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedScenarioTour(true);
      },
      onSkip: () async {
        await ref
            .read(learningTourLocalDataSourceProvider)
            .setCompletedScenarioTour(true);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _dismissSnackBars() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  }

  Future<void> _leaveScreen() async {
    _dismissSnackBars();
    await ref.read(scenarioTrainingProvider.notifier).stopAll();
    if (mounted) context.go('/scenarios/list');
  }

  @override
  void dispose() {
    // dispose 중에는 ref 사용 불가 — STT 정리는 Provider onDispose / _leaveScreen에서 처리.
    _scrollController.dispose();
    _typingController.dispose();
    _typingFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(scenarioTrainingProvider);
    final palette = _palette;
    final metrics = Active5Layout.of(context);
    final currentLine = ref.read(scenarioTrainingProvider.notifier).currentLine;
    final isCrewTurn =
        currentLine?.isCrew == true && !training.isCompleted;

    ref.listen<int>(scenarioTourReplaySignalProvider, (prev, next) {
      if ((prev ?? 0) < next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startScenarioTour(force: true);
        });
      }
    });

    ref.listen(scenarioTrainingProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.currentLineIndex != next.currentLineIndex) {
        _scrollToBottom();
      }
      if (prev?.currentLineIndex != next.currentLineIndex ||
          (prev?.isTypingMode == true &&
              next.isTypingMode == false &&
              next.selectedBlankIndex == null)) {
        _typingController.clear();
      }
      if (prev?.blankInputs != next.blankInputs &&
          next.selectedBlankIndex != null &&
          next.selectedBlankIndex! < next.blankInputs.length) {
        final t = next.blankInputs[next.selectedBlankIndex!];
        if (_typingController.text != t) {
          _typingController.value = TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          );
        }
      }
      if (prev?.selectedBlankIndex != next.selectedBlankIndex &&
          next.selectedBlankIndex != null &&
          next.selectedBlankIndex! < next.blankInputs.length) {
        final t = next.blankInputs[next.selectedBlankIndex!];
        _typingController.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
      if ((next.isTypingMode && !(prev?.isTypingMode ?? false)) ||
          (next.selectedBlankIndex != null &&
              prev?.selectedBlankIndex != next.selectedBlankIndex)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _typingFocus.requestFocus();
        });
      }
      if (prev?.shakeToken != next.shakeToken && next.shakeToken > 0) {
        _shakeController
          ..reset()
          ..forward();
      }
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        ref.invalidate(dashboardProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HapticFeedback.heavyImpact();
        });
        _showCompletionSnackBar(context, palette);
      }
      if (!_initialTourFinished &&
          !(prev?.isCompleted ?? false) &&
          _canShowScenarioTour()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleInitialTour();
        });
      }
    });

    final activeMsgId = training.activeCrewMessageId;
    final lineCount = widget.scenario.lines.length;
    final progress = training.isCompleted || lineCount == 0
        ? 1.0
        : (training.currentLineIndex / lineCount).clamp(0.0, 1.0);
    final metaParts = <String>[
      if (widget.scenario.title.trim().isNotEmpty)
        widget.scenario.title.trim(),
      if (widget.scenario.level.trim().isNotEmpty)
        widget.scenario.level.trim(),
    ];
    final metaLabel = metaParts.join(' • ');
    final tourBubbleId = _tourContextBubbleId(training.messages);

    // 플로팅 글래스 헤더 높이만큼 리스트 상단 여백 (스크롤 시 헤더 뒤로 지나감)
    const headerReserve = 84.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveScreen();
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: palette.toColorScheme(),
          extensions: [palette],
        ),
        child: DeviceScaffold(
        body: ColoredBox(
          color: DashboardPalette.softGray,
          child: Stack(
            children: [
              ListView(
                controller: _scrollController,
                padding: metrics.pagePadding.copyWith(
                  top: headerReserve,
                  bottom: isCrewTurn ? 200 : 24,
                ),
                children: [
                  for (final msg in training.messages)
                    ScenarioChatBubble(
                      key: ValueKey(msg.id),
                      tourHighlightKey: msg.id == tourBubbleId
                          ? _tourKeys.opponentBubbleKey
                          : null,
                      message: msg,
                      accentColor: palette.primary,
                      isActive:
                          msg.id == activeMsgId && !training.isCompleted,
                      liveSpokenText: msg.id == activeMsgId
                          ? training.spokenText
                          : '',
                      blankInputs: msg.id == activeMsgId
                          ? training.blankInputs
                          : const [],
                      selectedBlankIndex: msg.id == activeMsgId
                          ? training.selectedBlankIndex
                          : null,
                      onBlankTap: msg.id == activeMsgId &&
                              training.isBlankFillMode
                          ? (i) => ref
                              .read(scenarioTrainingProvider.notifier)
                              .selectBlank(i)
                          : null,
                    ),
                  if (training.isCompleted)
                    _CompletionBanner(
                      scenarioTitle: widget.scenario.title,
                      primaryColor: palette.primary,
                      secondaryColor: palette.secondary,
                    ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: ScenarioGlassHeader(
                    progress: progress,
                    metaLabel: metaLabel,
                    accentColor: palette.primary,
                    onBack: _leaveScreen,
                    onOptions: () => _showTrainingOptions(context),
                  ),
                ),
              ),
              if (isCrewTurn)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: SafeArea(
                    top: false,
                    child: _FloatingControlBar(
                      training: training,
                      primaryColor: palette.primary,
                      secondaryColor: palette.secondary,
                      shakeAnimation: _shakeController,
                      typingController: _typingController,
                      typingFocus: _typingFocus,
                      tourKeys: _tourKeys,
                      onHint: () => ref
                          .read(scenarioTrainingProvider.notifier)
                          .revealNextHint(),
                      onMic: () => ref
                          .read(scenarioTrainingProvider.notifier)
                          .toggleMic(),
                      onRevealAnswer: () => ref
                          .read(scenarioTrainingProvider.notifier)
                          .revealAnswerAndSkip(),
                      onToggleTyping: () {
                        final next = !training.isTypingMode;
                        ref
                            .read(scenarioTrainingProvider.notifier)
                            .setTypingMode(next);
                      },
                      onTypedChanged: (text) => ref
                          .read(scenarioTrainingProvider.notifier)
                          .updateTypedText(text),
                      onSubmitTyped: () => ref
                          .read(scenarioTrainingProvider.notifier)
                          .submitTypedAnswer(),
                    ),
                  ),
                ),
              if (training.isCompleted)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ScoreCelebrationOverlay(
                      tier: ScoreCelebrationTier.perfect,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showTrainingOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.route_rounded),
                  title: const Text('가이드 다시보기'),
                  subtitle: const Text('Scenario Tour'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(scenarioTourReplaySignalProvider.notifier)
                        .request();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded),
                  title: const Text('학습 종료'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _leaveScreen();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompletionSnackBar(BuildContext context, LanguagePalette palette) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.primary,
        content: const Text('시나리오를 완료했습니다! 학습 진도에 반영되었어요.'),
        action: SnackBarAction(
          label: '목록',
          textColor: Colors.white,
          onPressed: _leaveScreen,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating control bar
// ---------------------------------------------------------------------------

class _FloatingControlBar extends StatelessWidget {
  final ScenarioTrainingState training;
  final Color primaryColor;
  final Color secondaryColor;
  final AnimationController shakeAnimation;
  final TextEditingController typingController;
  final FocusNode typingFocus;
  final VoidCallback onHint;
  final VoidCallback onMic;
  final VoidCallback onRevealAnswer;
  final VoidCallback onToggleTyping;
  final ValueChanged<String> onTypedChanged;
  final VoidCallback onSubmitTyped;
  final ScenarioTourTargetKeys? tourKeys;

  const _FloatingControlBar({
    required this.training,
    required this.primaryColor,
    required this.secondaryColor,
    required this.shakeAnimation,
    required this.typingController,
    required this.typingFocus,
    required this.onHint,
    required this.onMic,
    required this.onRevealAnswer,
    required this.onToggleTyping,
    required this.onTypedChanged,
    required this.onSubmitTyped,
    this.tourKeys,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GuidanceBanner(
                text: training.guidanceText,
                feedback: training.feedback,
                primaryColor: primaryColor,
                shakeAnimation: shakeAnimation,
              ),
              if (training.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  training.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              const SizedBox(height: 12),
              if (training.isBlankFillMode) ...[
                if (training.selectedBlankIndex != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: typingController,
                          focusNode: typingFocus,
                          onChanged: onTypedChanged,
                          onSubmitted: (_) => onSubmitTyped(),
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DashboardPalette.navy,
                          ),
                          decoration: InputDecoration(
                            hintText: '빈칸 단어 입력 (연속 단어는 한 번에)',
                            hintStyle: TextStyle(
                              color: primaryColor.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: primaryColor.withValues(alpha: 0.25),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: primaryColor.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: primaryColor, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CompactIconButton(
                        icon: Icons.send_rounded,
                        color: primaryColor,
                        onTap: onSubmitTyped,
                        tooltip: '제출',
                      ),
                      const SizedBox(width: 4),
                      _CompactIconButton(
                        icon: training.isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: training.isListening
                            ? Colors.redAccent
                            : primaryColor,
                        onTap: onMic,
                        tooltip: training.isListening ? '녹음 종료' : '빈칸 녹음',
                      ),
                      const SizedBox(width: 4),
                      _CompactIconButton(
                        icon: Icons.visibility_outlined,
                        color: primaryColor,
                        onTap: onRevealAnswer,
                        tooltip: '정답 보기',
                      ),
                    ],
                  ),
                ] else if (training.isListening)
                  _ListeningRow(
                    soundLevel: training.soundLevel,
                    isInitializing: training.isInitializingStt,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    onMic: onMic,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _SideAction(
                          icon: Icons.touch_app_rounded,
                          label: '빈칸 터치',
                          color: primaryColor,
                          enabled: false,
                          onTap: () {},
                        ),
                      ),
                      _CompactIconButton(
                        icon: Icons.keyboard_rounded,
                        color: primaryColor,
                        onTap: onToggleTyping,
                        tooltip: '첫 빈칸 선택',
                      ),
                      const SizedBox(width: 8),
                      _MicButton(
                        enabled: !training.isInitializingStt,
                        isInitializing: training.isInitializingStt,
                        isListening: false,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        onPressed: onMic,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SideAction(
                          icon: Icons.visibility_outlined,
                          label: '정답',
                          color: primaryColor,
                          enabled: !training.isInitializingStt,
                          onTap: onRevealAnswer,
                        ),
                      ),
                    ],
                  ),
              ] else if (training.isTypingMode) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: typingController,
                        focusNode: typingFocus,
                        onChanged: onTypedChanged,
                        onSubmitted: (_) => onSubmitTyped(),
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DashboardPalette.navy,
                        ),
                        decoration: InputDecoration(
                          hintText: '정답을 직접 입력해 보세요',
                          hintStyle: TextStyle(
                            color: primaryColor.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (training.canRevealMoreHints) ...[
                      _CompactIconButton(
                        icon: Icons.lightbulb_outline_rounded,
                        color: primaryColor,
                        onTap: onHint,
                        tooltip: '힌트',
                      ),
                      const SizedBox(width: 4),
                    ],
                    _CompactIconButton(
                      icon: Icons.send_rounded,
                      color: primaryColor,
                      onTap: onSubmitTyped,
                      tooltip: '제출',
                    ),
                    const SizedBox(width: 4),
                    _CompactIconButton(
                      icon: Icons.mic_rounded,
                      color: primaryColor,
                      onTap: onToggleTyping,
                      tooltip: '음성으로 전환',
                    ),
                    const SizedBox(width: 4),
                    _CompactIconButton(
                      icon: Icons.visibility_outlined,
                      color: primaryColor,
                      onTap: onRevealAnswer,
                      tooltip: '정답 보기',
                    ),
                  ],
                ),
              ] else if (training.isListening)
                _ListeningRow(
                  soundLevel: training.soundLevel,
                  isInitializing: training.isInitializingStt,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  onMic: onMic,
                )
              else
                KeyedSubtree(
                  key: tourKeys?.toolbarKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SideAction(
                          icon: Icons.lightbulb_outline_rounded,
                          label: '힌트',
                          color: primaryColor,
                          enabled: training.canRevealMoreHints &&
                              !training.isInitializingStt,
                          onTap: onHint,
                        ),
                      ),
                      _CompactIconButton(
                        icon: Icons.keyboard_rounded,
                        color: primaryColor,
                        onTap: onToggleTyping,
                        tooltip: '타이핑 입력',
                      ),
                      const SizedBox(width: 8),
                      _MicButton(
                        tourKey: tourKeys?.micKey,
                        enabled: !training.isInitializingStt,
                        isInitializing: training.isInitializingStt,
                        isListening: false,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                        onPressed: onMic,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SideAction(
                          icon: Icons.visibility_outlined,
                          label: '정답',
                          color: primaryColor,
                          enabled: !training.isInitializingStt,
                          onTap: onRevealAnswer,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _CompactIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  final String text;
  final TrainingFeedback feedback;
  final Color primaryColor;
  final AnimationController shakeAnimation;

  const _GuidanceBanner({
    required this.text,
    required this.feedback,
    required this.primaryColor,
    required this.shakeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (feedback) {
      TrainingFeedback.wrong => const Color(0xFFFFEBEE),
      TrainingFeedback.correct => const Color(0xFFE8F5E9),
      TrainingFeedback.hint => primaryColor.withValues(alpha: 0.08),
      _ => primaryColor.withValues(alpha: 0.07),
    };
    final fg = switch (feedback) {
      TrainingFeedback.wrong => const Color(0xFFC62828),
      TrainingFeedback.correct => const Color(0xFF2E7D32),
      _ => primaryColor,
    };

    return AnimatedBuilder(
      animation: shakeAnimation,
      builder: (context, child) {
        final t = shakeAnimation.value;
        final shakeX = math.sin(t * math.pi * 6) * (1 - t) * 10;
        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: child,
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          // easeOutBack은 1.0을 넘어 오버슈트하므로 CurvedAnimation에 쓰면 크래시 남.
          // TweenSequence로 바운스감을 주되 부모 anim은 [0,1]만 사용.
          final slide = Tween<Offset>(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          final scale = TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.05), weight: 65),
            TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 35),
          ]).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));

          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          key: ValueKey('${feedback.name}_$text'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListeningRow extends StatelessWidget {
  final double soundLevel;
  final bool isInitializing;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onMic;

  const _ListeningRow({
    required this.soundLevel,
    required this.isInitializing,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _WaveformBars(
            soundLevel: soundLevel,
            color: primaryColor,
            mirror: true,
          ),
        ),
        const SizedBox(width: 10),
        _MicButton(
          enabled: true,
          isInitializing: isInitializing,
          isListening: true,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          onPressed: onMic,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WaveformBars(
            soundLevel: soundLevel,
            color: primaryColor,
            mirror: false,
          ),
        ),
      ],
    );
  }
}

class _WaveformBars extends StatelessWidget {
  final double soundLevel;
  final Color color;
  final bool mirror;

  const _WaveformBars({
    required this.soundLevel,
    required this.color,
    required this.mirror,
  });

  @override
  Widget build(BuildContext context) {
    // speech_to_text soundLevel ≈ -2 ~ 10
    final normalized = ((soundLevel + 2) / 12).clamp(0.05, 1.0);
    const barCount = 7;
    final heights = List.generate(barCount, (i) {
      final wave = math.sin((i + 1) * 0.9 + normalized * 8);
      final h = 8 + (normalized * 28) * (0.45 + 0.55 * wave.abs());
      return h.clamp(6.0, 36.0);
    });
    final bars = mirror ? heights.reversed.toList() : heights;

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 3.5,
              height: bars[i],
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.55 + normalized * 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _SideAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withValues(alpha: 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool enabled;
  final bool isInitializing;
  final bool isListening;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onPressed;
  final GlobalKey? tourKey;

  const _MicButton({
    required this.enabled,
    required this.isInitializing,
    required this.isListening,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onPressed,
    this.tourKey,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !isInitializing ? onPressed : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? (isListening
                    ? const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                      )
                    : LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ))
                : null,
            color: enabled ? null : DashboardPalette.borderLight,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (isListening ? Colors.red : primaryColor)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: isInitializing
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
        ),
      ),
    );

    if (tourKey != null) {
      return KeyedSubtree(key: tourKey, child: button);
    }
    return button;
  }
}

class _CompletionBanner extends StatelessWidget {
  final String scenarioTitle;
  final Color primaryColor;
  final Color secondaryColor;

  const _CompletionBanner({
    required this.scenarioTitle,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$scenarioTitle\n훈련 완료!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
