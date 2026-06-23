import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/collection_record.dart';

/// Offline-first local storage. Every collection record is written here
/// the instant it's confirmed on Screen 2 — the app never depends on
/// network availability during the trip. Screen 3's "Sync to server"
/// reads everything from here and pushes it to the backend in one batch.
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'glass_collector_local.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE collection_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            trip_stop_id INTEGER NOT NULL,
            supplier_code TEXT NOT NULL,
            clear_kg REAL NOT NULL,
            coloured_kg REAL NOT NULL,
            condition TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Saves a collection record locally. Called immediately on confirmation
  /// in Screen 2, regardless of connectivity.
  Future<int> insertRecord(CollectionRecord record) async {
    final db = await database;
    return db.insert('collection_records', record.toMap()
      ..remove('id')); // let autoincrement handle id
  }

  Future<List<CollectionRecord>> getRecordsForTrip(int tripId) async {
    final db = await database;
    final rows = await db.query(
      'collection_records',
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
    return rows.map(CollectionRecord.fromMap).toList();
  }

  Future<List<CollectionRecord>> getUnsyncedRecords(int tripId) async {
    final db = await database;
    final rows = await db.query(
      'collection_records',
      where: 'trip_id = ? AND synced = 0',
      whereArgs: [tripId],
    );
    return rows.map(CollectionRecord.fromMap).toList();
  }

  Future<void> markSynced(int recordId) async {
    final db = await database;
    await db.update(
      'collection_records',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('collection_records');
  }
}
