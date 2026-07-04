import 'package:workmanager/workmanager.dart';
import '../data/local_db.dart';
import '../data/repository.dart';
import '../services/notification_service.dart';

const kBackgroundChannel = 'sismos.background';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kBackgroundChannel) {
      try {
        await _checkAndNotify();
      } catch (e) {
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
  final unnotifiedIds = await _unnotifiedIds(db);

  for (var eq in events) {
    if (unnotifiedIds.contains(eq.id) && eq.magnitude >= 3) {
      await notifier.showSismoAlert(
        id: eq.id.hashCode & 0x7FFFFFFF,
        title: 'Sismo detectado M${eq.magnitude.toStringAsFixed(1)}',
        body: eq.place,
      );
      await db.markNotified(eq.id);
      unnotifiedIds.remove(eq.id);
    }
    await db.insertOrUpdate(eq);
  }
}

Future<Set<String>> _unnotifiedIds(LocalDb db) async {
  final rows = await db.database.rawQuery(
    'SELECT id FROM events WHERE notified = 0',
  );
  return rows.map((r) => r['id'] as String).toSet();
}
