/// Constantes usadas en toda la app.
class AppConstants {
  AppConstants._();

  /// Modelo de Gemini usado para entender y programar. Se puede cambiar
  /// aquí sin tocar el resto del código si Google renombra/actualiza el
  /// modelo.
  static const String geminiModel = 'gemini-3.5-flash-lite';

  /// Model de respaldo para claves/proyectos donde el modelo principal no está disponible.
  static const String geminiFallbackModel = 'gemini-3.5-flash';

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';

  /// Cuántas claves de API como máximo puede guardar el usuario en Ajustes.
  static const int maxApiKeys = 3;

  static const String prefsEventsKey = 'asiste_events_v1';
  static const String secureKeyPrefix = 'asiste_gemini_key_';

  /// Si la alarma repite la frase en bucle hasta que el usuario toca
  /// "Aceptar" (true, valor por defecto) o la dice una sola vez y se
  /// queda esperando en silencio (false). Ajustable en Ajustes; no tiene
  /// nada que ver con "Repetir todos los días" (eso es por evento).
  static const String prefsLoopAlarmKey = 'asiste_loop_alarm_v1';

  static const String notificationChannelId = 'asiste_alarms_v2';
  static const String notificationChannelName = 'Alarmas y recordatorios';
  static const String notificationChannelDescription =
      'Avisos de las alarmas, eventos y recordatorios que programaste por voz';
}
