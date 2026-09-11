import 'dart:async';

import 'package:flutter/services.dart';

/// Puente hacia el motor nativo de detección de "Alexa" (openWakeWord),
/// que vive en MainActivity.kt. Ver ese archivo para el detalle de qué
/// corre del lado nativo y por qué (Fase 1a: solo mientras la app está
/// abierta, todavía sin servicio en segundo plano).
class WakeWordService {
  WakeWordService._internal() {
    _channel.setMethodCallHandler(_onMethodCall);
  }
  static final WakeWordService instance = WakeWordService._internal();
  factory WakeWordService() => instance;

  static const MethodChannel _channel = MethodChannel('asiste/wakeword');
  final StreamController<void> _detectedController =
      StreamController<void>.broadcast();

  /// Emite un evento cada vez que el motor nativo escucha "Alexa".
  Stream<void> get onDetected => _detectedController.stream;

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onWakeWordDetected') {
      _detectedController.add(null);
    }
  }

  /// Arranca el motor. Debe llamarse solo después de confirmar el permiso
  /// de micrófono, y NUNCA al mismo tiempo que speech_to_text está
  /// escuchando (Android solo permite un AudioRecord activo a la vez).
  Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } catch (_) {
      // Si el canal falla (por ejemplo, plataforma no soportada), la app
      // sigue funcionando normal, solo sin la palabra de activación.
    }
  }

  /// Detiene el motor y libera el micrófono.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
