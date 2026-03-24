import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hanuman_chalisa/core/event_sync_service.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.deleteForTesting();
    EventSyncService.instance.testUserId = 'test-user-123';
    EventSyncService.instance.testSyncHandler = null;
  });

  tearDown(() async {
    EventSyncService.instance.testUserId = null;
    EventSyncService.instance.testSyncHandler = null;
    await DatabaseHelper.instance.deleteForTesting();
  });

  // ── Local queue ──────────────────────────────────────────────────────────────

  group('enqueue', () {
    test('stores event locally with synced=0', () async {
      await EventSyncService.instance.enqueue('s-1', DateTime.now());
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('pending_sync_events');
      expect(rows.length, 1);
      expect(rows.first['session_id'], 's-1');
      expect(rows.first['synced'], 0);
      expect(rows.first['retry_count'], 0);
    });

    test('duplicate session_id is ignored (idempotent)', () async {
      await EventSyncService.instance.enqueue('s-1', DateTime.now());
      await EventSyncService.instance.enqueue('s-1', DateTime.now());
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('pending_sync_events');
      expect(rows.length, 1);
    });
  });

  // ── Offline → online sync with 500 queued events ──────────────────────────

  group('offline → online sync', () {
    test('processes 500 queued events across batches of 50', () async {
      final synced = <String>[];
      EventSyncService.instance.testSyncHandler = (body) async {
        synced.add(body['session_id'] as String);
      };

      // Insert 500 events directly (bypass enqueue trigger).
      final db = await DatabaseHelper.instance.database;
      final batch = db.batch();
      for (int i = 0; i < 500; i++) {
        batch.insert('pending_sync_events', {
          'session_id': 'session-$i',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'synced': 0,
          'retry_count': 0,
        });
      }
      await batch.commit(noResult: true);

      // 10 calls × 50 per batch = 500 total.
      for (int i = 0; i < 10; i++) {
        await EventSyncService.instance.syncPending();
      }

      expect(synced.length, 500);
      final unsyncedRows =
          await db.query('pending_sync_events', where: 'synced = 0');
      expect(unsyncedRows.length, 0);
    });

    test('already-synced events are not reprocessed', () async {
      int callCount = 0;
      EventSyncService.instance.testSyncHandler = (_) async => callCount++;

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_sync_events', {
        'session_id': 'already-done',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 1,
        'retry_count': 0,
      });

      await EventSyncService.instance.syncPending();
      expect(callCount, 0);
    });
  });

  // ── Auth bypass / network failure resilience ──────────────────────────────

  group('auth bypass and failure resilience', () {
    test('401 simulation: retry_count increments, event stays unsynced',
        () async {
      EventSyncService.instance.testSyncHandler = (_) async {
        throw Exception('401: invalid_token');
      };

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_sync_events', {
        'session_id': 'auth-test',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
        'retry_count': 0,
      });

      await EventSyncService.instance.syncPending();

      final rows = await db.query('pending_sync_events',
          where: "session_id = 'auth-test'");
      expect(rows.first['retry_count'], 1);
      expect(rows.first['synced'], 0);
    });

    test('event is abandoned after 6 failed retries', () async {
      EventSyncService.instance.testSyncHandler = (_) async {
        throw Exception('network error');
      };

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_sync_events', {
        'session_id': 'exhausted',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'synced': 0,
        'retry_count': 5, // one more failure pushes it to 6
      });

      await EventSyncService.instance.syncPending(); // fails → retry_count = 6

      int callCount = 0;
      EventSyncService.instance.testSyncHandler = (_) async => callCount++;
      await EventSyncService.instance.syncPending(); // should be skipped now

      expect(callCount, 0);
      final rows = await db.query('pending_sync_events',
          where: "session_id = 'exhausted'");
      expect(rows.first['retry_count'], 6);
      expect(rows.first['synced'], 0);
    });

    test('failure stops current batch but does not throw', () async {
      EventSyncService.instance.testSyncHandler = (_) async {
        throw Exception('server error');
      };

      final db = await DatabaseHelper.instance.database;
      for (int i = 0; i < 5; i++) {
        await db.insert('pending_sync_events', {
          'session_id': 'batch-$i',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
          'synced': 0,
          'retry_count': 0,
        });
      }

      // Should complete without throwing.
      await expectLater(
        EventSyncService.instance.syncPending(),
        completes,
      );

      // Only first event in batch gets retry_count incremented (batch stops).
      final rows = await db.query('pending_sync_events',
          orderBy: 'id ASC');
      expect(rows.first['retry_count'], 1);
      // Rest are untouched.
      for (final row in rows.skip(1)) {
        expect(row['retry_count'], 0);
      }
    });
  });
}
