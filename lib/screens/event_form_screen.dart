import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/asiste_event.dart';
import '../services/events_repository.dart';
import '../services/notification_service.dart';

/// Se navega con `arguments` como:
///  - un [AsisteEvent] para editar uno existente, o
///  - un [DateTime] con el día ya seleccionado para crear uno nuevo.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _titleController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _recurringDaily = false;
  AsisteEvent? _editing;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is AsisteEvent) {
      _editing = args;
      _titleController.text = args.title;
      _date = args.dateTime;
      _time = TimeOfDay(hour: args.dateTime.hour, minute: args.dateTime.minute);
      _recurringDaily = args.recurringDaily;
    } else if (args is DateTime) {
      _date = args;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título al evento.')),
      );
      return;
    }
    final dateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final event = AsisteEvent(
      id: _editing?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      dateTime: dateTime,
      recurringDaily: _recurringDaily,
    );

    final repo = context.read<EventsRepository>();
    if (_editing != null) {
      await repo.updateEvent(event);
    } else {
      await repo.addEvent(event);
    }
    try {
      await NotificationService.instance.scheduleForEvent(event);
    } catch (e) {
      if (!mounted) return;
      final exactDenied = e.toString().contains('exact_alarms_not_permitted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exactDenied
                ? 'El evento se guardó, pero falta el permiso de "Alarmas y '
                    'recordatorios" del sistema. Ábrelo desde Ajustes.'
                : 'El evento se guardó, pero Android no pudo programar la alarma: $e',
          ),
          duration: const Duration(seconds: 6),
          action: exactDenied
              ? SnackBarAction(
                  label: 'Abrir ajustes',
                  onPressed: () {
                    NotificationService.instance.openExactAlarmSettings();
                  },
                )
              : null,
        ),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarma programada correctamente.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing == null ? 'Nuevo evento' : 'Editar evento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Título (ej. Ir al dentista)'),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today_rounded),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora'),
            subtitle: Text(_time.format(context)),
            trailing: const Icon(Icons.access_time_rounded),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repetir todos los días'),
            value: _recurringDaily,
            onChanged: (v) => setState(() => _recurringDaily = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}
