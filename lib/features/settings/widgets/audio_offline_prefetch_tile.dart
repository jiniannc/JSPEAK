import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/utils/content_sync_status.dart';

/// 설정 — 오프라인용 문장 오디오 전체 다운로드 (자동·수동 공통 진행 표시).
class AudioOfflinePrefetchTile extends ConsumerWidget {
  const AudioOfflinePrefetchTile({
    super.key,
    required this.onManualPrefetch,
    required this.onPrefetchFinished,
  });

  final VoidCallback onManualPrefetch;
  final VoidCallback onPrefetchFinished;

  static final _timeFormat = DateFormat('M월 d일 HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(audioOfflinePrefetchProvider);

    ref.listen(audioOfflinePrefetchProvider, (previous, next) {
      final wasRunning = previous?.running ?? false;
      if (wasRunning && !next.running) {
        onPrefetchFinished();
      }
    });

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      minVerticalPadding: 12,
      isThreeLine: offline.running && offline.total > 0,
      leading: const Icon(Icons.download_outlined, size: 28),
      title: const Text('오디오 전체 다운로드', style: TextStyle(fontSize: 17)),
      subtitle: _buildSubtitle(context, offline),
      trailing: offline.running
          ? SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      value: offline.total > 0 ? offline.progress : null,
                    ),
                  ),
                  if (offline.total > 0)
                    Text(
                      '${(offline.progress * 100).round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.38),
            ),
      onTap: offline.running || kIsWeb ? null : onManualPrefetch,
    );
  }

  Widget _buildSubtitle(BuildContext context, AudioOfflinePrefetchState offline) {
    if (kIsWeb) {
      return const Text(
        '웹에서는 디스크에 저장하지 않습니다. APK에서 자동·수동 다운로드를 이용하세요.',
        style: TextStyle(fontSize: 13),
      );
    }

    if (offline.running) {
      final phase = offline.total > 0
          ? '백그라운드 다운로드 중 · ${offline.done} / ${offline.total}개'
          : '다운로드 목록을 준비하는 중...';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(phase, style: const TextStyle(fontSize: 13)),
          if (offline.total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: offline.progress,
              ),
            ),
          ],
        ],
      );
    }

    if (offline.lastCompletedAt != null && offline.total > 0) {
      final at = _timeFormat.format(offline.lastCompletedAt!.toLocal());
      return Text(
        '마지막 완료: $at · ${offline.lastSucceeded}/${offline.total}개 저장\n'
        '앱 실행·동기화 시 네트워크가 있으면 자동으로 이어 받습니다',
        style: const TextStyle(fontSize: 13, height: 1.35),
      );
    }

    if (offline.lastCompletedAt != null) {
      return Text(
        '마지막 시도: ${formatLastContentSync(offline.lastCompletedAt)}',
        style: const TextStyle(fontSize: 13),
      );
    }

    return const Text(
      '앱 실행·콘텐츠 동기화 후 Wi‑Fi/데이터가 있으면 자동으로 받습니다.\n'
      '진행 상황은 이 항목에서 확인할 수 있습니다.',
      style: TextStyle(fontSize: 13, height: 1.35),
    );
  }
}
