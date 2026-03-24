import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'auth_service.dart';
import '../data/local/database_helper.dart';

/// Queues completion events locally and syncs them to the Supabase
/// `ingest-listen` edge function in the background.
///
/// Design goals:
/// - Works fully offline: events are persisted in SQLite until synced.
/// - Idempotent: `session_id` is the unique key; duplicate inserts are ignored
///   both locally (UNIQUE + ConflictAlgorithm.ignore) and on the server.
/// - Resilient: failed uploads increment `retry_count`; events are abandoned
///   after 6 failures to avoid infinite storms.
class EventSyncService {
  EventSyncService._();
  static final EventSyncService instance = EventSyncService._();

  final _db = DatabaseHelper.instance;

  /// Override in tests to bypass Supabase auth check.
  @visibleForTesting
  String? testUserId;

  /// Override in tests to replace the actual edge function call.
  @visibleForTesting
  Future<void> Function(Map<String, dynamic> body)? testSyncHandler;

  /// Persists a completion event locally and kicks off a sync attempt.
  /// [sessionId] must be stable and unique per play session (use started_at
  /// ISO string). Safe to call multiple times with the same id.
  Future<void> enqueue(String sessionId, DateTime completedAt) async {
    final db = await _db.database;
    await db.insert(
      'pending_sync_events',
      {
        'session_id': sessionId,
        'completed_at': completedAt.toUtc().toIso8601String(),
        'synced': 0,
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    unawaited(syncPending());
  }

  /// Uploads all unsynced events (up to 50 at a time) to the edge function.
  /// Called automatically after [enqueue] and on app resume.
  Future<void> syncPending() async {
    final userId = testUserId ??
        (AppConfig.isSupabaseConfigured
            ? SupabaseAuthService.instance.userId
            : null);
    if (userId == null) return;

    final db = await _db.database;
    final rows = await db.query(
      'pending_sync_events',
      where: 'synced = 0 AND retry_count < 6',
      orderBy: 'id ASC',
      limit: 50,
    );

    for (final row in rows) {
      final id = row['id'] as int;
      final sessionId = row['session_id'] as String;
      final completedAt = row['completed_at'] as String;

      try {
        final body = {
          'session_id': sessionId,
          'completed_at': completedAt,
          'source': 'app',
        };
        if (testSyncHandler != null) {
          await testSyncHandler!(body);
        } else {
          await Supabase.instance.client.functions
              .invoke('ingest-listen', body: body);
        }
        await db.update(
          'pending_sync_events',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        debugPrint('EventSyncService: synced $sessionId');
      } catch (e) {
        await db.rawUpdate(
          'UPDATE pending_sync_events SET retry_count = retry_count + 1 WHERE id = ?',
          [id],
        );
        debugPrint('EventSyncService: sync failed for $sessionId ($e) — will retry');
        // Stop processing this batch on network error; next app resume retries.
        break;
      }
    }
  }
}
