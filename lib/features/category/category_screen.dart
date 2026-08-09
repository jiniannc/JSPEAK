import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/widgets/active5_app_bar.dart';
import '../../core/widgets/device_scaffold.dart';

/// 선택한 언어의 카테고리 목록 (시트 등장 순서 유지).
class CategoryScreen extends ConsumerWidget {
  final String language;

  const CategoryScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);

    return DeviceScaffold(
      appBar: active5AppBar(
        context: context,
        title: Text(
          languageLabel(language),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          Active5IconButton(
            icon: Icons.search,
            tooltip: '검색',
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (state) {
          final categories = state.bundle.categoriesFor(language);
          if (categories.isEmpty) {
            return const Center(child: Text('이 언어의 콘텐츠가 없습니다.'));
          }
          return GridView.builder(
            padding: metrics.pagePadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: metrics.categoryColumns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final count =
                  state.bundle.sentencesFor(language, category).length;
              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(
                    '/dictionary/language/${Uri.encodeComponent(language)}'
                    '/category/${Uri.encodeComponent(category)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          categoryIcon(category),
                          size: metrics.isLandscape ? 40 : 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          category,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$count문장',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
