// lib/repositories/location_repository.dart
//
// Location repository (SQLite).
//
// This version is deliberately BACKWARD-COMPATIBLE with multiple MapPage variants.
//
// It supports BOTH styles:
//
// A) Newer API (object-based):
//   - createLocation(LocationPoint point)
//   - getLocationsByUser(int userId)
//   - deleteLocation(int id)
//
// B) Older/alternate API used by some MapPage implementations:
//   - LocationRepository() with NO args
//   - getPointsByUser(int userId)
//   - createPoint({required int userId, required double lat, required double lng, required String label})
//     (Some code may pass label as String?; adjust in MapPage if needed.)
//   - deletePoint({required int pointId, required int userId})
//
// Why this file exists:
// - Your app_database.dart defines locations columns as: userId, label, latitude, longitude, createdAt.
// - Some older MapPage code creates points by passing primitive args (userId/lat/lng/label).
// - Newer code passes a LocationPoint object.

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/location_point.dart';

class LocationRepository {
  final AppDatabase _db;

  /// Preferred: pass AppDatabase (useful for testing)
  /// Backward-compatible: allow zero-arg constructor which uses AppDatabase.instance
  LocationRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  // ---------- New API (object-based) ----------

  Future<int> createLocation(LocationPoint point) async {
    final db = await _db.database;
    return await db.insert(
      'locations',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationPoint>> getLocationsByUser(int userId) async {
    final db = await _db.database;
    final result = await db.query(
      'locations',
      where: 'userId = ?',
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
    return await db.delete(
      'locations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Compatibility API (primitive-arg based) ----------

  /// Alias used by some MapPage code: fetch user's saved points
  Future<List<LocationPoint>> getPointsByUser(int userId) =>
      getLocationsByUser(userId);

  /// Some MapPage code calls createPoint with named parameters rather than a LocationPoint.
  /// We create a LocationPoint internally and save it.
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

  /// Some MapPage code calls deletePoint(pointId: ..., userId: ...)
  /// userId is not needed for deletion; we keep it for compatibility.
  Future<int> deletePoint({
    required int pointId,
    required int userId,
  }) async {
    return deleteLocation(pointId);
  }
}
