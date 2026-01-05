// lib/db/app_database.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'memo_app.db');

    // ✅ Bump DB version to support Locations + memo.locationId
    return openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enable FK constraints (recommended when using FOREIGN KEY)
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Called when the database is created for the first time
  Future<void> _onCreate(Database db, int version) async {
    // users table (accounts)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // locations table (for map feature)
    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        label TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id)
      )
    ''');

    // memos table (now supports optional locationId)
    await db.execute('''
      CREATE TABLE memos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        updatedAt TEXT NOT NULL,
        locationId INTEGER,
        FOREIGN KEY (userId) REFERENCES users(id),
        FOREIGN KEY (locationId) REFERENCES locations(id)
      )
    ''');

    // Helpful indexes (optional but good)
    await db.execute(
      'CREATE INDEX idx_memos_user_updated ON memos(userId, updatedAt)',
    );
    await db.execute(
      'CREATE INDEX idx_locations_user_created ON locations(userId, createdAt)',
    );
  }

  /// Handle schema upgrades for existing installs
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add locations table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          label TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (userId) REFERENCES users(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_locations_user_created ON locations(userId, createdAt)',
      );
    }

    // v2 -> v3: add locationId column to memos
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE memos ADD COLUMN locationId INTEGER;');
      // Existing rows will have NULL locationId (no location bound)
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_memos_user_updated ON memos(userId, updatedAt)',
      );
    }
  }

  /// Delete a user account safely by removing dependent rows first.
  /// This avoids FOREIGN KEY constraint failures even without ON DELETE CASCADE.
  Future<void> deleteUserAccount(int userId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete memos first (they may reference locations)
      await txn.delete(
        'memos',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Delete locations owned by this user
      await txn.delete(
        'locations',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Finally delete the user record
      await txn.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }
}
