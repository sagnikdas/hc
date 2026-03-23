import '../local/database_helper.dart';
import '../models/play_session.dart';

abstract interface class PlaySessionRepository {
  Future<int> insert(PlaySession session);
  Future<PlaySession?> getById(int id);
  Future<List<PlaySession>> getByDate(String date); // 'YYYY-MM-DD'
  Future<int> update(PlaySession session);
}

class SqlitePlaySessionRepository implements PlaySessionRepository {
  final DatabaseHelper _db;
  SqlitePlaySessionRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<int> insert(PlaySession session) async {
    final database = await _db.database;
    return database.insert('play_sessions', session.toMap());
  }

  @override
  Future<PlaySession?> getById(int id) async {
    final database = await _db.database;
    final rows = await database
        .query('play_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PlaySession.fromMap(rows.first);
  }

  @override
  Future<List<PlaySession>> getByDate(String date) async {
    final database = await _db.database;
    final rows = await database.query(
      'play_sessions',
      where: "started_at LIKE ?",
      whereArgs: ['$date%'],
    );
    return rows.map(PlaySession.fromMap).toList();
  }

  @override
  Future<int> update(PlaySession session) async {
    final database = await _db.database;
    return database.update(
      'play_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }
}
