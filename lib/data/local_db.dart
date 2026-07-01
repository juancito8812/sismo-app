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
        if (oldVersion < 1) { /* schema v1 inicial */ }
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

  Future<List<Earthquake>> recent({int limit = 50}) async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'time DESC', limit: limit);
    return rows.map((r) => Earthquake(
      id: r['id'] as String,
      magnitude: (r['magnitude'] as num).toDouble(),
      place: r['place'] as String,
      time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      depthKm: (r['depth_km'] as num).toDouble(),
      source: r['source'] as String? ?? 'USGS',
      notified: (r['notified'] as int? ?? 0),
    )).toList();
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
    return rows.map((r) => Earthquake(
      id: r['id'] as String,
      magnitude: (r['magnitude'] as num).toDouble(),
      place: r['place'] as String,
      time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      depthKm: (r['depth_km'] as num).toDouble(),
      source: r['source'] as String? ?? 'USGS',
      notified: (r['notified'] as int? ?? 0),
    )).toList();
  }

  Future<int> unnotifiedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM events WHERE notified = 0',
    );
    return (result.first['count'] as int? ?? 0);
  }
}
