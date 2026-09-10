import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_service.dart';
import '../services/notification_service.dart';
import '../services/secure_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _settings = SecureSettingsService();
  final _appSettings = AppSettingsService();
  final List<TextEditingController> _controllers = List.generate(
    AppConstants.maxApiKeys,
    (_) => TextEditingController(),
  );
  bool _loading = true;
  bool _saving = false;
  bool? _exactAlarmsGranted;
  bool _loopAlarm = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshExactAlarmStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El usuario suele conceder el permiso desde Ajustes del sistema y
    // volver a la app: al reanudar, refrescamos el estado mostrado.
    if (state == AppLifecycleState.resumed) {
      _refreshExactAlarmStatus();
    }
  }

  Future<void> _refreshExactAlarmStatus() async {
    final granted = await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) setState(() => _exactAlarmsGranted = granted);
  }

  Future<void> _load() async {
    for (int i = 0; i < AppConstants.maxApiKeys; i++) {
      final v = await _settings.getKey(i + 1);
      _controllers[i].text = v ?? '';
    }
    final loop = await _appSettings.getLoopAlarm();
    if (mounted) setState(() {
      _loading = false;
      _loopAlarm = loop;
    });
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    for (int i = 0; i < AppConstants.maxApiKeys; i++) {
      await _settings.setKey(i + 1, _controllers[i].text);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Claves guardadas.')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildExactAlarmCard() {
    final granted = _exactAlarmsGranted;
    final ok = granted == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (ok ? AppTheme.confirm : Colors.orange).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ok ? AppTheme.confirm : Colors.orange).withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                color: ok ? AppTheme.confirm : Colors.orange,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Permiso de "Alarmas y recordatorios"',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            granted == null
                ? 'Comprobando…'
                : ok
                    ? 'Concedido. Las alarmas pueden sonar puntuales.'
                    : 'No concedido. Sin este permiso especial del sistema, '
                        'Android no deja que Asiste programe alarmas exactas '
                        '(aunque los permisos de notificaciones estén bien). '
                        'No es el mismo ajuste que el sonido/vibración del '
                        'canal de notificaciones.',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          if (!ok) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await NotificationService.instance.openExactAlarmSettings();
                },
                child: const Text('Abrir el ajuste correcto del sistema'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoopAlarmCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textMuted.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Repetir la alarma en bucle',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Activado: dice el aviso una y otra vez hasta que tocas Aceptar. '
          'Desactivado: lo dice una sola vez y se queda esperando en '
          'silencio en la pantalla de la alarma. No tiene relación con '
          '"Repetir todos los días", que es por evento.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        value: _loopAlarm,
        onChanged: (value) async {
          setState(() => _loopAlarm = value);
          await _appSettings.setLoopAlarm(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildExactAlarmCard(),
                const SizedBox(height: 16),
                _buildLoopAlarmCard(),
                const SizedBox(height: 28),
                const Text(
                  'Claves de API de Gemini',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pega hasta 3 claves gratuitas. Asiste usa la primera y, si '
                  'se queda sin cuota, pasa automáticamente a la siguiente.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://aistudio.google.com/apikey'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'Generar una clave gratis en aistudio.google.com/apikey',
                    style: TextStyle(
                      color: AppTheme.confirm,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (int i = 0; i < AppConstants.maxApiKeys; i++) ...[
                  Text(
                    'Clave ${i + 1}${i == 0 ? " (principal)" : ""}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controllers[i],
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Pega aquí la clave de API',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () =>
                            setState(() => _controllers[i].clear()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAll,
                    child: Text(_saving ? 'Guardando…' : 'Guardar'),
                  ),
                ),
              ],
            ),
    );
  }
}
