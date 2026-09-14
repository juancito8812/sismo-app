import 'package:flutter_test/flutter_test.dart';

import 'package:sismo_ve/data/earthquake.dart';
import 'package:sismo_ve/services/alert_engine.dart';

Earthquake _eq(String id, double mag, {DateTime? time}) {
  return Earthquake(
    id: id,
    magnitude: mag,
    place: 'Test $id',
    time: time ?? DateTime.now(),
    latitude: 10.5,
    longitude: -66.9,
    depthKm: 10.0,
  );
}

void main() {
  group('alertDecisions', () {
    test('notifica solo eventos por encima del umbral', () {
      final events = [
        _eq('a', 2.5),
        _eq('b', 3.0),
        _eq('c', 4.7),
      ];
      final decisions = alertDecisions(
        events: events,
        pendingIds: {'a', 'b', 'c'},
        minMagnitude: 3.0,
        enabled: true,
      );
      // b califica por igualdad (>=), a no llega al umbral
      expect(decisions, containsAllInOrder(['b', 'c']));
      expect(decisions, isNot(contains('a')));
    });

    test('no notifica eventos ya notificados', () {
      final events = [_eq('new', 5.0), _eq('old', 6.0)];
      final decisions = alertDecisions(
        events: events,
        pendingIds: {'new'}, // 'old' ya fue notificado
        minMagnitude: 3.0,
        enabled: true,
      );
      expect(decisions, ['new']);
    });

    test('con alertas desactivadas no emite ninguna decisión', () {
      final events = [_eq('a', 7.0), _eq('b', 5.0)];
      final decisions = alertDecisions(
        events: events,
        pendingIds: {'a', 'b'},
        minMagnitude: 3.0,
        enabled: false,
      );
      expect(decisions, isEmpty);
    });

    test('dedupe: el mismo evento nunca se decide dos veces', () {
      final events = [_eq('x', 4.0)];
      final pending = {'x'};

      final first = alertDecisions(
        events: events, pendingIds: pending, minMagnitude: 3.0, enabled: true,
      );
      // Simula el segundo ciclo después de marcar como notificado:
      pending.remove('x');
      final second = alertDecisions(
        events: events, pendingIds: pending, minMagnitude: 3.0, enabled: true,
      );
      expect(first, ['x']);
      expect(second, isEmpty);
    });

    test('umbral alto no notifica sismos moderados', () {
      final events = [_eq('m5', 5.2), _eq('m6', 6.1)];
      final decisions = alertDecisions(
        events: events,
        pendingIds: {'m5', 'm6'},
        minMagnitude: 6.0,
        enabled: true,
      );
      expect(decisions, ['m6']);
    });
  });

  group('decideRevision (revisiones de USGS)', () {
    Earthquake prevQuake(String id, double mag, {int notified = 1}) => Earthquake(
          id: id,
          magnitude: mag,
          place: 'Test $id',
          time: DateTime.now().subtract(const Duration(minutes: 30)),
          latitude: 10.5,
          longitude: -66.9,
          depthKm: 10.0,
          notified: notified,
        );

    test('evento nuevo (sin estado previo) no es revisión', () {
      final rev = decideRevision(
        previous: null,
        updated: _eq('a', 4.0),
        minMagnitude: 3.0,
      );
      expect(rev, isNull);
    });

    test('cambio trivial no re-alerta', () {
      final rev = decideRevision(
        previous: prevQuake('a', 4.0),
        updated: _eq('a', 4.2), // delta < 0.5
        minMagnitude: 3.0,
      );
      expect(rev, isNull);
    });

    test('revisión a la baja solo actualiza historial', () {
      final rev = decideRevision(
        previous: prevQuake('a', 4.8),
        updated: _eq('a', 3.9), // bajó
        minMagnitude: 3.0,
      );
      expect(rev, isNull);
    });

    test('cruce de umbral hacia arriba re-alerta', () {
      final rev = decideRevision(
        previous: prevQuake('a', 2.6),
        updated: _eq('a', 3.4),
        minMagnitude: 3.0,
      );
      expect(rev, isNotNull);
      expect(rev!.kind, QuakeRevisionKind.crossedThreshold);
      expect(rev.previousMagnitude, 2.6);
      expect(
        rev.titleFor(_eq('a', 3.4)),
        'Sismo revisado: M3.4 (era M2.6)',
      );
      expect(rev.bodyFor(_eq('a', 3.4), 3.0), contains('Superó tu umbral'));
    });

    test('escalación >= +0.5 sobre el umbral re-alerta', () {
      final rev = decideRevision(
        previous: prevQuake('a', 4.0),
        updated: _eq('a', 4.6),
        minMagnitude: 3.0,
      );
      expect(rev, isNotNull);
      expect(rev!.kind, QuakeRevisionKind.escalated);
      expect(rev.bodyFor(_eq('a', 4.6), 3.0), contains('Se intensificó +0.6'));
    });

    test('escalación que no llega al umbral no re-alerta', () {
      final rev = decideRevision(
        previous: prevQuake('a', 4.0),
        updated: _eq('a', 4.6),
        minMagnitude: 5.0, // sigue debajo del umbral del usuario
      );
      expect(rev, isNull);
    });

    test('evento que nunca sonó no es re-alerta (es primera notificación)', () {
      final rev = decideRevision(
        previous: prevQuake('a', 2.6, notified: 0),
        updated: _eq('a', 3.4),
        minMagnitude: 3.0,
      );
      expect(rev, isNull);
    });

    test('evento fuera de la ventana de frescura no re-alerta', () {
      // Mismo tiempo de ocurrencia para ambas versiones: las revisiones de
      // magnitud no cambian cuándo ocurrió el sismo.
      final occurredAt = DateTime.now().subtract(const Duration(hours: 12));
      final old = Earthquake(
        id: 'old',
        magnitude: 2.6,
        place: 'Test',
        time: occurredAt,
        latitude: 10,
        longitude: -66,
        depthKm: 10,
        notified: 1,
      );
      final rev = decideRevision(
        previous: old,
        updated: _eq('old', 4.0, time: occurredAt), // +1.4 pero ya es histórico
        minMagnitude: 3.0,
      );
      expect(rev, isNull);
    });
  });
}
