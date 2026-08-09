import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/tts_service.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.stop);
  return service;
});

final ttsSpeakingProvider = NotifierProvider<TtsSpeakingController, bool>(
  TtsSpeakingController.new,
);

class TtsSpeakingController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> speakWord({
    required String word,
    required String language,
  }) async {
    final tts = ref.read(ttsServiceProvider);
    state = true;
    try {
      await tts.speak(word, language: language);
    } finally {
      state = false;
    }
  }
}
