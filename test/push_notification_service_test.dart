import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sismo_ve/services/notification_service.dart';
import 'package:sismo_ve/services/push_notification_service.dart';

Map<String, String?> _payload({
  String id = 'us6000test',
  String mag = '4.8',
  String place = '15 km NE de Cumaná, Venezuela',
  String? time,
  String lat = '10.45',
  String lon = '-64.15',
  String depth = '33.2',
}) {
  return {
    'id': id,
    'mag': mag,
    'place': place,
    if (time != null) 'time': time,
    'lat': lat,
    'lon': lon,
    'depth': depth,
  };
}

void main() {
  setUp(() {
    // Estado estático compartido entre tests: resetear para aislarlos.
    PushNotificationService.onTapNotification = null;
    NotificationService.onQuakeTap =
        PushNotificationService.handleLocalNotificationTap;
    NotificationService.pendingTapPayload = null;
    PushNotificationService.instance.clearInitialQuakeId();
  });

  group('parseQuakeData', () {
    test('parsea un payload completo del backend', () {
      final now = DateTime.now();
      final q = parseQuakeData(
        _payload(time: '${now.millisecondsSinceEpoch}'),
        receivedAt: now,
      );

      expect(q, isNotNull);
      expect(q!.id, 'us6000test');
      expect(q.magnitude, 4.8);
      expect(q.place, '15 km NE de Cumaná, Venezuela');
      expect(q.latitude, 10.45);
      expect(q.longitude, -64.15);
      expect(q.depthKm, 33.2);
    });

    test('devuelve null sin id', () {
      expect(parseQuakeData(_payload(id: '')), isNull);
    });

    test('devuelve null con magnitud no numérica', () {
      expect(parseQuakeData(_payload(mag: 'x')), isNull);
    });

    test('devuelve null sin magnitud', () {
      expect(parseQuakeData(_payload(mag: '')), isNull);
    });

    test('con time ausente usa receivedAt como fallback', () {
      final received = DateTime.fromMillisecondsSinceEpoch(1711324800000);
      final q = parseQuakeData(_payload(), receivedAt: received);
      expect(q, isNotNull);
      expect(q!.time, received);
    });

    test('con receivedAt ausente usa el reloj actual', () {
      final before = DateTime.now();
      final q = parseQuakeData(_payload());
      final after = DateTime.now();
      expect(q, isNotNull);
      expect(
        q!.time.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(q.time.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('convierte a Earthquake con fuente USGS', () {
      final q = parseQuakeData(_payload())!;
      final eq = q.toEarthquake();
      expect(eq.id, 'us6000test');
      expect(eq.magnitude, 4.8);
      expect(eq.source, 'USGS');
      expect(eq.notified, 0);
    });

    test('tolera campos geo faltantes con valores en 0', () {
      final q = parseQuakeData({'id': 'x1', 'mag': '3.2'});
      expect(q, isNotNull);
      expect(q!.latitude, 0);
      expect(q.longitude, 0);
      expect(q.depthKm, 0);
      expect(q.place, '');
    });
  });

  group('shouldNotifyPush', () {
    test('notifica cuando la magnitud alcanza el umbral', () {
      expect(shouldNotifyPush(mag: 3.0, minMag: 3.0, enabled: true), isTrue);
    });

    test('no notifica por debajo del umbral', () {
      expect(shouldNotifyPush(mag: 2.9, minMag: 3.0, enabled: true), isFalse);
    });

    test('respeta el toggle de alertas desactivadas', () {
      expect(shouldNotifyPush(mag: 7.0, minMag: 3.0, enabled: false), isFalse);
    });
  });

  group('ruteo de taps de notificaciones (Finding #1)', () {
    test('un tap con router registrado notifica a la UI y guarda el id', () {
      String? routedId;
      PushNotificationService.onTapNotification = () async {
        routedId = PushNotificationService.instance.initialQuakeId;
      };
      addTearDown(() => PushNotificationService.onTapNotification = null);

      NotificationService.onQuakeTap!('us-tap-1');

      expect(PushNotificationService.instance.initialQuakeId, 'us-tap-1');
      expect(routedId, 'us-tap-1');
    });

    test('un tap sin router listo deja el id en espera (cold start)', () {
      NotificationService.onQuakeTap = null;
      NotificationService.handleTapResponse(
        const NotificationResponse(
          id: 1,
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'us-tap-2',
        ),
      );

      expect(NotificationService.pendingTapPayload, 'us-tap-2');
      expect(
        PushNotificationService.instance.initialQuakeId,
        isNull,
        reason: 'sin router, el id no debe perderse pero tampoco exponerse aún',
      );

      // La UI (initialize) drena el pendiente una sola vez: primero asigna
      // el router, después consume el payload en espera.
      NotificationService.onQuakeTap =
          PushNotificationService.handleLocalNotificationTap;
      final pending = NotificationService.pendingTapPayload!;
      NotificationService.pendingTapPayload = null;
      NotificationService.onQuakeTap!(pending);

      expect(PushNotificationService.instance.initialQuakeId, 'us-tap-2');
      expect(NotificationService.pendingTapPayload, isNull);
    });

    test('handleTapResponse ignora payload vacío', () {
      NotificationService.handleTapResponse(
        const NotificationResponse(
          id: 1,
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '',
        ),
      );
      expect(NotificationService.pendingTapPayload, isNull);
      expect(PushNotificationService.instance.initialQuakeId, isNull);
    });

    test('clearInitialQuakeId evita abrir el detalle dos veces', () {
      NotificationService.onQuakeTap!('us-tap-3');
      expect(PushNotificationService.instance.initialQuakeId, 'us-tap-3');

      PushNotificationService.instance.clearInitialQuakeId();
      expect(PushNotificationService.instance.initialQuakeId, isNull);
    });
  });
}
