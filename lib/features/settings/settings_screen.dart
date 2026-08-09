import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/config/active5_layout.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/active5_app_bar.dart';
import '../../core/widgets/device_scaffold.dart';

/// 설정: 콘텐츠 동기화, 오디오 전체 다운로드, 캐시 관리.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _prefetching = false;
  int _prefetchDone = 0;
  int _prefetchTotal = 0;
  int? _cacheSizeBytes;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size =
        await ref.read(contentRepositoryProvider).audioCacheSizeBytes();
    if (mounted) setState(() => _cacheSizeBytes = size);
  }

  Future<void> _prefetchAudio() async {
    final state = ref.read(contentProvider).value;
    if (state == null || state.bundle.isEmpty || _prefetching) return;

    setState(() {
      _prefetching = true;
      _prefetchDone = 0;
      _prefetchTotal = 0;
    });
    final succeeded =
        await ref.read(contentRepositoryProvider).prefetchAllAudio(
      state.bundle,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _prefetchDone = done;
            _prefetchTotal = total;
          });
        }
      },
    );
    if (!mounted) return;
    setState(() => _prefetching = false);
    await _refreshCacheSize();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오디오 $succeeded / $_prefetchTotal개 다운로드 완료')),
    );
  }

  Future<void> _clearCache() async {
    await ref.read(contentRepositoryProvider).clearAudioCache();
    await _refreshCacheSize();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('오디오 캐시를 삭제했습니다.')));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final contentState = ref.watch(contentProvider).value;
    final syncedAt = contentState?.lastSyncedAt;
    final syncing = contentState?.syncing ?? false;

    final metrics = Active5Layout.of(context);

    return DeviceScaffold(
      appBar: active5AppBar(
        context: context,
        title: const Text(
          '설정',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: metrics.pagePadding.copyWith(top: 0),
        children: [
          const _SectionHeader('콘텐츠'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: const Icon(Icons.sync, size: 28),
            title: const Text('지금 동기화', style: TextStyle(fontSize: 17)),
            subtitle: Text(
              syncedAt != null
                  ? '마지막 동기화: ${DateFormat('yyyy-MM-dd HH:mm').format(syncedAt)}'
                  : '아직 동기화하지 않았습니다',
            ),
            trailing: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: syncing
                ? null
                : () => ref.read(contentProvider.notifier).sync(),
          ),
          if (contentState?.syncError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                contentState!.syncError!,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: const Icon(Icons.article_outlined, size: 28),
            title: const Text('문장 수', style: TextStyle(fontSize: 17)),
            subtitle: Text('${contentState?.bundle.sentences.length ?? 0}개'),
          ),
          const Divider(),
          const _SectionHeader('오프라인 오디오'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: const Icon(Icons.download_outlined, size: 28),
            title: const Text('오디오 전체 다운로드', style: TextStyle(fontSize: 17)),
            subtitle: Text(
              _prefetching
                  ? '다운로드 중... $_prefetchDone / $_prefetchTotal'
                  : '비행 전 미리 받아두면 오프라인에서 재생됩니다',
            ),
            trailing: _prefetching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _prefetching ? null : _prefetchAudio,
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: const Icon(Icons.storage_outlined, size: 28),
            title: const Text('캐시 용량', style: TextStyle(fontSize: 17)),
            subtitle: Text(
              _cacheSizeBytes != null
                  ? _formatBytes(_cacheSizeBytes!)
                  : '계산 중...',
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: const Icon(Icons.delete_outline, size: 28),
            title: const Text('오디오 캐시 삭제', style: TextStyle(fontSize: 17)),
            onTap: _clearCache,
          ),
          const Divider(),
          const _SectionHeader('정보'),
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            minVerticalPadding: 12,
            leading: Icon(Icons.info_outline, size: 28),
            title: Text(AppConfig.appName, style: TextStyle(fontSize: 17)),
            subtitle: Text('${AppConfig.appSubtitle}\n최적화: ${Active5Layout.deviceName}'),
          ),
          if (!AppConfig.isConfigured)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'CONTENT_URL이 설정되지 않은 빌드입니다.\n'
                'flutter run --dart-define=CONTENT_URL=... 으로 실행하세요.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
