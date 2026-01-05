// lib/repositories/memo_repository.dart
//
// Handles CRUD operations for Memo objects.
// This version supports JOIN with locations to fetch location label in one query.

import '../models/memo.dart';
import '../db/app_database.dart';

import 'package:sqflite/sqflite.dart';

class MemoRepository {
  final AppDatabase _db;

  MemoRepository(this._db);

  /// Create a new memo (with optional locationId)
  Future<int> createMemo(Memo memo) async {
    final db = await _db.database;
    return await db.insert(
      'memos',
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing memo
  Future<int> updateMemo(Memo memo) async {
    final db = await _db.database;
    return await db.update(
      'memos',
      memo.toMap(),
      where: 'id = ?',
      whereArgs: [memo.id],
    );
  }

  /// Delete a memo by id
  Future<int> deleteMemo(int id) async {
    final db = await _db.database;
    return await db.delete('memos', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all memos for a user, including location label via LEFT JOIN
  Future<List<Memo>> getMemosByUser(int userId) async {
    final db = await _db.database;

    final result = await db.rawQuery(
      '''
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
    ''',
      [userId],
    );

    return result.map((row) => Memo.fromMap(row)).toList();
  }

  /// Get memos for a user in pages (LIMIT/OFFSET), including location label via LEFT JOIN.
  /// This matches HomePage's infinite scroll usage.
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

  /// Get a single memo by id (also joins location)
  Future<Memo?> getMemoById(int id) async {
    final db = await _db.database;

    final result = await db.rawQuery(
      '''
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
    ''',
      [id],
    );

    if (result.isEmpty) return null;
    return Memo.fromMap(result.first);
  }
}
