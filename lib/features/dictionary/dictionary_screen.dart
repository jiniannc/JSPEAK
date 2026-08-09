import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/constants/labels.dart';
import '../../core/widgets/active5_app_bar.dart';
import '../../core/widgets/device_scaffold.dart';

/// 기내 사전 탭: 언어 선택 화면.
class DictionaryScreen extends ConsumerWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(contentProvider);
    final metrics = Active5Layout.of(context);

    return DeviceScaffold(
      appBar: active5AppBar(
        context: context,
        title: const Text(
          '기내 사전',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (state) {
          if (state.bundle.isEmpty) {
            return _EmptyView(
              syncError: state.syncError,
              onRetry: () => ref.read(contentProvider.notifier).sync(),
              syncing: state.syncing,
            );
          }
          final languages = state.bundle.languages;
          return RefreshIndicator(
            onRefresh: () => ref.read(contentProvider.notifier).sync(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: metrics.pagePadding.copyWith(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '학습할 언어를 선택하세요',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: metrics.isLandscape ? 20 : 16),
                  _LanguageSection(languages: languages, metrics: metrics),
                  if (state.syncError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '동기화 실패 (저장된 데이터로 표시 중)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
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

class _LanguageSection extends StatelessWidget {
  final List<String> languages;
  final Active5Metrics metrics;

  const _LanguageSection({
    required this.languages,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.isLandscape && languages.length <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < languages.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _LanguageTile(
                language: languages[i],
                metrics: metrics,
                compact: true,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (final lang in languages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LanguageTile(language: lang, metrics: metrics),
          ),
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String language;
  final Active5Metrics metrics;
  final bool compact;

  const _LanguageTile({
    required this.language,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(
          '/dictionary/language/${Uri.encodeComponent(language)}',
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 20,
            vertical: compact ? 12 : 20,
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      languageEmoji[language] ?? '🌐',
                      style: TextStyle(
                        fontSize: metrics.languageEmojiSize * 0.75,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      languageLabel(language),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: metrics.languageTitleSize - 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text(
                      languageEmoji[language] ?? '🌐',
                      style: TextStyle(fontSize: metrics.languageEmojiSize),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageLabel(language),
                            style: TextStyle(
                              fontSize: metrics.languageTitleSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            language,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 28),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String? syncError;
  final bool syncing;
  final VoidCallback onRetry;

  const _EmptyView({
    required this.syncError,
    required this.onRetry,
    required this.syncing,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_download_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              '콘텐츠가 아직 없습니다.\n네트워크 연결 후 동기화해 주세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (syncError != null) ...[
              const SizedBox(height: 8),
              Text(
                syncError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: syncing ? null : onRetry,
              icon: syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(syncing ? '동기화 중...' : '동기화'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '오류가 발생했습니다.\n$message',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
