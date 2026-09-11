import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/asiste_event.dart';
import '../services/events_repository.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/secure_settings_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/wake_word_service.dart';
import '../theme/app_theme.dart';
import '../widgets/conversation_bubble.dart';
import '../widgets/mic_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SpeechService _speech = SpeechService();
  final TtsService _tts = TtsService();
  final WakeWordService _wakeWord = WakeWordService();
  late final GeminiService _gemini = GeminiService(SecureSettingsService());
  StreamSubscription<void>? _wakeWordSub;

  MicButtonState _state = MicButtonState.idle;
  final List<ConversationTurn> _history = [];
  String _userText = '';
  // Si Gemini está preguntando algo de sí/no (por ahora, solo "¿todos los
  // días?"), escuchamos en modo "respuesta rápida" en vez del modo normal
  // de frase larga. Null = escucha libre (descripción inicial, hora, etc).
  String? _pendingMissingField;
  String _asisteText =
      'Toca el micrófono y dime qué quieres programar: una alarma, '
      'un evento, un recordatorio o una reunión.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakeWordSub = _wakeWord.onDetected.listen((_) => _onWakeWordDetected());
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestStartupPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeWordSub?.cancel();
    _wakeWord.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fase 1a: la palabra "Alexa" solo se escucha con la app abierta y en
    // primer plano. Al pasar a segundo plano soltamos el micrófono (buena
    // práctica de batería/privacidad); al volver, lo retomamos.
    if (state == AppLifecycleState.resumed) {
      if (_state == MicButtonState.idle) _wakeWord.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wakeWord.stop();
    }
  }

  Future<void> _requestStartupPermissions() async {
    final exactAlarmGranted = await NotificationService.instance.requestPermissions();
    if (!exactAlarmGranted && mounted) {
      _showSnack(
        'Para que las alarmas suenen puntuales, activa "Alarmas y recordatorios" '
        'para Asiste en los Ajustes del sistema.',
      );
    }
    // El motor de "Alexa" necesita el permiso de micrófono ya concedido
    // antes de arrancar (si no, el lado nativo lo intenta y falla en
    // silencio). ensureReady() lo pide si todavía no se aceptó.
    final micReady = await _speech.ensureReady();
    if (micReady) await _wakeWord.start();
  }

  Future<void> _onWakeWordDetected() async {
    // Si ya está en medio de algo (hablando, escuchando, pensando),
    // ignoramos la palabra de activación para no pisar esa conversación.
    if (_state != MicButtonState.idle) return;
    _history.clear();
    _pendingMissingField = null;
    setState(() {
      _asisteText = '¿Sí?';
      _state = MicButtonState.speaking;
    });
    await _tts.speakAndWait('¿Sí?');
    if (!mounted) return;
    await _listenAndProcess();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onMicTap() async {
    switch (_state) {
      case MicButtonState.idle:
        _history.clear();
        _pendingMissingField = null;
        await _listenAndProcess();
        break;
      case MicButtonState.listening:
        await _speech.stop();
        break;
      case MicButtonState.thinking:
      case MicButtonState.speaking:
        // Tocar durante estos estados cancela la conversación actual.
        await _tts.stop();
        await _speech.cancel();
        setState(() {
          _state = MicButtonState.idle;
          _asisteText = 'Cancelado. Toca el micrófono cuando quieras.';
        });
        break;
    }
  }

  Future<void> _listenAndProcess() async {
    final ready = await _speech.ensureReady();
    if (!ready) {
      setState(() {
        _asisteText = 'Necesito permiso de micrófono para escucharte.';
        _state = MicButtonState.idle;
      });
      return;
    }

    // Android solo permite un micrófono (AudioRecord) activo a la vez:
    // hay que soltar el motor de "Alexa" antes de que speech_to_text
    // tome el micrófono, o ninguno de los dos funciona bien.
    await _wakeWord.stop();
    setState(() => _state = MicButtonState.listening);
    String text;
    try {
      text = await _speech.listenOnce(
        quickAnswer: _pendingMissingField == 'recurring',
      );
    } finally {
      // SIEMPRE reactivamos, sin importar cómo termine listenOnce (con
      // texto, vacío, error, cancelado) — si no, "Alexa" se queda sordo
      // para el resto de la sesión.
      if (mounted) await _wakeWord.start();
    }

    if (!mounted) return;
    if (text.trim().isEmpty) {
      setState(() {
        _state = MicButtonState.idle;
        _asisteText = 'No te escuché. Toca el micrófono e inténtalo de nuevo.';
      });
      return;
    }

    setState(() {
      _userText = text;
      _state = MicButtonState.thinking;
      _history.add(ConversationTurn('user', text));
    });

    await _processTurn();
  }

  Future<void> _processTurn() async {
    try {
      final result = await _gemini.sendTurn(_history);
      _history.add(ConversationTurn('model', jsonEncode(result.raw)));

      if (result.needsInfo) {
        _pendingMissingField = result.missingField;
        final question = result.question ?? '¿Puedes repetirlo?';
        await _sayAndListenAgain(question);
        return;
      }

      if (result.isComplete && result.intent == 'schedule') {
        if (result.title == null || result.dateTime == null) {
          await _sayAndReturnToIdle(
            'Me faltó algún dato para programarlo, intentemos de nuevo.',
          );
          return;
        }
        final event = AsisteEvent(
          id: const Uuid().v4(),
          title: result.title!,
          dateTime: result.dateTime!,
          recurringDaily: result.recurringDaily,
        );
        if (!mounted) return;
        await context.read<EventsRepository>().addEvent(event);

        try {
          await NotificationService.instance.scheduleForEvent(event);
        } catch (e) {
          final exactDenied = e.toString().contains('exact_alarms_not_permitted');
          await _sayAndReturnToIdle(
            exactDenied
                ? 'Guardé el evento, pero al sistema le falta darle permiso '
                    'a Asiste para programar alarmas exactas. Ve a Ajustes '
                    'de Asiste y actívalo.'
                : 'Guardé el evento, pero Android no pudo programar la alarma. '
                    'Revisa los permisos de notificaciones y Alarmas y recordatorios.',
          );
          return;
        }

        await _sayAndReturnToIdle(
          result.confirmationMessage ?? 'Listo, lo programé.',
        );
        return;
      }

      // chitchat, rejected o unclear sin pregunta puntual
      await _sayAndReturnToIdle(
        result.confirmationMessage ?? result.question ?? 'No entendí bien.',
      );
    } on GeminiException catch (e) {
      await _sayAndReturnToIdle(e.message);
    } catch (_) {
      await _sayAndReturnToIdle('Ocurrió un problema inesperado, intenta de nuevo.');
    }
  }

  Future<void> _sayAndListenAgain(String question) async {
    setState(() {
      _asisteText = question;
      _state = MicButtonState.speaking;
    });
    await _tts.speakAndWait(question);
    if (!mounted) return;
    await _listenAndProcess();
  }

  Future<void> _sayAndReturnToIdle(String message) async {
    setState(() {
      _asisteText = message;
      _state = MicButtonState.speaking;
    });
    await _tts.speakAndWait(message);
    if (!mounted) return;
    setState(() => _state = MicButtonState.idle);
  }

  String get _stateLabel {
    switch (_state) {
      case MicButtonState.idle:
        return 'Toca para hablar';
      case MicButtonState.listening:
        return 'Escuchando…';
      case MicButtonState.thinking:
        return 'Pensando…';
      case MicButtonState.speaking:
        return 'Hablando…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asiste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Calendario',
            onPressed: () => Navigator.of(context).pushNamed('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            MicButton(state: _state, onTap: _onMicTap),
            const SizedBox(height: 20),
            Text(
              _stateLabel,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_userText.isNotEmpty && _state != MicButtonState.idle)
              ConversationBubble(text: _userText, isAsiste: false),
            ConversationBubble(text: _asisteText, isAsiste: true),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
