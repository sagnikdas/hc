import '../local/database_helper.dart';
import '../models/user_settings.dart';

abstract interface class UserSettingsRepository {
  Future<UserSettings> get();
  Future<void> save(UserSettings settings);
}

class SqliteUserSettingsRepository implements UserSettingsRepository {
  final DatabaseHelper _db;
  SqliteUserSettingsRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<UserSettings> get() async {
    final database = await _db.database;
    final rows = await database.query('user_settings', limit: 1);
    if (rows.isEmpty) {
      const defaults = UserSettings();
      await save(defaults);
      return defaults;
    }
    return UserSettings.fromMap(rows.first);
  }

  @override
  Future<void> save(UserSettings settings) async {
    final database = await _db.database;
    if (settings.id == null) {
      await database.insert('user_settings', settings.toMap());
    } else {
      await database.update(
        'user_settings',
        settings.toMap(),
        where: 'id = ?',
        whereArgs: [settings.id],
      );
    }
  }
}
