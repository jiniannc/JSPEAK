import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dashboard_providers.dart';
import '../../data/datasources/local/learning_tour_local_datasource.dart';
import '../../app/learning_tour_providers.dart';
import '../../app/providers.dart';
import '../../app/scenario_providers.dart';
import '../../app/vocabulary_providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/language_palette.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../data/models/scenario.dart';
import '../../data/models/scenario_training_result.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../shared/widgets/web_safe_backdrop_blur.dart';
import 'scenario_tour.dart';
import 'scenario_word_hints.dart';
import 'widgets/scenario_bubble_avatar.dart';
import 'widgets/scenario_chat_bubble.dart';
import 'widgets/scenario_glass_header.dart';
import 'widgets/scenario_result_modal.dart';

/// 대화식 실전 훈련 — 미니멀 채팅 + 플로팅 컨트롤.
class ScenarioTrainingScreen extends ConsumerStatefulWidget {
  final Scenario scenario;

  const ScenarioTrainingScreen({super.key, required this.scenario});

  @override
  ConsumerState<ScenarioTrainingScreen> createState() =>
      _ScenarioTrainingScreenState();
}

class _ScenarioTrainingScreenState extends ConsumerState<ScenarioTrainingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _typingController = TextEditingController();
  final _typingFocus = FocusNode();
  final _activeBubbleKey = GlobalKey();

  late final AnimationController _shakeController;

  final ScenarioTourTargetKeys _tourKeys = ScenarioTourTargetKeys();
  bool _tourScheduled = false;
  bool _initialTourFinished = false;

  /// 코치마크가 실제로 떠 있는 동안만 true — 아니면 tourHighlightKey를
  /// 아무 말풍선에도 주지 않아, 승객 말풍선 subtree가 GlobalKey 부착/해제로
  /// 불필요하게 재생성(타이핑 애니메이션 리플레이)되는 것을 막는다.
  bool _tourActive = false;
  bool _tourStarting = false;
  bool _resultSheetShowing = false;
  late final LearningTourLocalDataSource _tourLocalDataSource;
  double _lastKeyboardInset = 0;

  LanguagePalette get _palette =>
      LanguagePalette.forLanguage(widget.scenario.language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tourLocalDataSource = ref.read(learningTourLocalDataSourceProvider);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _typingFocus.addListener(_onTypingFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapScenario());
  }

  Future<void> _bootstrapScenario() async {
    final lines = widget.scenario.lines;
    final firstLine = lines.isNotEmpty ? lines.first : null;
    if (firstLine?.isCrew == true && firstLine!.avatarImage.isNotEmpty) {
      await ScenarioBubbleAvatar.precachePaths(
        context,
        [firstLine.avatarImage],
      );
    }
    if (!mounted) return;

    ref.read(scenarioTrainingProvider.notifier).init(widget.scenario);
    unawaited(
      ScenarioBubbleAvatar.precacheScenarios(context, [widget.scenario]),
    );
    _scheduleInitialTour();
  }

  void _onTypingFocusChanged() {
    if (_typingFocus.hasFocus) {
      _ensureActiveBubbleVisible();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      if (inset == _lastKeyboardInset) return;
      _lastKeyboardInset = inset;
      if (inset > 0) {
        _ensureActiveBubbleVisible();
      }
    });
  }

  /// 키보드·타이핑 중에도 승무원 말풍선이 컨트롤 바 위에 보이도록 스크롤.
  void _ensureActiveBubbleVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _activeBubbleKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.06,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? _tourContextBubbleId(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    for (final msg in messages) {
      if (msg.kind == ChatBubbleKind.passenger) return msg.id;
    }
    return messages.first.id;
  }

  /// 코치마크 1단계 — 아바타·한국어 프롬프트가 있는 활성 승무원 말풍선.
  String? _tourHighlightBubbleId(ScenarioTrainingState training) {
    final crewId = training.activeCrewMessageId;
    if (crewId != null) return crewId;
    return _tourContextBubbleId(training.messages);
  }

  Future<void> _ensureTourBubbleVisible() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final ctx = _tourKeys.opponentBubbleKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.18,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
    _tourScheduled = true;

    final completed = await _tourLocalDataSource.hasCompletedScenarioTour();
    if (!mounted || completed) {
      _initialTourFinished = true;
      return;
    }

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
    if (!mounted || ScenarioTour.isShowing || _tourStarting) return;
    if (!force && !_canShowScenarioTour()) return;

    _tourStarting = true;
    try {
      await _ensureTourBubbleVisible();
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (!mounted || ScenarioTour.isShowing) return;

      setState(() => _tourActive = true);
      await ScenarioTour.show(
        context: context,
        keys: _tourKeys,
        onComplete: () async {
          if (mounted) setState(() => _tourActive = false);
          await _tourLocalDataSource.setCompletedScenarioTour(true);
        },
        onSkip: () async {
          if (mounted) setState(() => _tourActive = false);
          await _tourLocalDataSource.setCompletedScenarioTour(true);
        },
      );
    } finally {
      _tourStarting = false;
    }
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
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/scenarios');
  }

  List<Scenario> get _orderedScenarios {
    final content = ref.read(contentProvider).value;
    if (content == null) return [];
    return content.bundle
        .scenariosFor(widget.scenario.language)
        .where((scenario) => !scenario.isSheetHeaderRow)
        .toList();
  }

  int get _currentScenarioIndex =>
      _orderedScenarios.indexWhere((scenario) => scenario.id == widget.scenario.id);

  Scenario? get _previousScenario {
    final index = _currentScenarioIndex;
    if (index <= 0) return null;
    return _orderedScenarios[index - 1];
  }

  Scenario? get _nextScenario {
    final index = _currentScenarioIndex;
    if (index < 0 || index + 1 >= _orderedScenarios.length) return null;
    return _orderedScenarios[index + 1];
  }

  void _retryScenario() {
    _typingController.clear();
    _typingFocus.unfocus();
    ref.read(scenarioTrainingProvider.notifier).init(widget.scenario);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _openScenario(Scenario scenario) async {
    await ref.read(scenarioTrainingProvider.notifier).stopAll();
    if (!mounted) return;
    context.go('/scenarios/train/${scenario.id}', extra: scenario);
  }

  Future<void> _showResultSheet(ScenarioTrainingResult result) async {
    if (_resultSheetShowing || !mounted) return;
    _resultSheetShowing = true;
    final previous = _previousScenario;
    final next = _nextScenario;
    await ScenarioResultModal.show(
      context: context,
      result: result,
      scenarioTitle: widget.scenario.title,
      onRetry: _retryScenario,
      onExit: _leaveScreen,
      previousScenario: previous,
      nextScenario: next,
      onPrevious: previous == null ? null : () => _openScenario(previous),
      onNext: next == null ? null : () => _openScenario(next),
    );
    if (mounted) _resultSheetShowing = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingFocus.removeListener(_onTypingFocusChanged);
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
    final isCrewTurn = currentLine?.isCrew == true && !training.isCompleted;

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
          if (mounted) {
            _typingFocus.requestFocus();
            _ensureActiveBubbleVisible();
          }
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
          if (mounted && next.result != null) {
            _showResultSheet(next.result!);
          }
        });
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
      if (widget.scenario.title.trim().isNotEmpty) widget.scenario.title.trim(),
      if (widget.scenario.level.trim().isNotEmpty) widget.scenario.level.trim(),
    ];
    final metaLabel = metaParts.join(' • ');
    // 코치마크가 실제로 떠 있지 않을 때는 계산하지 않음 — 아니면 fallback id가
    // 상태 전환마다 바뀌면서 승객 말풍선 subtree가 불필요하게 재생성된다.
    final tourBubbleId = _tourActive ? _tourHighlightBubbleId(training) : null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isTyping =
        training.isTypingMode || training.selectedBlankIndex != null;

    // 키보드가 열리면 inset 변화에 맞춰 말풍선 위치를 재조정한다.
    if (keyboardInset != _lastKeyboardInset && isTyping) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (keyboardInset != _lastKeyboardInset) {
          _lastKeyboardInset = keyboardInset;
          if (keyboardInset > 0) _ensureActiveBubbleVisible();
        }
      });
    }

    // 플로팅 글래스 헤더 높이만큼 리스트 상단 여백 (스크롤 시 헤더 뒤로 지나감)
    const headerReserve = 84.0;
    const controlBarClearance = 200.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveScreen();
        }
      },
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: palette.toColorScheme(), extensions: [palette]),
        child: DeviceScaffold(
          resizeToAvoidBottomInset: true,
          safeAreaBottom: false,
          body: ColoredBox(
            color: DashboardPalette.softGray,
            child: Stack(
              children: [
                // 리스트 뷰포트 자체를 플로팅 헤더 아래에서 시작시킨다.
                // 단순 top padding은 스크롤되면 사라져 overflow 아바타가 헤더와
                // 시스템 영역까지 침범하지만, Positioned 경계는 계속 유지된다.
                Positioned(
                  top: headerReserve,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ListView(
                    clipBehavior: Clip.hardEdge,
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: metrics.pagePadding.copyWith(
                      top: 0,
                      bottom: isCrewTurn ? controlBarClearance : 24,
                    ),
                    children: [
                      for (final (msgIndex, msg) in training.messages.indexed)
                        ScenarioChatBubble(
                          key: ValueKey(msg.id),
                          tourHighlightKey: msg.id == tourBubbleId
                              ? _tourKeys.opponentBubbleKey
                              : null,
                          scrollAnchorKey: msg.id == activeMsgId
                              ? _activeBubbleKey
                              : null,
                          // 리스트 첫 메시지는 위에 겹칠 대상이 없어 안전 모드로 표시.
                          allowTopOverlap: msgIndex > 0,
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
                          wordHints: msg.showWordHints
                              ? resolveBlankWordHints(
                                  index: ref.watch(vocabularyProvider),
                                  correct: msg.line.textTarget,
                                  blankFrame: msg.line.blankFrame,
                                  language: msg.line.language,
                                )
                              : const [],
                          karaokeTokenIndex: msg.id == activeMsgId
                              ? training.karaokeTokenIndex
                              : null,
                          blankAttentionToken: msg.id == activeMsgId
                              ? training.blankAttentionToken
                              : 0,
                          onBlankTap:
                              msg.id == activeMsgId && training.isBlankFillMode
                              ? (i) => ref
                                    .read(scenarioTrainingProvider.notifier)
                                    .selectBlank(i)
                              : null,
                          keyboardTyping:
                              msg.id == activeMsgId &&
                              !training.isCompleted &&
                              (training.isTypingMode ||
                                  training.selectedBlankIndex != null),
                        ),
                      if (training.isCompleted)
                        _CompletionBanner(
                          scenarioTitle: widget.scenario.title,
                          primaryColor: palette.primary,
                          secondaryColor: palette.secondary,
                        ),
                    ],
                  ),
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
      child: WebSafeBackdropBlur(
        sigmaX: 18,
        sigmaY: 18,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
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
                                color: primaryColor,
                                width: 1.5,
                              ),
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
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _SideAction(
                          icon: training.canRevealMoreHints
                              ? Icons.lightbulb_outline_rounded
                              : Icons.touch_app_rounded,
                          label: training.canRevealMoreHints
                              ? training.nextHintLabel
                              : '빈칸 터치',
                          color: primaryColor,
                          attentionToken: training.blankAttentionToken,
                          enabled:
                              training.canRevealMoreHints &&
                              !training.isListening &&
                              !training.isInitializingStt,
                          onTap: onHint,
                        ),
                      ),
                      _CompactIconButton(
                        icon: Icons.keyboard_rounded,
                        color: primaryColor,
                        enabled:
                            !training.isListening &&
                            !training.isInitializingStt,
                        onTap: onToggleTyping,
                        tooltip: '첫 빈칸 선택',
                      ),
                      const SizedBox(width: 8),
                      _MicButton(
                        enabled:
                            training.isListening || !training.isInitializingStt,
                        isInitializing:
                            training.isInitializingStt && !training.isListening,
                        isListening: training.isListening,
                        attentionToken: training.micAttentionToken,
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
                          enabled:
                              !training.isListening &&
                              !training.isInitializingStt,
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
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 1.5,
                            ),
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
                        tooltip: training.nextHintLabel,
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
              ] else
                KeyedSubtree(
                  key: tourKeys?.toolbarKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SideAction(
                          icon: Icons.lightbulb_outline_rounded,
                          label: training.nextHintLabel,
                          color: primaryColor,
                          attentionToken: training.blankAttentionToken,
                          enabled:
                              !training.isListening &&
                              !training.isInitializingStt &&
                              training.canRevealMoreHints,
                          onTap: onHint,
                        ),
                      ),
                      _CompactIconButton(
                        icon: Icons.keyboard_rounded,
                        color: primaryColor,
                        enabled:
                            !training.isListening &&
                            !training.isInitializingStt,
                        onTap: onToggleTyping,
                        tooltip: '타이핑 입력',
                      ),
                      const SizedBox(width: 8),
                      _MicButton(
                        tourKey: tourKeys?.micKey,
                        enabled:
                            training.isListening || !training.isInitializingStt,
                        isInitializing:
                            training.isInitializingStt && !training.isListening,
                        isListening: training.isListening,
                        attentionToken: training.micAttentionToken,
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
                          enabled:
                              !training.isListening &&
                              !training.isInitializingStt,
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
  final bool enabled;

  const _CompactIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? color : color.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? color.withValues(alpha: 0.1)
            : DashboardPalette.borderLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: iconColor, size: 22),
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
        return Transform.translate(offset: Offset(shakeX, 0), child: child);
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
              child: ScaleTransition(scale: scale, child: child),
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

class _SideAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final int attentionToken;

  const _SideAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.attentionToken = 0,
  });

  @override
  State<_SideAction> createState() => _SideActionState();
}

class _SideActionState extends State<_SideAction>
    with SingleTickerProviderStateMixin {
  static const _warmAccent = Color(0xFFFF6D00);

  late final AnimationController _pulse;
  Timer? _stopTimer;
  bool _pulsing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
  }

  @override
  void didUpdateWidget(covariant _SideAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attentionToken != oldWidget.attentionToken &&
        widget.attentionToken > 0) {
      _startPulse();
    }
  }

  void _startPulse() {
    _stopTimer?.cancel();
    setState(() => _pulsing = true);
    _pulse
      ..reset()
      ..repeat(reverse: true);
    _stopTimer = Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      _pulse
        ..stop()
        ..value = 0;
      setState(() => _pulsing = false);
    });
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.enabled ? widget.color : widget.color.withValues(alpha: 0.35);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulsing
            ? Curves.easeInOut.transform(_pulse.value)
            : 0.0;
        final accent = Color.lerp(base, _warmAccent, t * 0.72)!;
        return InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 22, color: accent),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MicButton extends StatefulWidget {
  final bool enabled;
  final bool isInitializing;
  final bool isListening;
  final int attentionToken;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onPressed;
  final GlobalKey? tourKey;

  const _MicButton({
    required this.enabled,
    required this.isInitializing,
    required this.isListening,
    this.attentionToken = 0,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onPressed,
    this.tourKey,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with TickerProviderStateMixin {
  static const _warmPrimary = Color(0xFFFF6D00);
  static const _warmSecondary = Color(0xFFFF9100);

  late final AnimationController _listenPulse;
  late final AnimationController _attentionPulse;
  Timer? _attentionStopTimer;
  bool _attentionActive = false;

  @override
  void initState() {
    super.initState();
    _listenPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _attentionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.isListening) {
      _listenPulse.repeat();
    } else if (widget.attentionToken > 0) {
      _playAttentionPulse();
    }
  }

  void _playAttentionPulse() {
    _attentionStopTimer?.cancel();
    setState(() => _attentionActive = true);
    _attentionPulse
      ..reset()
      ..repeat(reverse: true);
    _attentionStopTimer = Timer(const Duration(milliseconds: 3600), () {
      if (!mounted || widget.isListening) return;
      _attentionPulse
        ..stop()
        ..value = 0;
      setState(() => _attentionActive = false);
    });
  }

  @override
  void didUpdateWidget(covariant _MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (widget.isListening) {
      if (!_listenPulse.isAnimating) _listenPulse.repeat();
      if (_attentionActive) {
        _attentionStopTimer?.cancel();
        _attentionPulse
          ..stop()
          ..reset();
        _attentionActive = false;
      }
    } else {
      if (_listenPulse.isAnimating) {
        _listenPulse
          ..stop()
          ..reset();
      }
      if (widget.attentionToken != oldWidget.attentionToken) {
        _playAttentionPulse();
      }
    }
  }

  @override
  void dispose() {
    _attentionStopTimer?.cancel();
    _listenPulse.dispose();
    _attentionPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const micSize = 64.0;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled && !widget.isInitializing
            ? widget.onPressed
            : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: micSize,
          height: micSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.isListening)
                AnimatedBuilder(
                  animation: _listenPulse,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final phase in [0.0, 0.45])
                          Transform.scale(
                            scale:
                                1.0 + (_listenPulse.value + phase) % 1.0 * 0.55,
                            child: Container(
                              width: micSize,
                              height: micSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.withValues(
                                    alpha: 0.42 *
                                        (1 - ((_listenPulse.value + phase) % 1.0)),
                                  ),
                                  width: 2.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (_attentionActive && !widget.isListening)
                AnimatedBuilder(
                  animation: _attentionPulse,
                  builder: (context, _) {
                    final ringColor = Color.lerp(
                      widget.primaryColor,
                      _warmPrimary,
                      0.72,
                    )!;
                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (final phase in [0.0, 0.48])
                          Transform.scale(
                            scale: 1.0 +
                                ((_attentionPulse.value + phase) % 1.0) * 0.42,
                            child: Container(
                              width: micSize,
                              height: micSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ringColor.withValues(
                                    alpha: 0.62 *
                                        (1 -
                                            ((_attentionPulse.value + phase) %
                                                1.0)),
                                  ),
                                  width: 2.6,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              AnimatedBuilder(
                animation: _attentionPulse,
                builder: (context, _) {
                  final t = _attentionActive && !widget.isListening
                      ? Curves.easeInOut.transform(_attentionPulse.value)
                      : 0.0;
                  final warmth =
                      _attentionActive && !widget.isListening ? 0.72 * t : 0.0;
                  return Transform.scale(
                    scale: 1.0 + t * 0.08,
                    child: Container(
                      width: micSize,
                      height: micSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.enabled
                            ? (widget.isListening
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF5252),
                                        Color(0xFFD32F2F),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Color.lerp(
                                          widget.primaryColor,
                                          _warmPrimary,
                                          warmth,
                                        )!,
                                        Color.lerp(
                                          widget.secondaryColor,
                                          _warmSecondary,
                                          warmth,
                                        )!,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ))
                            : null,
                        color: widget.enabled ? null : DashboardPalette.borderLight,
                        boxShadow: widget.enabled
                            ? [
                                BoxShadow(
                                  color: (widget.isListening
                                          ? Colors.red
                                          : (_attentionActive
                                              ? _warmPrimary
                                              : widget.primaryColor))
                                      .withValues(
                                        alpha: widget.isListening
                                            ? 0.42
                                            : (0.35 + warmth * 0.38),
                                      ),
                                  blurRadius: widget.isListening
                                      ? 18
                                      : (14 + warmth * 10),
                                  spreadRadius: widget.isListening
                                      ? 1
                                      : (warmth * 2.4),
                                  offset: const Offset(0, 4),
                                ),
                                if (_attentionActive && !widget.isListening)
                                  BoxShadow(
                                    color: _warmSecondary.withValues(
                                      alpha: 0.18 + warmth * 0.28,
                                    ),
                                    blurRadius: 24 + warmth * 10,
                                    spreadRadius: 2 + warmth * 3,
                                  ),
                              ]
                            : null,
                      ),
                      child: widget.isInitializing
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                              size: widget.isListening ? 30 : 28,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tourKey != null) {
      return KeyedSubtree(key: widget.tourKey, child: button);
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
