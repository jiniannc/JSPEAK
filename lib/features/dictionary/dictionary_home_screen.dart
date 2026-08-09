import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_favorite_providers.dart';
import '../../app/dictionary_providers.dart';
import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../shell/main_shell_tab_header.dart';
import 'widgets/dictionary_live_search.dart';

/// 기내사전 홈 — Dynamic Live Search Hero 레이아웃.
class DictionaryHomeScreen extends ConsumerWidget {
  const DictionaryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(selectedLanguageProvider);
    final contentAsync = ref.watch(contentProvider);
    final favorites = ref.watch(dictionaryFavoritesForLanguageProvider(12));
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;

    return DeviceScaffold(
      safeAreaBottom: false,
      safeAreaTop: false,
      backgroundColor: Colors.transparent,
      body: MainShellTabBody(
        child: contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (_) => AnimatedLanguageScope(
            language: language,
            builder: (context, palette) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DictionaryLiveSearchView(
                      language: language,
                      palette: palette,
                      inset: inset,
                      favorites: favorites,
                      onFavoriteTap: (item) =>
                          _handleFavoriteTap(context, ref, item),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleFavoriteTap(
    BuildContext context,
    WidgetRef ref,
    DictionaryFavoriteItem item,
  ) {
    switch (item) {
      case DictionaryFavoriteWordItem(:final entry):
        ref.read(dictionarySearchJumpProvider.notifier).apply(entry.term);
      case DictionaryFavoriteSentenceItem(:final sentence):
        context.push(
          '/scenarios/sentences/play'
          '?lang=${Uri.encodeComponent(sentence.language)}'
          '&category=${Uri.encodeComponent(sentence.category)}',
        );
    }
  }
}
