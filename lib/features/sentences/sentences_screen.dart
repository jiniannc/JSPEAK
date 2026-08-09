import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/widgets/active5_app_bar.dart';
import '../../core/widgets/device_scaffold.dart';
import '../../shared/widgets/sentence_card.dart';

/// 선택한 언어·카테고리의 문장 목록.
class SentencesScreen extends ConsumerWidget {
  final String language;
  final String category;

  const SentencesScreen({
    super.key,
    required this.language,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);

    return DeviceScaffold(
      appBar: active5AppBar(
        context: context,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              languageLabel(language),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (state) {
          final sentences = state.bundle.sentencesFor(language, category);
          if (sentences.isEmpty) {
            return const Center(child: Text('문장이 없습니다.'));
          }
          return ListView.builder(
            padding: metrics.pagePadding.copyWith(top: 8),
            itemCount: sentences.length,
            itemBuilder: (context, index) =>
                SentenceCard(sentence: sentences[index]),
          );
        },
      ),
    );
  }
}
