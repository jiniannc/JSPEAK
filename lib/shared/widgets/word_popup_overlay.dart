import 'package:flutter/material.dart';

import '../../core/utils/word_compare.dart';
import '../../data/models/vocabulary_entry.dart';
import 'word_definition_card.dart';

/// 문장 내 단어 탭 위치 근처에 뜨는 미니 팝업 오버레이.
class WordPopupOverlay {
  WordPopupOverlay._();

  static OverlayEntry? _currentEntry;

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void show({
    required BuildContext context,
    required GlobalKey anchorKey,
    required String sentence,
    required int wordStartIndex,
    required int wordEndIndex,
    required TextStyle textStyle,
    required VocabularyEntry entry,
  }) {
    dismiss();

    final overlay = Overlay.of(context);
    final renderBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final anchorOffset = renderBox.localToGlobal(Offset.zero);
    final anchorSize = renderBox.size;
    final anchor = _phraseAnchorRect(
      sentence: sentence,
      wordStartIndex: wordStartIndex,
      wordEndIndex: wordEndIndex,
      textStyle: textStyle,
      maxWidth: anchorSize.width,
      globalOffset: anchorOffset,
    );

    final screen = MediaQuery.sizeOf(context);
    const popupWidth = 300.0;
    const margin = 12.0;

    var left = anchor.center.dx - popupWidth / 2;
    left = left.clamp(margin, screen.width - popupWidth - margin);

    var top = anchor.bottom + 8;
    if (top + 260 > screen.height - margin) {
      top = anchor.top - 8 - 260;
    }
    top = top.clamp(margin, screen.height - margin);

    late OverlayEntry entryOverlay;
    entryOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: dismiss,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: _AnimatedWordPopup(
              entry: entry,
              onClose: dismiss,
            ),
          ),
        ],
      ),
    );

    _currentEntry = entryOverlay;
    overlay.insert(entryOverlay);
  }

  static Rect _phraseAnchorRect({
    required String sentence,
    required int wordStartIndex,
    required int wordEndIndex,
    required TextStyle textStyle,
    required double maxWidth,
    required Offset globalOffset,
  }) {
    final words = WordCompare.splitWords(sentence);
    if (wordStartIndex < 0 ||
        wordEndIndex >= words.length ||
        wordStartIndex > wordEndIndex) {
      return Rect.fromLTWH(
        globalOffset.dx,
        globalOffset.dy,
        maxWidth,
        textStyle.fontSize ?? 16,
      );
    }

    var charStart = 0;
    for (var i = 0; i < wordStartIndex; i++) {
      charStart += words[i].length + 1;
    }

    var charEnd = charStart;
    for (var i = wordStartIndex; i <= wordEndIndex; i++) {
      if (i > wordStartIndex) charEnd += 1;
      charEnd += words[i].length;
    }

    final painter = TextPainter(
      text: TextSpan(text: sentence, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: charStart, extentOffset: charEnd),
    );

    if (boxes.isEmpty) {
      return Rect.fromLTWH(
        globalOffset.dx,
        globalOffset.dy,
        maxWidth,
        textStyle.fontSize ?? 16,
      );
    }

    var left = boxes.first.left;
    var top = boxes.first.top;
    var right = boxes.first.right;
    var bottom = boxes.first.bottom;
    for (final box in boxes) {
      left = left < box.left ? left : box.left;
      top = top < box.top ? top : box.top;
      right = right > box.right ? right : box.right;
      bottom = bottom > box.bottom ? bottom : box.bottom;
    }

    return Rect.fromLTWH(
      globalOffset.dx + left,
      globalOffset.dy + top,
      right - left,
      bottom - top,
    );
  }
}

class _AnimatedWordPopup extends StatefulWidget {
  final VocabularyEntry entry;
  final VoidCallback onClose;

  const _AnimatedWordPopup({
    required this.entry,
    required this.onClose,
  });

  @override
  State<_AnimatedWordPopup> createState() => _AnimatedWordPopupState();
}

class _AnimatedWordPopupState extends State<_AnimatedWordPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
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
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1).animate(_scale),
        alignment: Alignment.topCenter,
        child: WordDefinitionCard(
          entry: widget.entry,
          onClose: widget.onClose,
        ),
      ),
    );
  }
}
