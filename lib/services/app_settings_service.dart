import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Ajustes globales simples (no secretos, a diferencia de las API keys
/// que maneja SecureSettingsService). Por ahora solo si la alarma debe
/// repetirse en bucle o decirse una sola vez.
class AppSettingsService {
  Future<bool> getLoopAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    // Por defecto en bucle: es el comportamiento que tenía la app antes
    // de que este ajuste existiera, así nadie pierde una alarma porque
    // se actualizó la app.
    return prefs.getBool(AppConstants.prefsLoopAlarmKey) ?? true;
  }

  Future<void> setLoopAlarm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsLoopAlarmKey, value);
  }
}
