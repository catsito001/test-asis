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
import '../theme/app_theme.dart';
import '../widgets/conversation_bubble.dart';
import '../widgets/mic_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService _speech = SpeechService();
  final TtsService _tts = TtsService();
  late final GeminiService _gemini = GeminiService(SecureSettingsService());

  MicButtonState _state = MicButtonState.idle;
  final List<ConversationTurn> _history = [];
  String _userText = '';
  String _asisteText =
      'Toca el micrófono y dime qué quieres programar: una alarma, '
      'un evento, un recordatorio o una reunión.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestStartupPermissions());
  }

  Future<void> _requestStartupPermissions() async {
    final exactAlarmGranted = await NotificationService.instance.requestPermissions();
    if (!exactAlarmGranted && mounted) {
      _showSnack(
        'Para que las alarmas suenen puntuales, activa "Alarmas y recordatorios" '
        'para Asiste en los Ajustes del sistema.',
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onMicTap() async {
    switch (_state) {
      case MicButtonState.idle:
        _history.clear();
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

    setState(() => _state = MicButtonState.listening);
    final text = await _speech.listenOnce();

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
