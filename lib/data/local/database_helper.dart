import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _db;

  DatabaseHelper._();
  static DatabaseHelper get instance => _instance ??= DatabaseHelper._();

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'hanuman_chalisa.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
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
        continuous_play INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('user_settings', {
      'id': 1,
      'target_count': 11,
      'haptic_enabled': 1,
      'continuous_play': 0,
    });
  }
}
