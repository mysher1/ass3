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

    return openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 启用外键约束
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 1. 用户表
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // 2. 地理位置表
    // 修改点：在外键处增加了 ON DELETE CASCADE
    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        label TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 3. 备忘录表
    // 修改点：为 userId 增加了 ON DELETE CASCADE
    // 修改点：为 locationId 增加了 ON DELETE SET NULL (防止删除位置时误删备忘录)
    await db.execute('''
      CREATE TABLE memos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        updatedAt TEXT NOT NULL,
        locationId INTEGER,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (locationId) REFERENCES locations(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_memos_user_updated ON memos(userId, updatedAt)',
    );
    await db.execute(
      'CREATE INDEX idx_locations_user_created ON locations(userId, createdAt)',
    );
  }

  /// 处理版本升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          label TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      // 检查列是否存在，防止重复添加
      var columns = await db.rawQuery('PRAGMA table_info(memos)');
      bool columnExists =
          columns.any((column) => column['name'] == 'locationId');

      if (!columnExists) {
        await db.execute('ALTER TABLE memos ADD COLUMN locationId INTEGER;');
      }

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_memos_user_updated ON memos(userId, updatedAt)',
      );
    }
  }
}
