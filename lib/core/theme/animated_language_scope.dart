import 'package:flutter/material.dart';

import 'language_palette.dart';

/// 언어 전환 시 팔레트를 짧게 보간하며 Theme·배경을 갱신한다.
class AnimatedLanguageScope extends StatefulWidget {
  final String language;
  final Widget Function(BuildContext context, LanguagePalette palette) builder;

  const AnimatedLanguageScope({
    super.key,
    required this.language,
    required this.builder,
  });

  @override
  State<AnimatedLanguageScope> createState() => _AnimatedLanguageScopeState();
}

class _AnimatedLanguageScopeState extends State<AnimatedLanguageScope>
    with SingleTickerProviderStateMixin {
  late LanguagePalette _from;
  late LanguagePalette _to;
  late AnimationController _controller;
  late Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _from = LanguagePalette.forLanguage(widget.language);
    _to = _from;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant AnimatedLanguageScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _from = _currentPalette();
      _to = LanguagePalette.forLanguage(widget.language);
      _controller.forward(from: 0);
    }
  }

  LanguagePalette _currentPalette() {
    return _from.lerp(_to, _t.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final palette = _currentPalette();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: palette.toColorScheme(),
            scaffoldBackgroundColor: palette.canvas,
            extensions: [palette],
          ),
          child: widget.builder(context, palette),
        );
      },
    );
  }
}
