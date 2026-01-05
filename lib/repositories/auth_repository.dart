// lib/repositories/auth_repository.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../services/audio_service.dart';

class AuthRepository {
  static const String _usersTable = 'users';
  static const String _memosTable = 'memos';

  static const String _prefCurrentUserId = 'currentUserId';
  static const String _prefCurrentUsername = 'currentUsername';

  /// Sign up: create a local account (SQLite users table)
  ///
  /// Returns the new user id
  Future<int> signup({
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    final u = username.trim();
    if (u.isEmpty) throw Exception('Invalid username');
    if (u.length < 3) throw Exception('Invalid username');
    if (u.length > 20) throw Exception('Invalid username');

    if (password.isEmpty || password.length < 6) {
      throw Exception('Invalid password');
    }
    if (password != confirmPassword) {
      throw Exception('Password not match');
    }

    final db = await AppDatabase.instance.database;

    // Check duplicate username
    final existed = await db.query(
      _usersTable,
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [u],
      limit: 1,
    );

    if (existed.isNotEmpty) {
      throw Exception('Username already exists');
    }

    final now = DateTime.now().toIso8601String();
    final passwordHash = _hash(password);

    final newId = await db.insert(_usersTable, {
      'username': u,
      'passwordHash': passwordHash,
      'createdAt': now,
    });

    return newId;
  }

  /// Login: verify username and password
  ///
  /// Returns userId on success; throws exception on failure
  Future<int> login({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    if (u.isEmpty) throw Exception('Invalid username');
    if (password.isEmpty) throw Exception('Invalid password');

    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      _usersTable,
      columns: ['id', 'username', 'passwordHash'],
      where: 'username = ?',
      whereArgs: [u],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('User not found');
    }

    final row = rows.first;
    final userId = row['id'] as int;
    final storedHash = row['passwordHash'] as String;

    final inputHash = _hash(password);
    if (inputHash != storedHash) {
      throw Exception('Wrong password');
    }

    // Persist login state
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_prefCurrentUserId, userId);
    await sp.setString(_prefCurrentUsername, u);

    return userId;
  }

  /// Sign out: clear locally stored login state
  Future<void> logout() async {
    // Stop background music when logging out
    try {
      await AudioService.instance.stop();
    } catch (_) {}

    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefCurrentUserId);
    await sp.remove(_prefCurrentUsername);

    // Extra safety: if an interruption happened during the first stop attempt,
    // try once more after state is cleared.
    try {
      await AudioService.instance.stop();
    } catch (_) {}
  }

  /// Get current logged-in user id
  Future<int?> getCurrentUserId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_prefCurrentUserId);
  }

  /// Get current logged-in username
  Future<String?> getCurrentUsername() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_prefCurrentUsername);
  }

  /// Delete account: remove all memos of the user + delete user record
  ///
  /// This action is irreversible
  Future<void> deleteAccount({required int userId}) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // 1) Delete all memos of the user
      await txn.delete(_memosTable, where: 'userId = ?', whereArgs: [userId]);

      // 2) Delete user record
      final deleted = await txn.delete(
        _usersTable,
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (deleted == 0) {
        throw Exception('User not found');
      }
    });

    // Clear login state
    await logout();
  }

  /// SHA-256 hash
  String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
