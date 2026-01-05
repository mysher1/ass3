// lib/repositories/memo_repository.dart
//
// SQLite repository for memos.
// - CRUD for memos
// - JOIN with locations to fetch location label in a single query
// - Paged loading for infinite scroll (LIMIT/OFFSET)

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/memo.dart';

class MemoRepository {
  final AppDatabase _db;

  /// Backward-compatible: allow zero-arg usage by defaulting to AppDatabase.instance.
  /// Also allow injecting a custom AppDatabase for tests.
  MemoRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  // ---------- Create / Update / Delete ----------

  /// Create a new memo (with optional locationId)
  Future<int> createMemo(Memo memo) async {
    final db = await _db.database;
    return db.insert(
      'memos',
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing memo
  Future<int> updateMemo(Memo memo) async {
    if (memo.id == null) {
      throw ArgumentError('Cannot update memo without id');
    }
    final db = await _db.database;
    return db.update(
      'memos',
      memo.toMap(),
      where: 'id = ?',
      whereArgs: [memo.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a memo by id
  Future<int> deleteMemo(int id) async {
    final db = await _db.database;
    return db.delete(
      'memos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Reads (with JOIN to locations) ----------

  /// Paged query used by HomePage infinite scroll.
  /// Includes locationLabel via LEFT JOIN.
  Future<List<Memo>> getMemosByUserPaged({
    required int userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _db.database;

    final result = await db.rawQuery('''
      SELECT 
        m.id,
        m.userId,
        m.title,
        m.content,
        m.updatedAt,
        m.locationId,
        l.label AS locationLabel
      FROM memos m
      LEFT JOIN locations l ON m.locationId = l.id
      WHERE m.userId = ?
      ORDER BY m.updatedAt DESC
      LIMIT ? OFFSET ?
    ''', [userId, limit, offset]);

    return result.map((row) => Memo.fromMap(row)).toList();
  }

  /// Convenience: fetch all memos for a user (still uses JOIN).
  Future<List<Memo>> getMemosByUser(int userId) async {
    // Use a very large limit; for very large data sets prefer getMemosByUserPaged.
    return getMemosByUserPaged(userId: userId, limit: 100000, offset: 0);
  }

  /// Get a single memo by id (JOIN to get locationLabel)
  Future<Memo?> getMemoById(int id) async {
    final db = await _db.database;

    final result = await db.rawQuery('''
      SELECT 
        m.id,
        m.userId,
        m.title,
        m.content,
        m.updatedAt,
        m.locationId,
        l.label AS locationLabel
      FROM memos m
      LEFT JOIN locations l ON m.locationId = l.id
      WHERE m.id = ?
      LIMIT 1
    ''', [id]);

    if (result.isEmpty) return null;
    return Memo.fromMap(result.first);
  }
}
