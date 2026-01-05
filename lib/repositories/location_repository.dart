// lib/repositories/location_repository.dart
//
// SQLite repository for the `locations` table.
//
// DB columns (from app_database.dart):
//   id, userId, label, latitude, longitude, createdAt
//
// This repository intentionally supports multiple calling styles because
// different pages in your project use different method signatures.
//
// Supported APIs:
//
// 1) Object-based (recommended):
//   - createLocation(LocationPoint point)
//   - getLocationsByUser(int userId)
//   - deleteLocation(int id)
//
// 2) Primitive-arg compatibility (used by some MapPage versions):
//   - LocationRepository() with NO args
//   - getPointsByUser(int userId)
//   - createPoint({required int userId, required double lat, required double lng, required String label})
//   - deletePoint({required int pointId, required int userId})

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/location_point.dart';

class LocationRepository {
  final AppDatabase _db;

  /// Backward-compatible: allow zero-arg constructor (uses singleton).
  /// Also allow passing a custom AppDatabase for tests.
  LocationRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  // ---------- Recommended (object-based) ----------

  Future<int> createLocation(LocationPoint point) async {
    final db = await _db.database;
    return db.insert(
      'locations',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationPoint>> getLocationsByUser(int userId) async {
    final db = await _db.database;

    // Avoid old/invalid rows where latitude/longitude might be NULL (pre-migration data).
    final result = await db.query(
      'locations',
      where: 'userId = ? AND latitude IS NOT NULL AND longitude IS NOT NULL',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return result.map((row) => LocationPoint.fromMap(row)).toList();
  }

  Future<LocationPoint?> getLocationById(int id) async {
    final db = await _db.database;
    final result = await db.query(
      'locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return LocationPoint.fromMap(result.first);
  }

  Future<int> deleteLocation(int id) async {
    final db = await _db.database;
    return db.delete(
      'locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Compatibility (primitive-arg based) ----------

  Future<List<LocationPoint>> getPointsByUser(int userId) =>
      getLocationsByUser(userId);

  Future<int> createPoint({
    required int userId,
    required double lat,
    required double lng,
    required String label,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final point = LocationPoint(
      id: null,
      userId: userId,
      lat: lat,
      lng: lng,
      label: label,
      createdAt: now,
    );
    return createLocation(point);
  }

  Future<int> deletePoint({
    required int pointId,
    required int userId,
  }) async {
    final db = await _db.database;
    return db.delete(
      'locations',
      where: 'id = ? AND userId = ?',
      whereArgs: [pointId, userId],
    );
  }
}
