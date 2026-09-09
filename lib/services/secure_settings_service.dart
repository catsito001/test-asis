import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';

/// Guarda y lee las claves de API de Gemini de forma cifrada en el
/// dispositivo (nunca en texto plano, nunca en la nube).
class SecureSettingsService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _keyName(int slot) => '${AppConstants.secureKeyPrefix}$slot';

  /// Lee la clave guardada en la posición [slot] (1, 2 o 3).
  Future<String?> getKey(int slot) => _storage.read(key: _keyName(slot));

  Future<void> setKey(int slot, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _storage.delete(key: _keyName(slot));
    }
    return _storage.write(key: _keyName(slot), value: trimmed);
  }

  Future<void> clearKey(int slot) => _storage.delete(key: _keyName(slot));

  /// Todas las claves configuradas y no vacías, en orden 1 → 3.
  /// GeminiService usa esta lista para ir rotando cuando una se queda
  /// sin créditos.
  Future<List<String>> getAllKeys() async {
    final List<String> keys = [];
    for (int i = 1; i <= AppConstants.maxApiKeys; i++) {
      final v = await getKey(i);
      if (v != null && v.trim().isNotEmpty) keys.add(v.trim());
    }
    return keys;
  }

  Future<bool> hasAnyKey() async => (await getAllKeys()).isNotEmpty;
}
