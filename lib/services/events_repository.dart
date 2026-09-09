import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asiste_event.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

/// Fuente única de verdad para los eventos/alarmas de la app. Guarda todo
/// en SharedPreferences como JSON (nada de esto es sensible, a diferencia
/// de las API keys) y avisa a la UI (Provider) cuando algo cambia.
class EventsRepository extends ChangeNotifier {
  List<AsisteEvent> _events = [];

  List<AsisteEvent> get events => List.unmodifiable(_events);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(AppConstants.prefsEventsKey) ?? [];
    _events = raw
        .map((s) => AsisteEvent.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      AppConstants.prefsEventsKey,
      _events.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> addEvent(AsisteEvent event) async {
    _events.add(event);
    await _persist();
    notifyListeners();
  }

  Future<void> updateEvent(AsisteEvent event) async {
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i != -1) {
      _events[i] = event;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
    await NotificationService.instance.cancelForEventId(id);
  }

  AsisteEvent? byId(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Eventos que ocurren en [day], ordenados por hora. Usado tanto por el
  /// calendario (para resaltar el día) como por la lista debajo de él.
  List<AsisteEvent> eventsOn(DateTime day) {
    final list = _events.where((e) => e.occursOn(day)).toList();
    list.sort((a, b) {
      final am = a.dateTime.hour * 60 + a.dateTime.minute;
      final bm = b.dateTime.hour * 60 + b.dateTime.minute;
      return am - bm;
    });
    return list;
  }
}
