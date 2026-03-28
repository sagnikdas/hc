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

AppRepository _freshRepo({bool signedIn = false}) {
  final path = join(Directory.systemTemp.path, 'hc_ext_${_uid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(
    isSignedIn: () => signedIn,
    syncCompletion: (_) async {},
  );
  return repo;
}

PlaySession _session(String date, {int count = 1, int? completedAtMs}) =>
    PlaySession(
      date: date,
      count: count,
      completedAt:
          completedAtMs ?? DateTime.parse(date).millisecondsSinceEpoch,
    );

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
    test('stores row retrievable via getRecentSessions', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 5));
      final sessions = await repo.getRecentSessions();
      expect(sessions, hasLength(1));
      expect(sessions.first.date, today);
      expect(sessions.first.count, 5);
    });

    test('multiple sessions all stored', () async {
      final repo = _freshRepo();
      final d1 = AppRepository.dateStr(DateTime.now());
      final d2 =
          AppRepository.dateStr(DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(d1, count: 2));
      await repo.insertSession(_session(d2, count: 3));
      expect(await repo.getAllSessions(), hasLength(2));
    });

    test('does not call sync when signed out', () async {
      int syncCalls = 0;
      final repo = _freshRepo(signedIn: false);
      repo.overrideSyncForTest(
        isSignedIn: () => false,
        syncCompletion: (_) async { syncCalls++; },
      );
      await repo.insertSession(_session(AppRepository.dateStr(DateTime.now())));
      expect(syncCalls, 0);
    });

    test('calls sync once when signed in and sync succeeds', () async {
      int syncCalls = 0;
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { syncCalls++; },
      );
      await repo.insertSession(_session(AppRepository.dateStr(DateTime.now())));
      expect(syncCalls, 1);
    });

    test('queues to pending_syncs when signed in and sync throws', () async {
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('network error'); },
      );
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 7));

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('pending_syncs');
      expect(rows, hasLength(1));
      expect(rows.first['count'], 7);
    });

    test('does not queue to pending_syncs when signed out and sync not called',
        () async {
      final repo = _freshRepo(signedIn: false);
      await repo.insertSession(_session(AppRepository.dateStr(DateTime.now())));

      final db = await DatabaseHelper.instance.database;
      expect(await db.query('pending_syncs'), isEmpty);
    });

    test('pending row preserves date and count', () async {
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('offline'); },
      );
      const date = '2025-06-15';
      await repo.insertSession(_session(date, count: 11));

      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('pending_syncs');
      expect(rows.first['date'], date);
      expect(rows.first['count'], 11);
    });
  });

  // ── flushPendingSyncs ──────────────────────────────────────────────────────

  group('flushPendingSyncs', () {
    test('is a no-op when not signed in', () async {
      int syncCalls = 0;
      final repo = _freshRepo(signedIn: false);
      repo.overrideSyncForTest(
        isSignedIn: () => false,
        syncCompletion: (_) async { syncCalls++; },
      );
      await repo.flushPendingSyncs();
      expect(syncCalls, 0);
    });

    test('is a no-op when pending_syncs is empty', () async {
      int syncCalls = 0;
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { syncCalls++; },
      );
      await repo.flushPendingSyncs();
      expect(syncCalls, 0);
    });

    test('flushes all pending rows and removes them on success', () async {
      // Seed two pending rows via failed insertSession.
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('offline'); },
      );
      final d1 = AppRepository.dateStr(DateTime.now());
      final d2 =
          AppRepository.dateStr(DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(d1, count: 1));
      await repo.insertSession(_session(d2, count: 2));

      final db = await DatabaseHelper.instance.database;
      expect(await db.query('pending_syncs'), hasLength(2));

      // Fix network and flush.
      final List<int> flushed = [];
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (s) async { flushed.add(s.count); },
      );
      await repo.flushPendingSyncs();

      expect(flushed, hasLength(2));
      expect(await db.query('pending_syncs'), isEmpty);
    });

    test('flushes rows in insertion order (ascending id)', () async {
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('offline'); },
      );
      // Insert in order: counts 10, 11, 12.
      for (int i = 0; i < 3; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: 10 + i));
      }

      final List<int> order = [];
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (s) async { order.add(s.count); },
      );
      await repo.flushPendingSyncs();
      expect(order, [10, 11, 12]);
    });

    test('stops at first failure and leaves remaining rows', () async {
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('offline'); },
      );
      final d1 = AppRepository.dateStr(DateTime.now());
      final d2 =
          AppRepository.dateStr(DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(d1, count: 3));
      await repo.insertSession(_session(d2, count: 4));

      int attempts = 0;
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async {
          attempts++;
          throw Exception('still offline');
        },
      );
      await repo.flushPendingSyncs();

      // Only the first row was attempted; both rows remain.
      expect(attempts, 1);
      final db = await DatabaseHelper.instance.database;
      expect(await db.query('pending_syncs'), hasLength(2));
    });

    test('concurrent second call is a no-op while first is running', () async {
      final repo = _freshRepo(signedIn: true);
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async { throw Exception('offline'); },
      );
      await repo.insertSession(
          _session(AppRepository.dateStr(DateTime.now()), count: 1));

      // Make the sync hang until released.
      final gate = Completer<void>();
      int syncCalls = 0;
      repo.overrideSyncForTest(
        isSignedIn: () => true,
        syncCompletion: (_) async {
          syncCalls++;
          await gate.future;
        },
      );

      final f1 = repo.flushPendingSyncs();
      final f2 = repo.flushPendingSyncs(); // should be a no-op (_flushing=true)
      gate.complete();
      await Future.wait([f1, f2]);

      expect(syncCalls, 1);
    });
  });

  // ── getCountsForLastDays ───────────────────────────────────────────────────

  group('getCountsForLastDays', () {
    test('returns empty map when DB is empty', () async {
      expect(await _freshRepo().getCountsForLastDays(7), isEmpty);
    });

    test('maps each date to its count within the window', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      final yesterday =
          AppRepository.dateStr(DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(today, count: 3));
      await repo.insertSession(_session(yesterday, count: 2));
      final result = await repo.getCountsForLastDays(7);
      expect(result[today], 3);
      expect(result[yesterday], 2);
    });

    test('sums multiple sessions on the same day', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 4));
      await repo.insertSession(_session(today, count: 6));
      final result = await repo.getCountsForLastDays(7);
      expect(result[today], 10);
    });

    test('excludes sessions outside the window', () async {
      final repo = _freshRepo();
      // 8 days ago is outside a 7-day window.
      final outside = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 8)));
      await repo.insertSession(_session(outside, count: 5));
      expect(await repo.getCountsForLastDays(7), isEmpty);
    });

    test('365-day window includes session from 364 days ago', () async {
      final repo = _freshRepo();
      final old = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 364)));
      await repo.insertSession(_session(old, count: 9));
      final result = await repo.getCountsForLastDays(365);
      expect(result[old], 9);
    });

    test('7-day window does not include session from 365 days ago', () async {
      final repo = _freshRepo();
      final old = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 365)));
      await repo.insertSession(_session(old, count: 1));
      expect(await repo.getCountsForLastDays(7), isEmpty);
    });
  });

  // ── getAllSessions ─────────────────────────────────────────────────────────

  group('getAllSessions', () {
    test('returns empty list when DB is empty', () async {
      expect(await _freshRepo().getAllSessions(), isEmpty);
    });

    test('returns all sessions when count is below default limit (50)', () async {
      final repo = _freshRepo();
      for (int i = 0; i < 5; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: i + 1));
      }
      expect(await repo.getAllSessions(), hasLength(5));
    });

    test('respects explicit limit', () async {
      final repo = _freshRepo();
      for (int i = 0; i < 5; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: i + 1));
      }
      expect(await repo.getAllSessions(limit: 3), hasLength(3));
    });

    test('offset paginates without overlap', () async {
      final repo = _freshRepo();
      for (int i = 0; i < 5; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: i + 1));
      }
      final page1 = await repo.getAllSessions(limit: 3, offset: 0);
      final page2 = await repo.getAllSessions(limit: 3, offset: 3);
      expect(page1, hasLength(3));
      expect(page2, hasLength(2));
      final dates1 = page1.map((s) => s.date).toSet();
      final dates2 = page2.map((s) => s.date).toSet();
      expect(dates1.intersection(dates2), isEmpty);
    });

    test('orders by completed_at DESC (most recent first)', () async {
      final repo = _freshRepo();
      final now = DateTime.now().millisecondsSinceEpoch;
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 1, completedAtMs: now - 10000));
      await repo.insertSession(_session(today, count: 2, completedAtMs: now));
      final result = await repo.getAllSessions();
      expect(result.first.count, 2);
      expect(result.last.count, 1);
    });
  });

  // ── getRecentSessions ─────────────────────────────────────────────────────

  group('getRecentSessions', () {
    test('returns empty list when DB is empty', () async {
      expect(await _freshRepo().getRecentSessions(), isEmpty);
    });

    test('default limit caps at 10 when more sessions exist', () async {
      final repo = _freshRepo();
      for (int i = 0; i < 15; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: 1));
      }
      expect(await repo.getRecentSessions(), hasLength(10));
    });

    test('custom limit is respected', () async {
      final repo = _freshRepo();
      for (int i = 0; i < 5; i++) {
        final d =
            AppRepository.dateStr(DateTime.now().subtract(Duration(days: i)));
        await repo.insertSession(_session(d, count: 1));
      }
      expect(await repo.getRecentSessions(limit: 3), hasLength(3));
    });

    test('returns fewer rows than limit when DB has fewer sessions', () async {
      final repo = _freshRepo();
      await repo.insertSession(_session(AppRepository.dateStr(DateTime.now())));
      expect(await repo.getRecentSessions(limit: 10), hasLength(1));
    });
  });

  // ── dateStr ───────────────────────────────────────────────────────────────

  group('dateStr', () {
    test('zero-pads single-digit month and day', () {
      expect(AppRepository.dateStr(DateTime(2024, 3, 5)), '2024-03-05');
    });

    test('does not pad double-digit month and day', () {
      expect(AppRepository.dateStr(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('zero-pads single-digit day with double-digit month', () {
      expect(AppRepository.dateStr(DateTime(2025, 10, 3)), '2025-10-03');
    });

    test('zero-pads single-digit month with double-digit day', () {
      expect(AppRepository.dateStr(DateTime(2025, 1, 19)), '2025-01-19');
    });

    test('handles year 2000', () {
      expect(AppRepository.dateStr(DateTime(2000, 1, 1)), '2000-01-01');
    });

    test('produces ISO-like YYYY-MM-DD format parseable by DateTime.parse', () {
      final d = DateTime(2026, 7, 4);
      final s = AppRepository.dateStr(d);
      final parsed = DateTime.parse(s);
      expect(parsed.year, 2026);
      expect(parsed.month, 7);
      expect(parsed.day, 4);
    });
  });

  // ── formatDate ────────────────────────────────────────────────────────────

  group('formatDate', () {
    test('January', () => expect(AppRepository.formatDate(DateTime(2025, 1, 1)), 'Jan 1, 2025'));
    test('February', () => expect(AppRepository.formatDate(DateTime(2025, 2, 14)), 'Feb 14, 2025'));
    test('March', () => expect(AppRepository.formatDate(DateTime(2025, 3, 20)), 'Mar 20, 2025'));
    test('April', () => expect(AppRepository.formatDate(DateTime(2025, 4, 5)), 'Apr 5, 2025'));
    test('May', () => expect(AppRepository.formatDate(DateTime(2025, 5, 31)), 'May 31, 2025'));
    test('June', () => expect(AppRepository.formatDate(DateTime(2025, 6, 15)), 'Jun 15, 2025'));
    test('July', () => expect(AppRepository.formatDate(DateTime(2025, 7, 4)), 'Jul 4, 2025'));
    test('August', () => expect(AppRepository.formatDate(DateTime(2025, 8, 19)), 'Aug 19, 2025'));
    test('September', () => expect(AppRepository.formatDate(DateTime(2025, 9, 10)), 'Sep 10, 2025'));
    test('October', () => expect(AppRepository.formatDate(DateTime(2025, 10, 28)), 'Oct 28, 2025'));
    test('November', () => expect(AppRepository.formatDate(DateTime(2025, 11, 11)), 'Nov 11, 2025'));
    test('December', () => expect(AppRepository.formatDate(DateTime(2025, 12, 25)), 'Dec 25, 2025'));

    test('day is not zero-padded', () {
      expect(AppRepository.formatDate(DateTime(2025, 3, 5)), 'Mar 5, 2025');
    });
  });

  // ── formatTime ────────────────────────────────────────────────────────────

  group('formatTime', () {
    int _ms(int hour, int minute) =>
        DateTime(2025, 1, 1, hour, minute).millisecondsSinceEpoch;

    test('midnight (00:00) → 12:00 AM', () {
      expect(AppRepository.formatTime(_ms(0, 0)), '12:00 AM');
    });

    test('noon (12:00) → 12:00 PM', () {
      expect(AppRepository.formatTime(_ms(12, 0)), '12:00 PM');
    });

    test('1 AM → 1:00 AM', () {
      expect(AppRepository.formatTime(_ms(1, 0)), '1:00 AM');
    });

    test('11:59 AM → 11:59 AM', () {
      expect(AppRepository.formatTime(_ms(11, 59)), '11:59 AM');
    });

    test('13:00 → 1:00 PM', () {
      expect(AppRepository.formatTime(_ms(13, 0)), '1:00 PM');
    });

    test('23:59 → 11:59 PM', () {
      expect(AppRepository.formatTime(_ms(23, 59)), '11:59 PM');
    });

    test('1:05 AM zero-pads minutes', () {
      expect(AppRepository.formatTime(_ms(1, 5)), '1:05 AM');
    });

    test('12:01 PM → 12:01 PM', () {
      expect(AppRepository.formatTime(_ms(12, 1)), '12:01 PM');
    });

    test('AM/PM boundary: 11:59 PM → PM', () {
      expect(AppRepository.formatTime(_ms(23, 59)).endsWith('PM'), isTrue);
    });

    test('AM/PM boundary: 12:00 AM (midnight) → AM', () {
      expect(AppRepository.formatTime(_ms(0, 0)).endsWith('AM'), isTrue);
    });
  });
}
