/// Un evento/alarma/recordatorio programado por el usuario (por voz o a mano).
class AsisteEvent {
  AsisteEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.recurringDaily = false,
  });

  final String id;
  String title;
  DateTime dateTime;
  bool recurringDaily;

  /// flutter_local_notifications necesita un id numérico estable por evento.
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Si este evento suena/aparece en [day] (respetando la repetición diaria).
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (recurringDaily) return !d.isBefore(start);
    return d == start;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'recurringDaily': recurringDaily,
      };

  factory AsisteEvent.fromJson(Map<String, dynamic> j) => AsisteEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        dateTime: DateTime.parse(j['dateTime'] as String),
        recurringDaily: j['recurringDaily'] as bool? ?? false,
      );
}
