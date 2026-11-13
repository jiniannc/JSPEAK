import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/content_sync_status.dart';

/// 홈 등 — 동기화 실패·오래된 로컬 데이터를 사용자에게 알린다.
class ContentSyncStatusBanner extends ConsumerWidget {
  const ContentSyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider).value;
    if (content == null) return const SizedBox.shrink();

    if (content.syncing) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _SyncBannerShell(
          icon: Icons.cloud_sync_outlined,
          tone: _SyncBannerTone.info,
          title: '콘텐츠 동기화 중…',
          subtitle: '최신 기내 표현 데이터를 확인하고 있습니다.',
        ),
      );
    }

    final error = content.syncError;
    if (error != null && error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SyncBannerShell(
          icon: Icons.cloud_off_outlined,
          tone: _SyncBannerTone.error,
          title: '최신 콘텐츠를 가져오지 못했습니다',
          subtitle: error,
          actionLabel: '다시 시도',
          onAction: () => ref.read(contentProvider.notifier).sync(),
        ),
      );
    }

    if (isContentSyncStale(content.lastSyncedAt)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SyncBannerShell(
          icon: Icons.schedule_outlined,
          tone: _SyncBannerTone.warning,
          title: '로컬 데이터가 오래되었을 수 있습니다',
          subtitle: formatLastContentSync(content.lastSyncedAt),
          actionLabel: '동기화',
          onAction: () => ref.read(contentProvider.notifier).sync(),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

enum _SyncBannerTone { info, warning, error }

class _SyncBannerShell extends StatelessWidget {
  const _SyncBannerShell({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final _SyncBannerTone tone;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (tone) {
      _SyncBannerTone.info => (
          scheme.primaryContainer.withValues(alpha: 0.55),
          scheme.onPrimaryContainer,
        ),
      _SyncBannerTone.warning => (
          scheme.tertiaryContainer.withValues(alpha: 0.65),
          scheme.onTertiaryContainer,
        ),
      _SyncBannerTone.error => (
          scheme.errorContainer.withValues(alpha: 0.75),
          scheme.onErrorContainer,
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: fg.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
