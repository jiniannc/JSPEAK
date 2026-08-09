import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/search_providers.dart';
import '../../../features/dashboard/dashboard_palette.dart';

/// Dynamic Island 스타일 플로팅 알약 검색창.
class DynamicIslandSearch extends ConsumerStatefulWidget {
  final Color accent;
  final ValueChanged<bool>? onExpandedChanged;
  final String compactHint;
  final String expandedHint;
  final bool showSuggestions;

  const DynamicIslandSearch({
    super.key,
    required this.accent,
    this.onExpandedChanged,
    this.compactHint = '무엇을 찾아볼까요?',
    this.expandedHint = '기내 표현 · 발음 · 한국어 검색',
    this.showSuggestions = true,
  });

  @override
  ConsumerState<DynamicIslandSearch> createState() =>
      _DynamicIslandSearchState();
}

class _DynamicIslandSearchState extends ConsumerState<DynamicIslandSearch> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final next = _focusNode.hasFocus;
    if (next == _expanded) return;
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _expandAndFocus() {
    if (!_expanded) {
      setState(() => _expanded = true);
      widget.onExpandedChanged?.call(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _collapse() {
    _focusNode.unfocus();
    if (_expanded) {
      setState(() => _expanded = false);
      widget.onExpandedChanged?.call(false);
    }
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    await ref.read(searchProvider.notifier).submitSearch(q);
    if (!mounted) return;
    _collapse();
    context.go('/dictionary/search');
  }

  Future<void> _applyTag(String tag) async {
    _controller.text = tag;
    await _submit(tag);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardUp = bottomInset > 0;
    final expanded = _expanded || keyboardUp;

    final screenW = MediaQuery.sizeOf(context).width;
    final compactW = (screenW * 0.72).clamp(220.0, 340.0);
    final fullW = screenW - 32;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.fastOutSlowIn,
            width: expanded ? fullW : compactW,
            height: expanded ? 52 : 46,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(expanded ? 22 : 28),
                onTap: expanded ? null : _expandAndFocus,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(expanded ? 22 : 28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.fastOutSlowIn,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius:
                            BorderRadius.circular(expanded ? 22 : 28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D000000),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 14 : 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: expanded ? 22 : 20,
                              color: widget.accent.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              // TextField는 항상 트리에 두어 FocusNode가 연결되게 함
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                readOnly: !expanded,
                                showCursor: expanded,
                                enableInteractiveSelection: expanded,
                                textInputAction: TextInputAction.search,
                                style: TextStyle(
                                  fontSize: expanded ? 15 : 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: DashboardPalette.navy.withValues(
                                    alpha: expanded ? 1 : 0.55,
                                  ),
                                ),
                                cursorColor: widget.accent,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: expanded
                                      ? widget.expandedHint
                                      : widget.compactHint,
                                  hintStyle: TextStyle(
                                    fontSize: expanded ? 14 : 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: DashboardPalette.textMuted
                                        .withValues(
                                      alpha: expanded ? 0.75 : 0.55,
                                    ),
                                  ),
                                ),
                                onTap: expanded ? null : _expandAndFocus,
                                onChanged: (v) {
                                  ref
                                      .read(searchProvider.notifier)
                                      .setQuery(v);
                                  setState(() {});
                                },
                                onSubmitted: _submit,
                              ),
                            ),
                            if (expanded && _controller.text.isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: DashboardPalette.textMuted
                                      .withValues(alpha: 0.7),
                                ),
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchProvider.notifier)
                                      .setQuery('');
                                  setState(() {});
                                },
                              )
                            else if (expanded)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: DashboardPalette.textMuted
                                      .withValues(alpha: 0.7),
                                ),
                                onPressed: _collapse,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showSuggestions)
          AnimatedSize(
            duration: const Duration(milliseconds: 420),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _SearchSuggestionPanel(
                      accent: widget.accent,
                      recent: ref.watch(searchProvider).recentQueries,
                      onTag: _applyTag,
                      onClearRecent: () =>
                          ref.read(searchProvider.notifier).clearRecent(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _SearchSuggestionPanel extends StatelessWidget {
  final Color accent;
  final List<String> recent;
  final ValueChanged<String> onTag;
  final VoidCallback onClearRecent;

  const _SearchSuggestionPanel({
    required this.accent,
    required this.recent,
    required this.onTag,
    required this.onClearRecent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 15,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recent.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '최근 검색',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: DashboardPalette.navy.withValues(alpha: 0.55),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClearRecent,
                      child: Text(
                        '지우기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in recent.take(6))
                      _PillTag(
                        label: q,
                        accent: accent,
                        onTap: () => onTag(q),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '추천 검색어',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: DashboardPalette.navy.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in kSuggestedSearchTags)
                    _PillTag(
                      label: tag,
                      accent: accent,
                      onTap: () => onTag(tag),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _PillTag({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DashboardPalette.navy.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}
