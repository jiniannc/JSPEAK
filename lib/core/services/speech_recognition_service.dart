import 'package:flutter/foundation.dart' show debugPrint;

import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:speech_to_text/speech_to_text.dart';



/// speech_to_text 패키지 래퍼.

class SpeechRecognitionService {

  final SpeechToText _speech = SpeechToText();



  bool _initialized = false;

  void Function(String status)? _onStatus;



  bool get isInitialized => _initialized;



  bool get isListening => _speech.isListening;



  bool get isAvailable => _speech.isAvailable;



  Future<bool> initialize({void Function(String status)? onStatus}) async {

    if (onStatus != null) {

      _onStatus = onStatus;

    }

    if (_initialized) return _speech.isAvailable;



    _initialized = await _speech.initialize(

      onError: (error) => debugPrint('STT 오류: ${error.errorMsg}'),

      onStatus: (status) {

        debugPrint('STT 상태: $status');

        _onStatus?.call(status);

      },

    );

    return _initialized && _speech.isAvailable;

  }



  void changePauseFor(Duration pauseFor) {

    if (!_initialized) return;

    _speech.changePauseFor(pauseFor);

  }



  Future<void> startListening({

    required String localeId,

    required void Function(String text, {required bool isFinal}) onResult,

    void Function(double level)? onSoundLevelChange,

    Duration listenFor = const Duration(seconds: 30),

    Duration? pauseFor,

  }) async {

    if (!_initialized) {

      final ok = await initialize();

      if (!ok) return;

    }



    await _speech.listen(

      onResult: (SpeechRecognitionResult result) {

        onResult(result.recognizedWords, isFinal: result.finalResult);

      },

      onSoundLevelChange: onSoundLevelChange,

      listenOptions: SpeechListenOptions(

        localeId: localeId,

        listenFor: listenFor,

        pauseFor: pauseFor,

        partialResults: true,

      ),

    );

  }



  Future<void> stopListening() => _speech.stop();



  Future<void> cancelListening() => _speech.cancel();

}

