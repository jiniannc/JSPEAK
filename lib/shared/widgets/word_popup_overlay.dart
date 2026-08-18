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
    String language = 'English',
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
      language: language,
    );

    final screen = MediaQuery.sizeOf(context);
    const popupWidth = 320.0;
    const margin = 12.0;

    var left = anchor.center.dx - popupWidth / 2;
    left = left.clamp(margin, screen.width - popupWidth - margin);

    var top = anchor.bottom + 8;
    if (top + 320 > screen.height - margin) {
      top = anchor.top - 8 - 320;
    }
    top = top.clamp(margin, screen.height - margin);

    late OverlayEntry entryOverlay;
    entryOverlay = OverlayEntry(
      builder: (ctx) => _WordPopupLayer(
        left: left,
        top: top,
        width: popupWidth,
        entry: entry,
        onClose: dismiss,
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
    String language = 'English',
  }) {
    final words = WordCompare.splitTokens(sentence, language: language);
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

    final charStart = WordCompare.charOffsetForTokenIndex(
      words,
      wordStartIndex,
      language: language,
    );
    final charEnd = charStart +
        WordCompare.charLengthForTokenRange(
          words,
          wordStartIndex,
          wordEndIndex,
          language: language,
        );

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

class _WordPopupLayer extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final VocabularyEntry entry;
  final VoidCallback onClose;

  const _WordPopupLayer({
    required this.left,
    required this.top,
    required this.width,
    required this.entry,
    required this.onClose,
  });

  @override
  State<_WordPopupLayer> createState() => _WordPopupLayerState();
}

class _WordPopupLayerState extends State<_WordPopupLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
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
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: _PopupBackdropScrim(),
            ),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.width,
          child: _AnimatedWordPopup(
            fade: _fade,
            entry: widget.entry,
            onClose: widget.onClose,
          ),
        ),
      ],
    );
  }
}

class _PopupBackdropScrim extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.25),
    );
  }
}

class _AnimatedWordPopup extends StatefulWidget {
  final Animation<double> fade;
  final VocabularyEntry entry;
  final VoidCallback onClose;

  const _AnimatedWordPopup({
    required this.fade,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
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
      opacity: widget.fade,
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
