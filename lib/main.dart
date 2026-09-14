import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sismo_ve/screens/home.dart';
import 'package:sismo_ve/services/alert_engine.dart';
import 'package:sismo_ve/services/notification_service.dart';
import 'package:sismo_ve/services/push_notification_service.dart';

/// Handler de mensajes FCM en background/terminated (top-level requerido
/// por firebase_messaging).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) =>
    firebaseMessagingBackgroundHandler(message);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Canal de notificaciones lo antes posible: si un push llega con la app
  // cerrada, la notificación local necesita el canal (y su sonido) ya creado.
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.ensureChannels();
  } catch (e) {
    // ignore: avoid_print
    print('[main] notificaciones init error (non-fatal): $e');
  }

  // Push vía FCM (tolerante a fallos: sin Firebase configurado, la app
  // funciona igual con el polling del AlertEngine).
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    await PushNotificationService.instance.initialize();
  } catch (e) {
    // ignore: avoid_print
    print('[main] push init error (non-fatal): $e');
  }

  // Registra el polling en background (no cancela el schedule existente:
  // cambiar el intervalo en Ajustes lo re-registra con la política update).
  try {
    await AlertEnginePolling.configure();
  } catch (e) {
    // Si Workmanager falla (ej. permisos no concedidos), la app igual arranca
    // ignore: avoid_print
    print('[main] Workmanager init error (non-fatal): $e');
  }
  // Monitoreo en vivo mientras la app está abierta (más rápido que el poller).
  await AlertEngine.instance.startLiveMonitoring();
  runApp(const SismosApp());
}

class SismosApp extends StatelessWidget {
  const SismosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SismoVE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
