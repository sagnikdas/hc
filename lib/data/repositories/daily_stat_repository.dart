import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/daily_stat.dart';

abstract interface class DailyStatRepository {
  Future<DailyStat?> getByDate(String date); // 'YYYY-MM-DD'
  Future<void> upsert(DailyStat stat);
  Future<List<DailyStat>> getRange(String fromDate, String toDate);
}

class SqliteDailyStatRepository implements DailyStatRepository {
  final DatabaseHelper _db;
  SqliteDailyStatRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<DailyStat?> getByDate(String date) async {
    final database = await _db.database;
    final rows = await database
        .query('daily_stats', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    return DailyStat.fromMap(rows.first);
  }

  @override
  Future<void> upsert(DailyStat stat) async {
    final database = await _db.database;
    await database.insert(
      'daily_stats',
      stat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<DailyStat>> getRange(String fromDate, String toDate) async {
    final database = await _db.database;
    final rows = await database.query(
      'daily_stats',
      where: 'date >= ? AND date <= ?',
      whereArgs: [fromDate, toDate],
      orderBy: 'date ASC',
    );
    return rows.map(DailyStat.fromMap).toList();
  }
}
