import '../local/database_helper.dart';
import '../models/entitlement.dart';

abstract interface class EntitlementRepository {
  /// Returns the current entitlement, or [Entitlement.free] if none is stored.
  Future<Entitlement> get();

  /// Persists the entitlement (upsert — only one row is kept).
  Future<void> save(Entitlement entitlement);
}

class SqliteEntitlementRepository implements EntitlementRepository {
  final DatabaseHelper _db;
  SqliteEntitlementRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  @override
  Future<Entitlement> get() async {
    final database = await _db.database;
    final rows = await database.query('entitlements', limit: 1);
    if (rows.isEmpty) return Entitlement.free;
    return Entitlement.fromMap(rows.first);
  }

  @override
  Future<void> save(Entitlement entitlement) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.delete('entitlements');
      await txn.insert('entitlements', entitlement.toMap());
    });
  }
}
