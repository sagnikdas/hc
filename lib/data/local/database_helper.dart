import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static DatabaseHelper _instance = DatabaseHelper._();
  static DatabaseHelper get instance => _instance;
  DatabaseHelper._();

  // Overridden to a temp path in unit tests via [resetForTest].
  static String? _testPath;

  /// Call before each test to get a fresh, isolated database.
  @visibleForTesting
  static void resetForTest(String path) {
    _testPath = path;
    _instance = DatabaseHelper._();
  }

  // late final ensures _open() is called exactly once per instance.
  late final Future<Database> _db = _open();

  Future<Database> get database => _db;

  Future<Database> _open() async {
    final path = _testPath ??
        join(await getDatabasesPath(), 'hanuman_chalisa.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE play_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        completed_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY,
        target_count INTEGER NOT NULL DEFAULT 11,
        haptic_enabled INTEGER NOT NULL DEFAULT 1,
        continuous_play INTEGER NOT NULL DEFAULT 0,
        referral_code TEXT,
        onboarding_shown INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('user_settings', {
      'id': 1,
      'target_count': 11,
      'haptic_enabled': 1,
      'continuous_play': 0,
      'referral_code': null,
      'onboarding_shown': 0,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE user_settings ADD COLUMN referral_code TEXT',
      );
      await db.execute(
        'ALTER TABLE user_settings ADD COLUMN onboarding_shown INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
}
