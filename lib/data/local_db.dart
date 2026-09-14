import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/earthquake.dart';

/// Versión del schema de la DB. Incrementar al agregar columnas/tablas.
const _dbVersion = 1;

class LocalDb {
  static final LocalDb _instance = LocalDb._();
  static LocalDb get instance => _instance;

  LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'sismos_ve.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            magnitude REAL,
            place TEXT,
            time INTEGER,
            latitude REAL,
            longitude REAL,
            depth_km REAL,
            source TEXT,
            notified INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Scaffold de migraciones futuras.
      },
      onOpen: (db) async {
        // Asegurar columna notified si la DB existía desde antes.
        final info = await db.rawQuery("PRAGMA table_info(events)");
        final hasNotified = info.any((c) => c['name'] == 'notified');
        if (!hasNotified) {
          await db.execute("ALTER TABLE events ADD COLUMN notified INTEGER DEFAULT 0");
        }
      },
    );
  }

  Future<void> insertOrUpdate(Earthquake event) async {
    final db = await database;
    await db.insert(
      'events',
      {
        'id': event.id,
        'magnitude': event.magnitude,
        'place': event.place,
        'time': event.time.millisecondsSinceEpoch,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'depth_km': event.depthKm,
        'source': event.source,
        'notified': event.notified,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearNotified() async {
    final db = await database;
    await db.update('events', {'notified': 0});
  }

  Future<void> markNotified(String id, [int value = 1]) async {
    final db = await database;
    await db.update('events', {'notified': value}, where: 'id = ?', whereArgs: [id]);
  }

  /// Upsert que preserva el flag [notified] existente: si el evento ya estaba
  /// en la DB conserva si fue notificado; solo eventos nuevos arrancan en 0.
  Future<void> upsertNotified(Earthquake event) async {
    final db = await database;
    final existing = await db.query(
      'events',
      columns: ['notified'],
      where: 'id = ?',
      whereArgs: [event.id],
      limit: 1,
    );
    final notified = existing.isNotEmpty
        ? (existing.first['notified'] as int? ?? 0)
        : event.notified;
    await db.insert(
      'events',
      {
        'id': event.id,
        'magnitude': event.magnitude,
        'place': event.place,
        'time': event.time.millisecondsSinceEpoch,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'depth_km': event.depthKm,
        'source': event.source,
        'notified': notified,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ids de eventos candidatos a alerta: no notificados y dentro de la
  /// ventana de frescura [maxAge].
  Future<Set<String>> pendingAlertIds({Duration maxAge = const Duration(hours: 6)}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    final rows = await db.query(
      'events',
      columns: ['id'],
      where: 'notified = 0 AND time >= ?',
      whereArgs: [cutoff],
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  /// Busca un evento por id (null si no existe). Usado por el push para la
  /// deduplicación cruzada contra lo ya notificado por el polling.
  Future<Earthquake?> byId(String id) async {
    final db = await database;
    final rows = await db.query('events', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToEarthquake(rows.first);
  }

  /// Busca varios eventos por id en una sola query. Devuelve un mapa
  /// id → evento con los que existan. Usado para comparar el feed contra
  /// el estado previo y detectar revisiones de USGS.
  Future<Map<String, Earthquake>> byIds(Iterable<String> ids) async {
    final db = await database;
    final out = <String, Earthquake>{};
    final idList = ids.toSet().toList();
    // SQLite tiene un límite de variables por query (~999); troceamos por
    // seguridad aunque el feed normalmente traiga ≤ 200 eventos.
    const chunkSize = 500;
    for (var i = 0; i < idList.length; i += chunkSize) {
      final chunk = idList.sublist(
        i,
        i + chunkSize > idList.length ? idList.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        'events',
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final r in rows) {
        final eq = _rowToEarthquake(r);
        out[eq.id] = eq;
      }
    }
    return out;
  }

  /// Poda eventos más viejos que [keep] para que la DB no crezca indefinida.
  Future<void> pruneOldEvents({Duration keep = const Duration(days: 90)}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(keep).millisecondsSinceEpoch;
    await db.delete('events', where: 'time < ?', whereArgs: [cutoff]);
  }

  /// Convierte una fila de la DB a [Earthquake].
  static Earthquake _rowToEarthquake(Map<String, dynamic> r) {
    return Earthquake(
      id: r['id'] as String,
      magnitude: (r['magnitude'] as num).toDouble(),
      place: r['place'] as String,
      time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      depthKm: (r['depth_km'] as num).toDouble(),
      source: r['source'] as String? ?? 'USGS',
      notified: (r['notified'] as int? ?? 0),
    );
  }

  Future<List<Earthquake>> recent({int limit = 50}) async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'time DESC', limit: limit);
    return rows.map(_rowToEarthquake).toList();
  }

  Future<List<Earthquake>> queryFiltered({
    int limit = 200,
    double? minMagnitude,
    int? sinceEpochMs,
    String? source,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (minMagnitude != null) {
      conditions.add('magnitude >= ?');
      args.add(minMagnitude);
    }
    if (sinceEpochMs != null) {
      conditions.add('time >= ?');
      args.add(sinceEpochMs);
    }
    if (source != null) {
      conditions.add('source = ?');
      args.add(source);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'events',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'time DESC',
      limit: limit,
    );
    return rows.map(_rowToEarthquake).toList();
  }

  Future<int> unnotifiedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM events WHERE notified = 0',
    );
    return (result.first['count'] as int? ?? 0);
  }

  /// Cantidad de eventos ocurridos desde [sinceEpochMs].
  Future<int> countSince({required int sinceEpochMs}) async {
    final db = await database;
    final result = await db.query(
      'events',
      columns: ['COUNT(*) AS count'],
      where: 'time >= ?',
      whereArgs: [sinceEpochMs],
    );
    return (result.first['count'] as int? ?? 0);
  }
}
