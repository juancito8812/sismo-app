import 'package:flutter/material.dart';
import 'package:venezuela_sismos_app/screens/home.dart';
import 'package:workmanager/workmanager.dart';
import 'package:venezuela_sismos_app/services/background_poller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      'sismos.background',
      kBackgroundChannel,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
    // ignore: avoid_print
    print('[main] Workmanager initialized');
  } catch (e) {
    // Si Workmanager falla (ej. permisos no concedidos), la app igual arranca
    // ignore: avoid_print
    print('[main] Workmanager init error (non-fatal): $e');
  }
  runApp(const SismosApp());
}

class SismosApp extends StatelessWidget {
  const SismosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sismos Venezuela',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
