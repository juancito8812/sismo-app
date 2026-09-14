import 'package:flutter_test/flutter_test.dart';

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
}
