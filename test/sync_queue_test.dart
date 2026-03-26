// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/data/models/play_session.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _uid = 0;

/// Returns a fresh isolated DB and repo pair, signed out by default.
/// The sync seam is overridden to avoid touching Supabase (not init'd in tests).
AppRepository _freshRepo() {
  final path = join(Directory.systemTemp.path, 'hc_sync_test_${_uid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(
    isSignedIn: () => false,
    syncCompletion: (_) async =>
        throw StateError('syncCompletion must not be called when signed out'),
  );
  return repo;
}

/// Helper: repo that pretends a user is signed in.
/// [onSync] is called whenever syncCompletion is invoked.
AppRepository _signedInRepo({
  Future<void> Function(PlaySession)? onSync,
}) {
  final repo = _freshRepo();
  repo.overrideSyncForTest(
    isSignedIn: () => true,
    syncCompletion: onSync ?? (_) async {},
  );
  return repo;
}

PlaySession _session(String date, {int count = 1}) => PlaySession(
      date: date,
      count: count,
      completedAt: DateTime.parse(date).millisecondsSinceEpoch,
    );

Future<List<Map<String, dynamic>>> _pendingSyncs(AppRepository repo) async {
  final db = await DatabaseHelper.instance.database;
  return db.query('pending_syncs', orderBy: 'id ASC');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── insertSession ──────────────────────────────────────────────────────────

  group('insertSession', () {
    test('always writes to play_sessions regardless of auth state', () async {
      // Signed out.
      final repo = _freshRepo();
      await repo.insertSession(_session('2025-01-01'));
      expect(await repo.getTotalSessionCount(), 1);
    });

    test('does not touch pending_syncs when user is signed out', () async {
      final repo = _freshRepo();
      await repo.insertSession(_session('2025-01-01'));
      final pending = await _pendingSyncs(repo);
      expect(pending, isEmpty);
    });

    test('calls sync when user is signed in and network succeeds', () async {
      final synced = <PlaySession>[];
      final repo = _signedInRepo(onSync: (s) async => synced.add(s));

      await repo.insertSession(_session('2025-01-02'));

      expect(synced, hasLength(1));
      expect(synced.first.date, '2025-01-02');
    });

    test('does not write to pending_syncs when sync succeeds', () async {
      final repo = _signedInRepo(); // onSync is a no-op — always succeeds
      await repo.insertSession(_session('2025-01-03'));
      expect(await _pendingSyncs(repo), isEmpty);
    });

    test('writes to pending_syncs when sync throws (offline)', () async {
      final repo = _signedInRepo(onSync: (_) async => throw Exception('offline'));

      await repo.insertSession(_session('2025-01-04'));

      final pending = await _pendingSyncs(repo);
      expect(pending, hasLength(1));
    });

    test('pending_syncs row carries correct date, count, and completedAt',
        () async {
      final session = _session('2025-06-15', count: 3);
      final repo =
          _signedInRepo(onSync: (_) async => throw Exception('offline'));

      await repo.insertSession(session);

      final row = (await _pendingSyncs(repo)).first;
      expect(row['date'], '2025-06-15');
      expect(row['count'], 3);
      expect(row['completed_at'], session.completedAt);
    });

    test('queues multiple failures independently', () async {
      final repo =
          _signedInRepo(onSync: (_) async => throw Exception('offline'));

      await repo.insertSession(_session('2025-01-05'));
      await repo.insertSession(_session('2025-01-06'));
      await repo.insertSession(_session('2025-01-07'));

      expect(await _pendingSyncs(repo), hasLength(3));
    });
  });

  // ── flushPendingSyncs ──────────────────────────────────────────────────────

  group('flushPendingSyncs', () {
    test('is a no-op when user is signed out', () async {
      // Seed a pending row directly.
      final repo = _freshRepo();
      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_syncs', _session('2025-02-01').toMap()..remove('id'));

      // Even though a row exists, flush should not touch it.
      await repo.flushPendingSyncs();

      expect(await _pendingSyncs(repo), hasLength(1));
    });

    test('does nothing when pending_syncs is empty', () async {
      final synced = <PlaySession>[];
      final repo = _signedInRepo(onSync: (s) async => synced.add(s));

      await repo.flushPendingSyncs();

      expect(synced, isEmpty);
    });

    test('syncs all pending rows and clears them on success', () async {
      final synced = <String>[];
      final repo = _signedInRepo(onSync: (s) async => synced.add(s.date));

      // Directly insert 3 pending rows (simulating 3 offline completions).
      final db = await DatabaseHelper.instance.database;
      for (final date in ['2025-03-01', '2025-03-02', '2025-03-03']) {
        await db.insert('pending_syncs', {
          'date': date,
          'count': 1,
          'completed_at': DateTime.parse(date).millisecondsSinceEpoch,
        });
      }

      await repo.flushPendingSyncs();

      // All three were synced and the queue is empty.
      expect(synced, ['2025-03-01', '2025-03-02', '2025-03-03']);
      expect(await _pendingSyncs(repo), isEmpty);
    });

    test('stops at first failure and leaves remaining rows in queue', () async {
      int callCount = 0;
      final repo = _signedInRepo(onSync: (_) async {
        callCount++;
        if (callCount >= 2) throw Exception('offline');
      });

      final db = await DatabaseHelper.instance.database;
      for (final date in ['2025-04-01', '2025-04-02', '2025-04-03']) {
        await db.insert('pending_syncs', {
          'date': date,
          'count': 1,
          'completed_at': DateTime.parse(date).millisecondsSinceEpoch,
        });
      }

      await repo.flushPendingSyncs();

      // First row succeeded and was deleted; rows 2 and 3 remain.
      final remaining = await _pendingSyncs(repo);
      expect(remaining, hasLength(2));
      expect(remaining.first['date'], '2025-04-02');
      expect(remaining.last['date'], '2025-04-03');
    });

    test('clears only successfully synced rows, preserves failed ones', () async {
      // Rows: row1 succeeds, row2 fails → row2 stays in queue.
      bool failNext = false;
      final repo = _signedInRepo(onSync: (_) async {
        if (failNext) throw Exception('offline');
        failNext = true;
      });

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_syncs', {
        'date': '2025-05-01',
        'count': 1,
        'completed_at': DateTime.parse('2025-05-01').millisecondsSinceEpoch,
      });
      await db.insert('pending_syncs', {
        'date': '2025-05-02',
        'count': 1,
        'completed_at': DateTime.parse('2025-05-02').millisecondsSinceEpoch,
      });

      await repo.flushPendingSyncs();

      final remaining = await _pendingSyncs(repo);
      expect(remaining, hasLength(1));
      expect(remaining.first['date'], '2025-05-02');
    });

    test('processes rows in insertion order (FIFO)', () async {
      final syncOrder = <String>[];
      final repo = _signedInRepo(onSync: (s) async => syncOrder.add(s.date));

      final db = await DatabaseHelper.instance.database;
      // Insert in reverse-date order to confirm FIFO by id, not by date.
      for (final date in ['2025-06-03', '2025-06-01', '2025-06-02']) {
        await db.insert('pending_syncs', {
          'date': date,
          'count': 1,
          'completed_at': DateTime.parse(date).millisecondsSinceEpoch,
        });
      }

      await repo.flushPendingSyncs();

      expect(syncOrder, ['2025-06-03', '2025-06-01', '2025-06-02']);
    });
  });

  // ── Concurrency guard (_flushing) ──────────────────────────────────────────

  group('flushPendingSyncs concurrency guard', () {
    test('second concurrent call is a no-op while first is running', () async {
      // _flushing is set synchronously before the first await in flushPendingSyncs,
      // so the second call sees it immediately — no delayed yield needed.
      final gate = Completer<void>();
      int syncCallCount = 0;

      final repo = _signedInRepo(onSync: (_) async {
        syncCallCount++;
        await gate.future; // hold the first flush open
      });

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_syncs', {
        'date': '2025-07-01',
        'count': 1,
        'completed_at': DateTime.parse('2025-07-01').millisecondsSinceEpoch,
      });

      // Start first flush without awaiting — _flushing becomes true synchronously.
      final first = repo.flushPendingSyncs();

      // Start second flush without awaiting — should be a no-op.
      final second = repo.flushPendingSyncs();

      // Release the gate so both can complete.
      gate.complete();
      await Future.wait([first, second]);

      // sync was called exactly once despite two concurrent flush calls.
      expect(syncCallCount, 1);
    });

    test('second call proceeds normally after first flush completes', () async {
      final synced = <String>[];
      final repo = _signedInRepo(onSync: (s) async => synced.add(s.date));

      final db = await DatabaseHelper.instance.database;
      await db.insert('pending_syncs', {
        'date': '2025-08-01',
        'count': 1,
        'completed_at': DateTime.parse('2025-08-01').millisecondsSinceEpoch,
      });

      await repo.flushPendingSyncs(); // first flush — syncs row, clears it

      // Insert a new row for the second flush.
      await db.insert('pending_syncs', {
        'date': '2025-08-02',
        'count': 1,
        'completed_at': DateTime.parse('2025-08-02').millisecondsSinceEpoch,
      });

      await repo.flushPendingSyncs(); // second flush — should work normally

      expect(synced, ['2025-08-01', '2025-08-02']);
      expect(await _pendingSyncs(repo), isEmpty);
    });
  });

  // ── Round-trip: offline → queue → flush ────────────────────────────────────

  group('end-to-end offline → queue → flush', () {
    test('session completed offline is eventually synced after coming online',
        () async {
      // Phase 1: offline — sync throws.
      final synced = <String>[];
      bool isOnline = false;

      final repo = _signedInRepo(onSync: (s) async {
        if (!isOnline) throw Exception('offline');
        synced.add(s.date);
      });

      await repo.insertSession(_session('2025-09-01'));

      // Session is in play_sessions, and queued in pending_syncs.
      expect(await repo.getTotalSessionCount(), 1);
      expect(await _pendingSyncs(repo), hasLength(1));
      expect(synced, isEmpty);

      // Phase 2: come online and flush.
      isOnline = true;
      await repo.flushPendingSyncs();

      expect(synced, ['2025-09-01']);
      expect(await _pendingSyncs(repo), isEmpty);
    });

    test('multiple offline completions all reach Supabase after flush', () async {
      bool isOnline = false;
      final synced = <String>[];

      final repo = _signedInRepo(onSync: (s) async {
        if (!isOnline) throw Exception('offline');
        synced.add(s.date);
      });

      for (final d in ['2025-10-01', '2025-10-02', '2025-10-03']) {
        await repo.insertSession(_session(d));
      }

      expect(await _pendingSyncs(repo), hasLength(3));
      expect(synced, isEmpty);

      isOnline = true;
      await repo.flushPendingSyncs();

      expect(synced, hasLength(3));
      expect(await _pendingSyncs(repo), isEmpty);
    });
  });
}
