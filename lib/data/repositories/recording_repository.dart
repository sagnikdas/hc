import '../local/database_helper.dart';
import '../models/recording.dart';

abstract interface class RecordingRepository {
  Future<int> insert(Recording recording);
  Future<List<Recording>> getAll();
  Future<int> delete(int id);
}

class SqliteRecordingRepository implements RecordingRepository {
  final DatabaseHelper _db;
  SqliteRecordingRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<int> insert(Recording recording) async {
    final database = await _db.database;
    return database.insert('recordings', recording.toMap());
  }

  @override
  Future<List<Recording>> getAll() async {
    final database = await _db.database;
    final rows =
        await database.query('recordings', orderBy: 'recorded_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  @override
  Future<int> delete(int id) async {
    final database = await _db.database;
    return database.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }
}
