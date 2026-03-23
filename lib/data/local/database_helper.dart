import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _dbName = 'hanuman_chalisa.db';
  static const _dbVersion = 1;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _applyMigrations(db, 0, version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _applyMigrations(db, oldVersion, newVersion);
  }

  Future<void> _applyMigrations(
      Database db, int fromVersion, int toVersion) async {
    for (var v = fromVersion + 1; v <= toVersion; v++) {
      await _migrations[v]!(db);
    }
  }

  static final Map<int, Future<void> Function(Database)> _migrations = {
    1: (db) async {
      await db.execute('''
        CREATE TABLE play_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          duration_seconds INTEGER NOT NULL DEFAULT 0,
          completed INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE daily_stats (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          completion_count INTEGER NOT NULL DEFAULT 0,
          total_play_seconds INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE user_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          theme_mode TEXT NOT NULL DEFAULT 'system',
          reminder_enabled INTEGER NOT NULL DEFAULT 0,
          reminder_time TEXT,
          selected_voice TEXT NOT NULL DEFAULT 'default'
        )
      ''');
      await db.execute('''
        CREATE TABLE recordings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_path TEXT NOT NULL,
          recorded_at TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL DEFAULT 0,
          label TEXT
        )
      ''');
    },
  };

  /// Exposed for testing — closes and deletes the database.
  Future<void> deleteForTesting() async {
    final path = join(await getDatabasesPath(), _dbName);
    await _db?.close();
    _db = null;
    await deleteDatabase(path);
  }
}
