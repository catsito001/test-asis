import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/alarm_ring_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/event_form_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/events_repository.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);

  final eventsRepository = EventsRepository();
  await eventsRepository.load();

  await NotificationService.instance.init();

  // Si la app estaba cerrada y se abrió porque el usuario tocó (o se
  // disparó a pantalla completa) una notificación de alarma, vamos
  // directo a la pantalla de la alarma sonando.
  String? launchEventId;
  final launchDetails = await NotificationService.instance.appLaunchDetails();
  if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
    launchEventId = launchDetails.notificationResponse?.payload;
  }

  runApp(AsisteApp(
    eventsRepository: eventsRepository,
    launchEventId: launchEventId,
  ));
}

class AsisteApp extends StatefulWidget {
  const AsisteApp({
    super.key,
    required this.eventsRepository,
    this.launchEventId,
  });

  final EventsRepository eventsRepository;
  final String? launchEventId;

  @override
  State<AsisteApp> createState() => _AsisteAppState();
}

class _AsisteAppState extends State<AsisteApp> {
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();
    _tapSub = NotificationService.instance.onAlarmTapped.listen((eventId) {
      navigatorKey.currentState?.pushNamed('/alarm_ring', arguments: eventId);
    });
    if (widget.launchEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState
            ?.pushNamed('/alarm_ring', arguments: widget.launchEventId);
      });
    }
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EventsRepository>.value(
      value: widget.eventsRepository,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Asiste',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme(),
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/calendar': (_) => const CalendarScreen(),
          '/event_form': (_) => const EventFormScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/alarm_ring') {
            final eventId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => AlarmRingScreen(eventId: eventId),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
