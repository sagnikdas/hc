// ignore_for_file: avoid_relative_lib_imports
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

/// Returns a fresh isolated DB path and resets both singletons.
/// The Supabase sync seam is overridden so tests never touch the network.
AppRepository _freshRepo() {
  final path = join(
    Directory.systemTemp.path,
    'hc_test_${_uid++}.db',
  );
  // Clean up any leftover file from a previous run.
  final f = File(path);
  if (f.existsSync()) f.deleteSync();

  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(
    isSignedIn: () => false,
    syncCompletion: (_) async {},
  );
  return repo;
}

PlaySession _session(String date, {int count = 1}) => PlaySession(
      date: date,
      count: count,
      completedAt: DateTime.parse(date).millisecondsSinceEpoch,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── getTodayCount ──────────────────────────────────────────────────────────

  group('getTodayCount', () {
    test('returns 0 when no sessions exist', () async {
      final repo = _freshRepo();
      expect(await repo.getTodayCount(), 0);
    });

    test('returns count for today', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 3));
      expect(await repo.getTodayCount(), 3);
    });

    test('does not count sessions from other dates', () async {
      final repo = _freshRepo();
      final yesterday = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(yesterday, count: 5));
      expect(await repo.getTodayCount(), 0);
    });

    test('sums multiple sessions on the same day', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 2));
      await repo.insertSession(_session(today, count: 3));
      expect(await repo.getTodayCount(), 5);
    });
  });

  // ── getTotalSessionCount ──────────────────────────────────────────────────

  group('getTotalSessionCount', () {
    test('returns 0 with empty DB', () async {
      final repo = _freshRepo();
      expect(await repo.getTotalSessionCount(), 0);
    });

    test('sums all counts across all dates', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      final yesterday = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(today, count: 11));
      await repo.insertSession(_session(yesterday, count: 21));
      expect(await repo.getTotalSessionCount(), 32);
    });
  });

  // ── getStreaks ─────────────────────────────────────────────────────────────

  group('getStreaks', () {
    test('returns (0, 0) when no sessions', () async {
      final repo = _freshRepo();
      final s = await repo.getStreaks();
      expect(s.current, 0);
      expect(s.best, 0);
    });

    test('current = 1 when only today has a session', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today));
      final s = await repo.getStreaks();
      expect(s.current, 1);
      expect(s.best, 1);
    });

    test('current = 1 when only yesterday has a session', () async {
      final repo = _freshRepo();
      final yesterday = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(yesterday));
      final s = await repo.getStreaks();
      expect(s.current, 1); // gap ≤ 1, so streak is live
    });

    test('current = 2 when yesterday and today both have sessions', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      final yesterday = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 1)));
      await repo.insertSession(_session(today));
      await repo.insertSession(_session(yesterday));
      final s = await repo.getStreaks();
      expect(s.current, 2);
      expect(s.best, 2);
    });

    test('current = 0 when last session was 2+ days ago', () async {
      final repo = _freshRepo();
      final twoDaysAgo = AppRepository.dateStr(
          DateTime.now().subtract(const Duration(days: 2)));
      await repo.insertSession(_session(twoDaysAgo));
      final s = await repo.getStreaks();
      expect(s.current, 0);
    });

    test('best streak spans non-recent run', () async {
      final repo = _freshRepo();
      final now = DateTime.now();
      // 5-day consecutive run from 14 days ago.
      for (int i = 10; i <= 14; i++) {
        final d = AppRepository.dateStr(now.subtract(Duration(days: i)));
        await repo.insertSession(_session(d));
      }
      // Gap of 9 days, then today.
      final today = AppRepository.dateStr(now);
      await repo.insertSession(_session(today));

      final s = await repo.getStreaks();
      expect(s.best, 5);
      expect(s.current, 1);
    });

    test('multiple sessions on same day count as one streak day', () async {
      final repo = _freshRepo();
      final today = AppRepository.dateStr(DateTime.now());
      await repo.insertSession(_session(today, count: 3));
      await repo.insertSession(_session(today, count: 5));
      final s = await repo.getStreaks();
      // Only 1 distinct date.
      expect(s.current, 1);
      expect(s.best, 1);
    });

    test('3-day consecutive streak produces best = 3', () async {
      final repo = _freshRepo();
      final now = DateTime.now();
      for (int i = 0; i <= 2; i++) {
        final d = AppRepository.dateStr(now.subtract(Duration(days: i)));
        await repo.insertSession(_session(d));
      }
      final s = await repo.getStreaks();
      expect(s.current, 3);
      expect(s.best, 3);
    });
  });
}
