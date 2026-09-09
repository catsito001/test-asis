import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/asiste_event.dart';
import '../utils/constants.dart';

/// Programa las alarmas como notificaciones exactas de Android.
/// El disparo ocurre en segundo plano mediante AlarmManager; no depende
/// de que el proceso Flutter siga abierto.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _tappedController =
      StreamController<String>.broadcast();

  Stream<String> get onAlarmTapped => _tappedController.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    tzdata.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo));
    } catch (_) {
      // Si no se puede detectar la zona, se conserva la zona local de tz.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tappedController.add(payload);
        }
      },
    );

    // v2: un canal nuevo evita que Android conserve la configuración
    // silenciosa del canal viejo, ya que el sonido de un channel no puede
    // cambiarse una vez creado.
    const channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await _android?.createNotificationChannel(channel);
  }

  /// Solicita los permisos necesarios para que la alarma pueda aparecer
  /// incluso con pantalla bloqueada.
  Future<bool> requestPermissions() async {
    final android = _android;

    final notifications =
        await android?.requestNotificationsPermission() ?? true;
    final exact = await android?.requestExactAlarmsPermission() ?? true;
    final fullScreen =
        await android?.requestFullScreenIntentPermission() ?? true;

    return notifications && exact && fullScreen;
  }

  Future<bool> areNotificationsEnabled() async {
    return await _android?.areNotificationsEnabled() ?? true;
  }

  /// Estado real del permiso especial "Alarmas y recordatorios"
  /// (SCHEDULE_EXACT_ALARM). Ojo: esto NO es lo mismo que la
  /// configuración del canal de notificaciones, aunque ambos compartan
  /// el mismo nombre visible en pantalla.
  Future<bool> canScheduleExactAlarms() async {
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> openExactAlarmSettings() async {
    await _android?.requestExactAlarmsPermission();
  }

  Future<NotificationAppLaunchDetails?> appLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  NotificationDetails _alarmDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        category: AndroidNotificationCategory.alarm,
        priority: Priority.max,
        importance: Importance.max,
        fullScreenIntent: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  tz.TZDateTime _asLocalTzDateTime(DateTime value) {
    // Conserva exactamente la hora de pared elegida por el usuario.
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }

  Future<void> scheduleForEvent(AsisteEvent event) async {
    // Al editar una alarma, elimina primero la anterior.
    await cancelForEventId(event.id);

    final now = tz.TZDateTime.now(tz.local);
    var effective = _asLocalTzDateTime(event.dateTime);

    // Una alarma puntual que ya pasó se interpreta como mañana, igual que
    // el comportamiento esperado al programarla manualmente.
    if (effective.isBefore(now) && !event.recurringDaily) {
      effective = effective.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      event.notificationId,
      'Asiste',
      event.title,
      effective,
      _alarmDetails(),
      // Para una app que funciona como alarma, alarmClock es la variante
      // apropiada: exacta y capaz de ejecutarse en modo de bajo consumo.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          event.recurringDaily ? DateTimeComponents.time : null,
      payload: event.id,
    );

    // No usamos pendingNotificationRequests() como prueba de éxito:
    // Android/AlarmManager puede aceptar la alarma aunque esa consulta no
    // refleje inmediatamente la programación del receiver. Si zonedSchedule
    // termina sin excepción, consideramos que la programación fue aceptada.
  }

  Future<void> cancelForEventId(String id) async {
    await _plugin.cancel(id.hashCode & 0x7fffffff);
  }

  Future<void> scheduleSnooze({
    required String eventId,
    required String title,
    Duration delay = const Duration(minutes: 5),
  }) async {
    final when = tz.TZDateTime.now(tz.local).add(delay);

    await _plugin.zonedSchedule(
      (('$eventId-snooze').hashCode) & 0x7fffffff,
      'Asiste',
      title,
      when,
      _alarmDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: eventId,
    );
  }

  /// Útil para probar el sistema de alarmas sin tener que esperar a una
  /// hora concreta.
  Future<void> scheduleTestAlarm({
    Duration delay = const Duration(seconds: 10),
  }) async {
    final when = tz.TZDateTime.now(tz.local).add(delay);
    const testId = 2147483000;

    await _plugin.zonedSchedule(
      testId,
      'Asiste — prueba de alarma',
      'La alarma funciona correctamente.',
      when,
      _alarmDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '__test_alarm__',
    );
  }
}
