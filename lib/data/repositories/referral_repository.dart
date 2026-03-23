import '../local/database_helper.dart';
import '../models/referral_info.dart';

abstract interface class ReferralRepository {
  /// Returns the stored referral info, or null if none exists yet.
  Future<ReferralInfo?> get();

  /// Persists referral info (upsert — only one row per device).
  Future<void> save(ReferralInfo info);
}

class SqliteReferralRepository implements ReferralRepository {
  final DatabaseHelper _db;
  SqliteReferralRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<ReferralInfo?> get() async {
    final database = await _db.database;
    final rows = await database.query('referral_info', limit: 1);
    if (rows.isEmpty) return null;
    return ReferralInfo.fromMap(rows.first);
  }

  @override
  Future<void> save(ReferralInfo info) async {
    final database = await _db.database;
    final existing = await database.query('referral_info', limit: 1);
    if (existing.isEmpty) {
      await database.insert('referral_info', info.toMap());
    } else {
      final id = existing.first['id'] as int;
      await database.update(
        'referral_info',
        info.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
