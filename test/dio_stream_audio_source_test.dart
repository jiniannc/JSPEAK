import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/services/dio_stream_audio_source.dart';

void main() {
  group('resolveStreamAudioSlice (end exclusive)', () {
    final bytes = Uint8List.fromList(List<int>.generate(100, (i) => i));

    test('전체 요청 (start/end null)', () {
      final r = resolveStreamAudioSlice(bytes, null, null);
      expect(r.from, 0);
      expect(r.to, 100);
      expect(r.slice, bytes);
    });

    test('ExoPlayer 기본 요청 bytes=0- → start=0, end=null', () {
      final r = resolveStreamAudioSlice(bytes, 0, null);
      expect(r.from, 0);
      expect(r.to, 100);
      expect(r.slice.length, 100);
    });

    test('bytes=0-15 → end=16 (exclusive)', () {
      final r = resolveStreamAudioSlice(bytes, 0, 16);
      expect(r.slice, bytes.sublist(0, 16));
    });

    test('중간 range', () {
      final r = resolveStreamAudioSlice(bytes, 40, 60);
      expect(r.from, 40);
      expect(r.slice, bytes.sublist(40, 60));
    });

    test('빈 바이트', () {
      final r = resolveStreamAudioSlice(Uint8List(0), 0, 10);
      expect(r.slice, isEmpty);
    });

    test('범위가 파일 길이를 넘어도 clamp', () {
      final r = resolveStreamAudioSlice(bytes, 90, 999);
      expect(r.from, 90);
      expect(r.to, 100);
    });
  });
}
