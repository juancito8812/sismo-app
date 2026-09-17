import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

import 'package:sismo_ve/data/earthquake.dart';
import 'package:sismo_ve/data/local_db.dart';

/// DB SQLite real en memoria (no mocks): las regresiones de dedupe entre
/// isolates (polling vs push) dependen del comportamiento exacto de SQL.
bool _canLoadSqlite() {
  try {
    DynamicLibrary.open(Platform.isLinux ? 'libsqlite3.so.0' : 'libsqlite3.so');
    return true;
  } catch (_) {
    return false;
  }
}
void main() {
  final sqliteOk = _canLoadSqlite();
  setUpAll(() {
    if (!sqliteOk) return;
    // Ubuntu trae la lib versión (.so.0) sin el symlink de desarrollo:
    // apuntar el loader de package:sqlite3 al archivo real.
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
    sqfliteFfiInit();
    // Sin isolate: open.overrideFor aplica en este isolate (la variante con
    // isolate corre SQLite en otro isolate donde el override no llega).
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Earthquake quake(String id, double mag, {int notified = 0}) => Earthquake(
        id: id,
        magnitude: mag,
        place: 'Prueba, Venezuela',
        time: DateTime.now().subtract(const Duration(minutes: 1)),
        latitude: 10.5,
        longitude: -66.9,
        depthKm: 10,
        notified: notified,
      );

  group('upsertNotified (dedupe atómico, Finding #2)', () {
    test('un evento nuevo arranca con notified = 0', () async {
      final db = LocalDb.instance;
      await db.upsertNotified(quake('db-new-1', 3.4));

      final row = await db.byId('db-new-1');
      expect(row, isNotNull);
      expect(row!.notified, 0);
      expect(row.magnitude, 3.4);
    });

    test('re-sync del feed NO revierte notified=1 escrito por otro isolate',
        () async {
      final db = LocalDb.instance;
      // Ciclo 1: el evento llega y suena.
      await db.upsertNotified(quake('db-race-1', 4.0));
      await db.markNotified('db-race-1');
      expect((await db.byId('db-race-1'))!.notified, 1);

      // El isolate del push marca notified=1; en paralelo el sync del
      // polling re-pisa el evento con la versión del feed. Con el upsert
      // atómico el flag sobrevive (antes se revertía a 0 y el evento
      // volvía a sonar en el ciclo siguiente).
      await db.upsertNotified(quake('db-race-1', 4.0));

      final after = await db.byId('db-race-1');
      expect(after!.notified, 1);
    });

    test('el re-sync actualiza los datos (magnitud revisada) sin tocar el flag',
        () async {
      final db = LocalDb.instance;
      await db.upsertNotified(quake('db-rev-1', 4.0));
      await db.markNotified('db-rev-1');

      // USGS revisa la magnitud: 4.0 → 4.6.
      await db.upsertNotified(quake('db-rev-1', 4.6));

      final after = await db.byId('db-rev-1');
      expect(after!.magnitude, 4.6);
      expect(after.notified, 1);
    });

    test('markNotified(id, 0) permite re-armar un evento (Limpiar flag)',
        () async {
      final db = LocalDb.instance;
      await db.upsertNotified(quake('db-reset-1', 3.0));
      await db.markNotified('db-reset-1');
      await db.markNotified('db-reset-1', 0);
      expect((await db.byId('db-reset-1'))!.notified, 0);
    });
  },
      skip: sqliteOk ? null : 'libsqlite3 no disponible en este entorno');

  group('byIds', () {
    test('devuelve solo los eventos existentes, indexados por id', () async {
      final db = LocalDb.instance;
      await db.upsertNotified(quake('db-batch-a', 3.1));
      await db.upsertNotified(quake('db-batch-b', 3.2));

      final found = await db.byIds(['db-batch-a', 'db-batch-b', 'db-nope']);
      expect(found.keys, containsAll(['db-batch-a', 'db-batch-b']));
      expect(found.containsKey('db-nope'), isFalse);
    });

    test('maneja listas vacías', () async {
      final db = LocalDb.instance;
      expect(await db.byIds(const []), isEmpty);
    });
  },
      skip: sqliteOk ? null : 'libsqlite3 no disponible en este entorno');
}
