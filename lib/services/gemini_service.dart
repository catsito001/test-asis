import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gemini_turn_result.dart';
import '../utils/constants.dart';
import 'secure_settings_service.dart';

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _QuotaExceededException implements Exception {}

/// Un turno de la conversación de voz: quién habló ('user' o 'model') y
/// qué dijo (texto reconocido, o el JSON crudo que devolvió el modelo).
class ConversationTurn {
  ConversationTurn(this.role, this.text);
  final String role;
  final String text;
}

/// Entiende lo que el usuario quiere programar y va completando los datos
/// que faltan, turno a turno. Rota automáticamente entre las API keys
/// guardadas en Ajustes cuando una de ellas se queda sin cuota gratuita.
class GeminiService {
  GeminiService(this._settings);
  final SecureSettingsService _settings;

  int _lastGoodKeyIndex = 0;

  String _systemInstruction(DateTime now) {
    final iso = now.toIso8601String();
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    final weekday = weekdays[now.weekday - 1];
    return '''
Eres el motor de comprensión de "Asiste", un asistente de voz en español que
programa alarmas, eventos, recordatorios y reuniones a partir de lo que dice
el usuario.

Debes responder SIEMPRE con un único objeto JSON válido, sin texto adicional,
sin explicaciones y sin bloques de markdown, con exactamente esta forma:

{
  "intent": "schedule" | "chitchat" | "unclear",
  "status": "needs_info" | "complete" | "rejected",
  "title": string o null,
  "date": "YYYY-MM-DD" o null,
  "time": "HH:mm" (24 horas) o null,
  "recurring": true o false,
  "missing_field": "title" | "date" | "time" | "recurring" | null,
  "question": string o null,
  "confirmation_message": string o null
}

Contexto actual: hoy es $weekday, la fecha y hora exacta ahora mismo es $iso
(zona horaria del dispositivo). Usa este dato para resolver expresiones
relativas como "mañana", "el viernes que viene", "en dos horas", "a las 8
de la noche", etc., y conviértelas siempre a "date" y "time" absolutos.

Reglas:
- Si falta un dato imprescindible ("title", "date" o "time"), pon
  "status":"needs_info", indica cuál falta en "missing_field" y en
  "question" formula UNA sola pregunta corta y natural en español para
  pedir ese dato (nada de tecnicismos).
- Antes de dar el evento por completo, pregunta una sola vez si se debe
  repetir todos los días ("recurring"). Si el usuario dice que no, o
  cualquier negativa ("no", "no hace falta", "no es necesario", "da
  igual", "solo por hoy"), usa "recurring": false y continúa sin volver
  a preguntar por ese ni ningún otro campo opcional.
- En cuanto tengas "title", "date" y "time", y ya se resolvió
  "recurring" (aunque sea con el valor por defecto false), responde
  "status":"complete" y escribe en "confirmation_message" una frase
  breve y natural confirmando lo programado, mencionando día, hora y si
  se repite a diario.
- Si el usuario solo está conversando y no pide programar nada, usa
  "intent":"chitchat" y "status":"complete", y responde brevemente en
  "confirmation_message".
- Si no entiendes lo que quiere el usuario, usa "intent":"unclear",
  "status":"needs_info", "missing_field": null y en "question" pide que
  repita o aclare.
- No inventes datos: si un dato no te lo dieron ni se puede deducir del
  contexto, pídelo. Nunca dejes "title" vacío para un evento a programar.
''';
  }

  /// Envía todo el historial de la conversación (incluye el último turno
  /// del usuario) y devuelve la respuesta ya parseada. Prueba las claves
  /// guardadas en orden hasta que una funcione.
  Future<GeminiTurnResult> sendTurn(List<ConversationTurn> history) async {
    final keys = await _settings.getAllKeys();
    if (keys.isEmpty) {
      throw GeminiException(
        'No configuraste ninguna clave de API. Ábreme en Ajustes y pega al menos una.',
      );
    }

    final now = DateTime.now();
    for (int offset = 0; offset < keys.length; offset++) {
      final idx = (_lastGoodKeyIndex + offset) % keys.length;
      try {
        final result = await _callOnce(keys[idx], history, now);
        _lastGoodKeyIndex = idx;
        return result;
      } on _QuotaExceededException {
        continue; // esta clave se quedó sin cuota: prueba la siguiente
      }
    }
    throw GeminiException(
      'Tus ${keys.length} clave(s) de API llegaron a su límite gratuito por ahora. '
      'Intenta de nuevo más tarde o agrega otra clave en Ajustes.',
    );
  }

  Future<GeminiTurnResult> _callOnce(
    String apiKey,
    List<ConversationTurn> history,
    DateTime now,
  ) async {
    final body = {
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction(now)}
        ]
      },
      'contents': history
          .map((t) => {
                'role': t.role,
                'parts': [
                  {'text': t.text}
                ]
              })
          .toList(),
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    };

    Future<http.Response> postTo(String model) async {
      final baseUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
      final uri = Uri.parse('$baseUrl?key=${Uri.encodeQueryComponent(apiKey)}');
      return http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    }

    http.Response resp;
    try {
      resp = await postTo(AppConstants.geminiModel);

      // 404 suele significar que el modelo no está habilitado/disponible
      // para esa clave o proyecto. Probamos un modelo compatible de respaldo
      // antes de mostrar el error al usuario.
      if (resp.statusCode == 404 &&
          AppConstants.geminiFallbackModel != AppConstants.geminiModel) {
        resp = await postTo(AppConstants.geminiFallbackModel);
      }
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw GeminiException(
        'No pude conectarme a internet para entender el pedido.',
      );
    }

    if (resp.statusCode == 429 || resp.statusCode == 403) {
      throw _QuotaExceededException();
    }
    if (resp.statusCode == 401) {
      throw GeminiException(
        'La clave de Gemini no es válida o fue revocada. Genera otra en AI Studio y guárdala de nuevo en Ajustes.',
      );
    }
    if (resp.statusCode != 200) {
      String detail = '';
      try {
        final errorJson = jsonDecode(utf8.decode(resp.bodyBytes));
        final msg = errorJson['error']?['message'];
        if (msg is String && msg.isNotEmpty) detail = ' $msg';
      } catch (_) {}
      throw GeminiException(
        'Gemini respondió con un error (${resp.statusCode}).$detail',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw GeminiException('No pude leer la respuesta de Gemini.');
    }

    final candidates = decoded['candidates'] as List?;
    final text = candidates != null && candidates.isNotEmpty
        ? (candidates[0]?['content']?['parts']?[0]?['text'] as String?)
        : null;
    if (text == null || text.trim().isEmpty) {
      throw GeminiException('Gemini devolvió una respuesta vacía.');
    }

    try {
      final parsed = jsonDecode(_stripFences(text)) as Map<String, dynamic>;
      return GeminiTurnResult.fromJson(parsed);
    } catch (_) {
      throw GeminiException('No entendí la respuesta de Gemini, intenta de nuevo.');
    }
  }

  String _stripFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
    }
    return t.trim();
  }
}
