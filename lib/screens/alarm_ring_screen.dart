import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/events_repository.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Se abre encima de la pantalla de bloqueo (ver showWhenLocked/turnScreenOn
/// y fullScreenIntent) cuando suena una alarma. Repite el texto del evento
/// en voz alta hasta que el usuario toca "Aceptar".
class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  final TtsService _tts = TtsService();
  bool _dismissed = false;
  String _title = 'Tienes un aviso pendiente';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final repo = context.read<EventsRepository>();
    final event = repo.byId(widget.eventId);
    _title = event?.title ?? _title;
    _speakLoop();
  }

  Future<void> _speakLoop() async {
    while (!_dismissed && mounted) {
      await _tts.speakAndWait('Alarma. $_title');
      if (_dismissed || !mounted) break;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<void> _accept() async {
    setState(() => _dismissed = true);
    await _tts.stop();
    await NotificationService.instance.cancelForEventId(widget.eventId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _snooze() async {
    setState(() => _dismissed = true);
    await _tts.stop();
    await NotificationService.instance.cancelForEventId(widget.eventId);
    await NotificationService.instance.scheduleSnooze(
      eventId: widget.eventId,
      title: _title,
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _dismissed = true;
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm_rounded, size: 84, color: AppTheme.accent),
                const SizedBox(height: 24),
                const Text(
                  'Asiste',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _accept,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _snooze,
                    child: const Text('Posponer 5 minutos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
