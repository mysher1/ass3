// lib/repositories/location_repository.dart
import '../db/app_database.dart';
import '../models/location_point.dart';

class LocationRepository {
  static const String _table = 'locations';

  Future<int> createPoint({
    required int userId,
    required double lat,
    required double lng,
    String? label,
  }) async {
    final db = await AppDatabase.instance.database;

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final p = LocationPoint(
      id: null,
      userId: userId,
      lat: lat,
      lng: lng,
      label: label?.trim().isEmpty == true ? null : label?.trim(),
      createdAt: nowUtc,
    );

    return db.insert(_table, p.toMap(), conflictAlgorithm: null);
  }

  Future<List<LocationPoint>> getPointsByUser(int userId) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      _table,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC, id DESC',
    );

    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<int> deletePoint({required int pointId, required int userId}) async {
    final db = await AppDatabase.instance.database;

    // safer: delete only the current user's point
    return db.delete(
      _table,
      where: 'id = ? AND userId = ?',
      whereArgs: [pointId, userId],
    );
  }

  Future<int> deleteAllPointsByUser(int userId) async {
    final db = await AppDatabase.instance.database;
    return db.delete(_table, where: 'userId = ?', whereArgs: [userId]);
  }

  Future<int> countPointsByUser(int userId) async {
    final db = await AppDatabase.instance.database;

    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE userId = ?',
      [userId],
    );

    final v = rows.first['cnt'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
