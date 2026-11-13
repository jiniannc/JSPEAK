import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_log.dart';
import '../data/datasources/local/voice_preference_local_datasource.dart';
import '../data/models/sentence.dart';

final voicePreferenceLocalDataSourceProvider =
    Provider<VoicePreferenceLocalDataSource>(
  (ref) => VoicePreferenceLocalDataSource(),
);

/// 문장 스피킹 모드 재생 음성 — 기본 여자, 선택값은 로컬에 저장된다.
final sentenceVoiceProvider =
    NotifierProvider<SentenceVoiceController, VoiceGender>(
  SentenceVoiceController.new,
);

class SentenceVoiceController extends Notifier<VoiceGender> {
  bool _userChanged = false;

  @override
  VoiceGender build() {
    unawaited(_restore());
    return VoiceGender.female;
  }

  Future<void> _restore() async {
    try {
      final saved =
          await ref.read(voicePreferenceLocalDataSourceProvider).loadSentenceVoice();
      if (!ref.mounted || _userChanged) return;
      state = saved;
    } catch (e, st) {
      AppLog.debug('voice_pref', '음성 설정 불러오기 실패', e, st);
    }
  }

  void select(VoiceGender voice) {
    _userChanged = true;
    if (state == voice) return;
    state = voice;
    unawaited(
      ref
          .read(voicePreferenceLocalDataSourceProvider)
          .saveSentenceVoice(voice)
          .catchError((Object e, StackTrace st) {
        AppLog.debug('voice_pref', '음성 설정 저장 실패', e, st);
      }),
    );
  }
}
