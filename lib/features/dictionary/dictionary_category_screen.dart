import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/dictionary_providers.dart';
import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../shared/widgets/language_canvas_background.dart';
import '../../data/models/sentence.dart';
import '../../features/dashboard/dashboard_palette.dart';
import '../../shared/widgets/sentence_card.dart';
import 'dictionary_pronunciation_display.dart';

/// 상황별 카테고리 문장 리스트 (홈에서 진입하는 서브 화면).
class DictionaryCategoryScreen extends ConsumerWidget {
  final String category;
  final String? language;

  const DictionaryCategoryScreen({
    super.key,
    required this.category,
    this.language,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String lang =
        language ?? ref.watch(selectedLanguageProvider);
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);
    final inset = metrics.pagePadding.left;

    return DeviceScaffold(
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (content) {
          final sentences =
              content.bundle.sentencesFor(lang, category);
          return AnimatedLanguageScope(
            language: lang,
            builder: (context, palette) => LanguageCanvasBackground(
              palette: palette,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, inset, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dictionary');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: DashboardPalette.navy,
                        tooltip: '뒤로',
                      ),
                      Hero(
                        tag: 'dict-cat-emoji-$category',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            categoryEmoji(category),
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Hero(
                          tag: 'dict-cat-title-$category',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: DashboardPalette.navy,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${sentences.length}개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.primary.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _CategorySentenceList(
                    sentences: sentences,
                    horizontalInset: inset,
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}

class _CategorySentenceList extends StatelessWidget {
  final List<Sentence> sentences;
  final double horizontalInset;

  const _CategorySentenceList({
    required this.sentences,
    required this.horizontalInset,
  });

  @override
  Widget build(BuildContext context) {
    if (sentences.isEmpty) {
      return Center(
        child: Text(
          '이 카테고리에 문장이 없습니다.',
          style: TextStyle(
            color: DashboardPalette.textMuted.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(horizontalInset, 4, horizontalInset, 28),
      itemCount: sentences.length,
      itemBuilder: (context, index) => SentenceCard(
        sentence: sentences[index],
        mode: SentenceCardMode.list,
        showFavoriteToggle: true,
      ),
    );
  }
}

/// 필수 기내 단어장 바텀시트.
Future<void> showCabinVocabularySheet(
  BuildContext context, {
  required String language,
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CabinVocabularySheet(
      language: language,
      accent: accent,
    ),
  );
}

class _CabinVocabularySheet extends ConsumerWidget {
  final String language;
  final Color accent;

  const _CabinVocabularySheet({
    required this.language,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).value;
    final words = content == null
        ? const []
        : content.bundle.words
            .where((w) =>
                w.language == language &&
                w.term.trim().isNotEmpty &&
                (w.important || w.popular > 0))
            .toList();

    // 중요/인기 단어가 부족하면 언어 전체에서 상위 노출
    final fallback = content == null
        ? const []
        : content.bundle.words
            .where((w) => w.language == language && w.term.trim().isNotEmpty)
            .take(40)
            .toList();
    final list = words.isNotEmpty ? words.take(50).toList() : fallback;

    final h = MediaQuery.sizeOf(context).height * 0.72;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기내 필수 단어장',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: DashboardPalette.navy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${languageLabel(language)} · ${list.length}개 훑어보기',
                            style: const TextStyle(
                              fontSize: 12,
                              color: DashboardPalette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 단어 데이터가 없어요.',
                          style: TextStyle(color: DashboardPalette.textMuted),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final w = list[i];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        w.term,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: DashboardPalette.navy,
                                        ),
                                      ),
                                    ),
                                    if (w.important)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '필수',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if ((w.pronunciation ?? '').isNotEmpty &&
                                    DictionaryPronunciationDisplay
                                        .isCjkLanguage(w.language)) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    w.pronunciation!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: DashboardPalette.textMuted,
                                    ),
                                  ),
                                ] else if ((w.pronunciation ?? '').isNotEmpty &&
                                    w.language == 'English') ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    w.pronunciation!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: DashboardPalette.textMuted,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  w.meaning,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: DashboardPalette.navy
                                        .withValues(alpha: 0.78),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
