import 'package:flutter_tts/flutter_tts.dart';

/// Envuelve flutter_tts (voz nativa del teléfono, gratis). Se usa tanto
/// para las preguntas de aclaración durante la conversación como para
/// leer la alarma en voz alta cuando suena.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  /// Habla [text] y espera a que termine de decirlo antes de continuar.
  Future<void> speakAndWait(String text) async {
    await _ensureInit();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
