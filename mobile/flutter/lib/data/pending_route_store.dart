import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class PendingRouteStore {
  PendingRouteStore._();

  static final PendingRouteStore instance = PendingRouteStore._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = path.join(
      await getDatabasesPath(),
      'mapasjw_routes.db',
    );
    _database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_route_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            congregation_id INTEGER NOT NULL,
            territory_id INTEGER NOT NULL,
            street_card_id INTEGER,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            recorded_at INTEGER NOT NULL,
            is_test INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX pending_route_scope_idx ON pending_route_points(user_id, congregation_id, territory_id, id)',
        );
        await db.execute(
          'CREATE INDEX pending_route_street_scope_idx ON pending_route_points(user_id, congregation_id, street_card_id, id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE pending_route_points ADD COLUMN is_test INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE pending_route_points ADD COLUMN street_card_id INTEGER',
          );
          await db.execute(
            'CREATE INDEX pending_route_street_scope_idx ON pending_route_points(user_id, congregation_id, street_card_id, id)',
          );
        }
      },
    );

    return _database!;
  }

  Future<void> insert(Map<String, Object?> point) async {
    await (await database).insert(
      'pending_route_points',
      point,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> pending({
    required int userId,
    required int congregationId,
    required int territoryId,
    int? streetCardId,
    int limit = 100,
  }) async {
    return (await database).query(
      'pending_route_points',
      where: streetCardId == null
          ? 'user_id = ? AND congregation_id = ? AND territory_id = ? AND street_card_id IS NULL'
          : 'user_id = ? AND congregation_id = ? AND territory_id = ? AND street_card_id = ?',
      whereArgs: streetCardId == null
          ? [userId, congregationId, territoryId]
          : [userId, congregationId, territoryId, streetCardId],
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<int> count({required int userId, required int congregationId}) async {
    final result = await (await database).rawQuery(
      'SELECT COUNT(*) AS total FROM pending_route_points WHERE user_id = ? AND congregation_id = ?',
      [userId, congregationId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteClientIds(List<String> clientIds) async {
    if (clientIds.isEmpty) return;
    final placeholders = List.filled(clientIds.length, '?').join(',');
    await (await database).delete(
      'pending_route_points',
      where: 'client_id IN ($placeholders)',
      whereArgs: clientIds,
    );
  }

  Future<void> clearForOtherUsers(int userId) async {
    await (await database).delete(
      'pending_route_points',
      where: 'user_id != ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearAll() async {
    await (await database).delete('pending_route_points');
  }

  Future<int> clearTestPoints({
    required int userId,
    required int congregationId,
    int? territoryId,
    int? streetCardId,
  }) async {
    if (streetCardId == null) {
      if (territoryId == null) return 0;

      return (await database).delete(
        'pending_route_points',
        where: 'user_id = ? AND congregation_id = ? AND territory_id = ? AND street_card_id IS NULL AND is_test = 1',
        whereArgs: [userId, congregationId, territoryId],
      );
    }

    return (await database).delete(
      'pending_route_points',
      where: 'user_id = ? AND congregation_id = ? AND street_card_id = ? AND is_test = 1',
      whereArgs: [userId, congregationId, streetCardId],
    );
  }
}
