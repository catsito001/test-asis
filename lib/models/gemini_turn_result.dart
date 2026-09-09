/// Representa la respuesta estructurada de Gemini para un turno de la
/// conversación de programación. Ver el "system instruction" en
/// GeminiService para el contrato exacto de este JSON.
class GeminiTurnResult {
  GeminiTurnResult({
    required this.intent,
    required this.status,
    this.title,
    this.dateTime,
    this.recurringDaily = false,
    this.missingField,
    this.question,
    this.confirmationMessage,
    required this.raw,
  });

  final String intent; // schedule | cancel | chitchat | unclear
  final String status; // needs_info | complete | rejected
  final String? title;
  final DateTime? dateTime;
  final bool recurringDaily;
  final String? missingField;
  final String? question;
  final String? confirmationMessage;

  /// El mapa original, para poder reenviarlo tal cual como turno "model"
  /// en el historial de la conversación.
  final Map<String, dynamic> raw;

  bool get needsInfo => status == 'needs_info';
  bool get isComplete => status == 'complete';

  factory GeminiTurnResult.fromJson(Map<String, dynamic> j) {
    DateTime? parsedDateTime;
    final date = j['date'] as String?;
    final time = j['time'] as String?;
    if (date != null && time != null) {
      try {
        final parts = time.split(':');
        final base = DateTime.parse(date);
        parsedDateTime = DateTime(
          base.year,
          base.month,
          base.day,
          int.parse(parts[0]),
          parts.length > 1 ? int.parse(parts[1]) : 0,
        );
      } catch (_) {
        parsedDateTime = null;
      }
    }
    return GeminiTurnResult(
      intent: j['intent'] as String? ?? 'unclear',
      status: j['status'] as String? ?? 'needs_info',
      title: j['title'] as String?,
      dateTime: parsedDateTime,
      recurringDaily: j['recurring'] as bool? ?? false,
      missingField: j['missing_field'] as String?,
      question: j['question'] as String?,
      confirmationMessage: j['confirmation_message'] as String?,
      raw: j,
    );
  }
}
