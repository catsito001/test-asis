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
  ///
  /// [quickAnswer] cambia el modo de escucha: úsalo para preguntas de
  /// sí/no o de una sola palabra (ej. "¿todos los días?"), donde interesa
  /// que responda rápido apenas terminas de decir "sí" o "no". Para todo
  /// lo demás (la descripción inicial del evento, hora, fecha, título)
  /// deja el valor por defecto (false): usa el modo "dictation", pensado
  /// para frases más largas con pausas naturales al pensar, en vez del
  /// modo "confirmation" (el que traía la app antes), que está pensado
  /// para respuestas cortas y por eso cortaba la escucha muy rápido.
  ///
  /// Aviso honesto: en algunos Android/fabricantes (sobre todo Xiaomi),
  /// el motor de reconocimiento nativo tiene su propio límite de silencio
  /// interno que ignora lo que le pidamos desde Flutter — así lo advierte
  /// la propia documentación del paquete ("pauseFor... may be ignored on
  /// some devices"). Si eso pasa, no hay arreglo posible desde el código
  /// de la app; por eso el botón de micrófono también sirve para tocarlo
  /// de nuevo y decir "ya terminé" manualmente en cualquier momento.
  Future<String> listenOnce({
    bool quickAnswer = false,
    Duration? timeout,
    Duration? pauseFor,
  }) async {
    final effectiveTimeout =
        timeout ?? (quickAnswer ? const Duration(seconds: 12) : const Duration(seconds: 45));
    final effectivePauseFor =
        pauseFor ?? (quickAnswer ? const Duration(seconds: 2) : const Duration(seconds: 3));

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
      listenFor: effectiveTimeout,
      pauseFor: effectivePauseFor,
      partialResults: true,
      cancelOnError: true,
      listenMode: quickAnswer ? stt.ListenMode.confirmation : stt.ListenMode.dictation,
    );

    // Red de seguridad por si nunca llega un resultado "final".
    Timer(effectiveTimeout + const Duration(seconds: 2), finish);

    return completer.future;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
