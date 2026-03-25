import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/play_session.dart';
import '../models/user_settings.dart';

class AppRepository {
  static AppRepository? _instance;
  static AppRepository get instance => _instance ??= AppRepository._();
  AppRepository._();

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<void> insertSession(PlaySession session) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('play_sessions', session.toMap());
  }

  Future<int> getTodayCount() async {
    final today = dateStr(DateTime.now());
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT SUM(count) as total FROM play_sessions WHERE date = ?',
      [today],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Returns a map of date strings to counts for the last [days] days.
  Future<Map<String, int>> getCountsForLastDays(int days) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = dateStr(DateTime.now().subtract(Duration(days: days)));
    final rows = await db.rawQuery(
      'SELECT date, SUM(count) as total FROM play_sessions WHERE date >= ? GROUP BY date',
      [cutoff],
    );
    return {for (final r in rows) r['date'] as String: (r['total'] as int?) ?? 0};
  }

  Future<int> getTotalSessionCount() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
        'SELECT SUM(count) as total FROM play_sessions');
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<List<PlaySession>> getAllSessions(
      {int limit = 50, int offset = 0}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'play_sessions',
      orderBy: 'completed_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(PlaySession.fromMap).toList();
  }

  Future<List<PlaySession>> getRecentSessions({int limit = 10}) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'play_sessions',
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return rows.map(PlaySession.fromMap).toList();
  }

  Future<({int current, int best})> getStreaks() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM play_sessions ORDER BY date DESC',
    );
    if (rows.isEmpty) return (current: 0, best: 0);

    final dates = rows
        .map((r) => DateTime.parse(r['date'] as String))
        .toList();

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Current streak: from most recent date backwards
    int current = 0;
    final gap = today.difference(dates.first).inDays;
    if (gap <= 1) {
      current = 1;
      for (int i = 0; i < dates.length - 1; i++) {
        if (dates[i].difference(dates[i + 1]).inDays == 1) {
          current++;
        } else {
          break;
        }
      }
    }

    // Best streak: longest consecutive run anywhere in history
    int best = dates.isEmpty ? 0 : 1;
    int run = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      if (dates[i].difference(dates[i + 1]).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }

    return (current: current, best: best);
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<UserSettings> getSettings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('user_settings', where: 'id = 1');
    if (rows.isEmpty) return const UserSettings();
    return UserSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(UserSettings settings) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'user_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String formatTime(int epochMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
