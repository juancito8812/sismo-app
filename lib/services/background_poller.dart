import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/earthquake.dart';
import '../data/local_db.dart';
import '../services/notification_service.dart';

const _kChannel = 'sismos.background';

// Dispatcher de WorkManager (debe ser top-level)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _kChannel) {
      try {
        await _checkAndNotify();
      } catch (e) {
        // evitar crash en background
      }
      return Future.value(true);
    }
    return Future.value(false);
  });
}

Future<void> _checkAndNotify() async {
  final repo = EarthquakeRepository();
  final db = LocalDb.instance;
  final notifier = NotificationService.instance;
  await notifier.init();

  final events = await repo.fetchRecent();
  final saved = await db.recent();

  final savedIds = saved.map((e) => e.id).toSet();
  for (final eq in events) {
    final notified = saved.map((e) => e.id).contains(eq.id);
    if (!notified && eq.magnitude >= 3) {
      await notifier.showSismoAlert(
        id: eq.id.hashCode,
        title: 'Sismo detectado M${eq.magnitude.toStringAsFixed(1)}',
        body: eq.place,
      );
    }
    await db.insertOrUpdate(eq);
  }
}
