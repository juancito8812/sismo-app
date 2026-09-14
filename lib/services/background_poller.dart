import 'package:workmanager/workmanager.dart';
import '../services/alert_engine.dart';

/// Canal/tarea de WorkManager (referenciado por alert_engine).
const kBackgroundChannel = 'sismos.background';

// Dispatcher de WorkManager (debe ser top-level)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kBackgroundChannel) {
      try {
        final notified = await AlertEngine.instance.runCheck();
        // ignore: avoid_print
        print('[background_poller] ciclo OK, $notified alerta(s) emitida(s)');
      } catch (e) {
        // evitar crash en background
        // ignore: avoid_print
        print('[background_poller] error: $e');
      }
      return Future.value(true);
    }
    return Future.value(false);
  });
}
