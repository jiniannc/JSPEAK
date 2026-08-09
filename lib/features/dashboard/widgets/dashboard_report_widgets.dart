import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/scenario_providers.dart';
import '../../../core/constants/labels.dart';
import '../dashboard_palette.dart';

/// ICN → NRT 비행 항로 진도 카드.
class FlightRouteProgressCard extends StatefulWidget {
  final double progress;
  final String departureCity;
  final String departureCode;
  final String arrivalCity;
  final String arrivalCode;
  final int practicedCount;
  final int totalCount;
  final String? subtitle;

  const FlightRouteProgressCard({
    super.key,
    required this.progress,
    required this.departureCity,
    required this.departureCode,
    required this.arrivalCity,
    required this.arrivalCode,
    this.practicedCount = 0,
    this.totalCount = 0,
    this.subtitle,
  });

  @override
  State<FlightRouteProgressCard> createState() =>
      _FlightRouteProgressCardState();
}

class _FlightRouteProgressCardState extends State<FlightRouteProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FlightRouteProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DashboardPalette.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DashboardPalette.borderLight),
        boxShadow: const [
          BoxShadow(
            color: DashboardPalette.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '전체 학습 항로',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DashboardPalette.navy,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: DashboardPalette.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (widget.totalCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${widget.practicedCount} / ${widget.totalCount} 시나리오 완료',
                        style: const TextStyle(
                          fontSize: 12,
                          color: DashboardPalette.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: DashboardPalette.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, _) {
              final animatedProgress =
                  widget.progress * _progressAnim.value.clamp(0.0, 1.0);
              return LayoutBuilder(
                builder: (context, constraints) {
                  const planeSize = 36.0;
                  const lineHeight = 4.0;
                  final trackWidth = constraints.maxWidth;
                  final planeLeft = (trackWidth - planeSize) *
                      animatedProgress.clamp(0.0, 1.0);

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _AirportLabel(
                            city: widget.departureCity,
                            code: widget.departureCode,
                            align: CrossAxisAlignment.start,
                          ),
                          _AirportLabel(
                            city: widget.arrivalCity,
                            code: widget.arrivalCode,
                            align: CrossAxisAlignment.end,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: planeSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                height: lineHeight,
                                decoration: BoxDecoration(
                                  color: DashboardPalette.borderLight,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor:
                                    animatedProgress.clamp(0.02, 1.0),
                                child: Container(
                                  height: lineHeight,
                                  decoration: BoxDecoration(
                                    gradient: DashboardPalette.routeGradient,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: DashboardPalette.teal
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: planeLeft,
                              top: 0,
                              child: Transform.rotate(
                                angle: math.pi / 2,
                                child: Container(
                                  width: planeSize,
                                  height: planeSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DashboardPalette.cardWhite,
                                    border: Border.all(
                                      color: DashboardPalette.teal,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: DashboardPalette.shadow,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.flight,
                                    color: DashboardPalette.teal,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AirportLabel extends StatelessWidget {
  final String city;
  final String code;
  final CrossAxisAlignment align;

  const _AirportLabel({
    required this.city,
    required this.code,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          city,
          style: const TextStyle(
            fontSize: 12,
            color: DashboardPalette.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          code,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashboardPalette.navy,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// 언어별 시나리오 진도 미니 바.
class ScenarioLanguageProgressPanel extends StatelessWidget {
  final List<LanguageProgressSummary> items;

  const ScenarioLanguageProgressPanel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardPalette.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashboardPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _LanguageProgressRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _LanguageProgressRow extends StatelessWidget {
  final LanguageProgressSummary item;

  const _LanguageProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final label = languageLabel(item.language);
    final percent = item.percent.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.navy,
              ),
            ),
            const Spacer(),
            Text(
              '$percent% (${item.completed}/${item.total})',
              style: const TextStyle(
                fontSize: 12,
                color: DashboardPalette.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.total == 0 ? 0 : item.percent / 100,
            minHeight: 6,
            backgroundColor: DashboardPalette.borderLight,
            color: DashboardPalette.teal,
          ),
        ),
      ],
    );
  }
}
