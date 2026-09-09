import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Envuelve speech_to_text (motor de reconocimiento de voz nativo de
/// Android, gratis y sin usar las API keys de Gemini).
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;

  bool get isListening => _speech.isListening;

  /// Pide permiso de micrófono (si hace falta) e inicializa el motor.
  /// Devuelve false si el usuario no dio permiso o el dispositivo no
  /// soporta reconocimiento de voz.
  Future<bool> ensureReady() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    if (_ready) return true;
    _ready = await _speech.initialize(
      onError: (e) => _lastError = e.errorMsg,
      onStatus: (_) {},
    );
    return _ready;
  }

  String? _lastError;
  String? get lastError => _lastError;

  /// Escucha una sola intervención del usuario y devuelve el texto
  /// reconocido cuando termina de hablar (o al agotarse [timeout]).
  Future<String> listenOnce({
    Duration timeout = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final completer = Completer<String>();
    String best = '';

    void finish() {
      if (!completer.isCompleted) completer.complete(best);
    }

    await _speech.listen(
      onResult: (r) {
        best = r.recognizedWords;
        if (r.finalResult) finish();
      },
      listenFor: timeout,
      pauseFor: pauseFor,
      partialResults: true,
      cancelOnError: true,
    );

    // Red de seguridad por si nunca llega un resultado "final".
    Timer(timeout + const Duration(seconds: 2), finish);

    return completer.future;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
