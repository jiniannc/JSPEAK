import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/config/audio_playback_url.dart';

void main() {
  group('AudioPlaybackUrl.cacheKey', () {
    test('같은 Drive 파일이면 프록시 배포 URL이 달라도 키가 같다', () {
      const a = 'https://script.google.com/macros/s/OLD/exec?audio=FILE1';
      const b =
          'https://script.google.com/a/macros/jinair.com/s/NEW/exec?audio=FILE1';
      expect(AudioPlaybackUrl.cacheKey(a), AudioPlaybackUrl.cacheKey(b));
      expect(AudioPlaybackUrl.cacheKey(a), 'drive:FILE1');
    });

    test('Drive 직접 링크도 파일 ID로 키를 만든다', () {
      expect(
        AudioPlaybackUrl.cacheKey(
          'https://drive.usercontent.google.com/download?id=FILE2&export=download',
        ),
        'drive:FILE2',
      );
    });

    test('일반 URL은 그대로 쓴다', () {
      const url = 'https://example.com/a.mp3';
      expect(AudioPlaybackUrl.cacheKey(url), url);
      expect(AudioPlaybackUrl.driveFileIdOf(url), isNull);
    });

    test('프록시 URL에서 Drive 직접 다운로드 URL을 만든다', () {
      final id = AudioPlaybackUrl.driveFileIdOf(
        'https://script.google.com/macros/s/X/exec?audio=FILE3',
      );
      expect(id, 'FILE3');
      expect(
        AudioPlaybackUrl.directDriveUrl(id!),
        'https://drive.usercontent.google.com/download?id=FILE3&export=download',
      );
    });
  });
}
