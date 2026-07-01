import 'package:workmanager/workmanager.dart';
import '../data/local_db.dart';
import '../data/repository.dart';
import '../services/notification_service.dart';

const kBackgroundChannel = 'sismos.background';

// Dispatcher de WorkManager (debe ser top-level)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kBackgroundChannel) {
      try {
        await _checkAndNotify();
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

Future<void> _checkAndNotify() async {
  final repo = EarthquakeRepository();
  final db = LocalDb.instance;
  final notifier = NotificationService.instance;
  await notifier.init();

  final events = await repo.fetchRecent();
  final saved = await db.recent();

  final unNotifiedIds =
      saved.where((e) => e.notified == 0).map((e) => e.id).toSet();
  for (var eq in events) {
    final alreadyNotified = !unNotifiedIds.contains(eq.id);
    if (!alreadyNotified && eq.magnitude >= 3) {
      await notifier.showSismoAlert(
        id: eq.id.hashCode & 0x7FFFFFFF,
        title: 'Sismo detectado M${eq.magnitude.toStringAsFixed(1)}',
        body: eq.place,
      );
      await db.markNotified(eq.id);
    }
    await db.insertOrUpdate(eq);
  }
}
