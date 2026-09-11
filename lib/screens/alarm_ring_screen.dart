import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_settings_service.dart';
import '../services/events_repository.dart';
import '../services/notification_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Se abre encima de la pantalla de bloqueo (ver showWhenLocked/turnScreenOn
/// y fullScreenIntent) cuando suena una alarma. Repite el texto del evento
/// en voz alta hasta que el usuario toca "Aceptar" —o lo dice una sola vez,
/// según "Repetir la alarma en bucle" de Ajustes— y, si "Apagar diciendo
/// ok" está activo, también escucha por el micrófono para apagarla por voz.
class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key, required this.eventId});
  final String eventId;

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  // Palabras que, si aparecen sueltas (como palabra completa, no como
  // parte de otra) en lo que la app entendió, apagan la alarma. Se busca
  // como palabra completa con \b para no dispararse con una palabra al
  // azar mal transcrita que solo contenga esas letras por casualidad.
  static final RegExp _dismissPattern = RegExp(
    r'\b(ok|okay|okey|oki|vale|aceptar|listo)\b',
    caseSensitive: false,
  );

  final TtsService _tts = TtsService();
  final SpeechService _speech = SpeechService();
  final AppSettingsService _appSettings = AppSettingsService();
  bool _dismissed = false;
  bool _listeningForVoice = false;
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
    final loop = await _appSettings.getLoopAlarm();
    final voiceDismiss = await _appSettings.getVoiceDismiss();
    if (_dismissed || !mounted) return;

    final phrase = voiceDismiss
        ? 'Alarma. $_title. Di ok para apagarla.'
        : 'Alarma. $_title';

    if (!loop) {
      // Modo "una sola vez": la dice, y si el micrófono por voz está
      // activo, se queda escuchando en silencio (sin repetir el aviso)
      // hasta que digas "ok" o toques Aceptar.
      await _tts.speakAndWait(phrase);
      if (_dismissed || !mounted) return;
      if (voiceDismiss) await _listenUntilDismissedOrCancelled();
      return;
    }

    while (!_dismissed && mounted) {
      await _tts.speakAndWait(phrase);
      if (_dismissed || !mounted) break;

      if (voiceDismiss) {
        final heard = await _listenForDismissWord();
        if (heard || _dismissed || !mounted) break;
      } else {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  /// Escucha repetidamente (sin volver a hablar) hasta que se detecte la
  /// palabra de apagado o el usuario toque un botón en pantalla.
  Future<void> _listenUntilDismissedOrCancelled() async {
    while (!_dismissed && mounted) {
      final heard = await _listenForDismissWord();
      if (heard) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  /// Una sola pasada de escucha. Devuelve true si detectó la palabra de
  /// apagado (y ya llamó a [_accept] por dentro).
  Future<bool> _listenForDismissWord() async {
    if (_dismissed || !mounted) return false;
    final ready = await _speech.ensureReady();
    if (!ready || _dismissed || !mounted) return false;

    setState(() => _listeningForVoice = true);
    final text = await _speech.listenOnce(quickAnswer: true);
    if (!mounted) return false;
    setState(() => _listeningForVoice = false);

    if (_dismissed) return false;
    if (_dismissPattern.hasMatch(text)) {
      await _accept();
      return true;
    }
    return false;
  }

  Future<void> _accept() async {
    setState(() {
      _dismissed = true;
      _listeningForVoice = false;
    });
    await _tts.stop();
    await _speech.cancel();
    await NotificationService.instance.cancelForEventId(widget.eventId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _snooze() async {
    setState(() {
      _dismissed = true;
      _listeningForVoice = false;
    });
    await _tts.stop();
    await _speech.cancel();
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
    _speech.cancel();
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
                Icon(
                  _listeningForVoice ? Icons.mic_rounded : Icons.alarm_rounded,
                  size: 84,
                  color: AppTheme.accent,
                ),
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
                if (_listeningForVoice) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Escuchando… di "ok" para apagarla',
                    style: TextStyle(color: AppTheme.confirm, fontSize: 14),
                  ),
                ],
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
