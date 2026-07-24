import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sismo_ve/main.dart';
import 'package:sismo_ve/data/earthquake.dart';

void main() {
  group('Earthquake model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'us7000abcdef',
        'properties': {
          'mag': 5.2,
          'place': '10 km NE of Caracas, Venezuela',
          'time': 1711324800000,
        },
        'geometry': {
          'coordinates': [-66.8, 10.5, 15.0],
        },
      };

      final eq = Earthquake.fromJson(json);

      expect(eq.id, 'us7000abcdef');
      expect(eq.magnitude, 5.2);
      expect(eq.place, '10 km NE of Caracas, Venezuela');
      expect(eq.latitude, 10.5);
      expect(eq.longitude, -66.8);
      expect(eq.depthKm, 15.0);
      expect(eq.source, 'USGS');
      expect(eq.notified, 0);
    });

    test('fromJson handles missing/empty fields gracefully', () {
      final json = <String, dynamic>{};

      final eq = Earthquake.fromJson(json);

      expect(eq.id, '');
      expect(eq.magnitude, 0.0);
      expect(eq.place, '');
      expect(eq.latitude, 0.0);
      expect(eq.longitude, 0.0);
      expect(eq.depthKm, 0.0);
    });

    test('magnitudeColor returns correct colors', () {
      expect(Earthquake.magnitudeColor(6.0), const Color(0xFFE53935)); // red
      expect(Earthquake.magnitudeColor(5.5), const Color(0xFFFB8C00)); // orange
      expect(Earthquake.magnitudeColor(4.5), const Color(0xFFFFC107)); // amber
      expect(Earthquake.magnitudeColor(3.0), const Color(0xFF43A047)); // green
    });

    test('equality is based on id', () {
      final a = Earthquake(
        id: 'eq1',
        magnitude: 4.0,
        place: 'Test',
        time: DateTime.now(),
        latitude: 10.0,
        longitude: -66.0,
        depthKm: 10.0,
      );
      final b = Earthquake(
        id: 'eq1', // mismo id
        magnitude: 5.0, // diferente magnitud
        place: 'Other',
        time: DateTime.now(),
        latitude: 11.0,
        longitude: -67.0,
        depthKm: 20.0,
      );
      final c = Earthquake(
        id: 'eq2',
        magnitude: 4.0,
        place: 'Test',
        time: DateTime.now(),
        latitude: 10.0,
        longitude: -66.0,
        depthKm: 10.0,
      );

      expect(a, equals(b)); // mismo id → iguales
      expect(a, isNot(equals(c))); // distinto id → diferentes
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode is id-based', () {
      final eq = Earthquake(
        id: 'hash-test',
        magnitude: 3.5,
        place: 'Test',
        time: DateTime.now(),
        latitude: 8.0,
        longitude: -70.0,
        depthKm: 5.0,
      );
      expect(eq.hashCode, 'hash-test'.hashCode);
    });
  });

  group('App smoke test', () {
    testWidgets('SismosApp renders without crashing', (tester) async {
      await tester.pumpWidget(const SismosApp());
      // Should show the app bar title
      expect(find.text('SismoVE'), findsOneWidget);
    });

    testWidgets('HomeScreen shows prep bar', (tester) async {
      await tester.pumpWidget(const SismosApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Critical emergency buttons should be present (may need scroll)
      expect(find.text('SOS'), findsWidgets);
      expect(find.text('Guía'), findsWidgets);
      expect(find.text('Kit'), findsWidgets);
    });
  });
}
