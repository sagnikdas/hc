import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/data/models/cloud_stats.dart';

void main() {
  // ── Multi-device conflict resolution ─────────────────────────────────────────

  group('CloudStats.mergeWithLocal — multi-device conflict strategy', () {
    test('server values win when higher than local', () {
      const cloud = CloudStats(
        currentStreak: 10,
        bestStreak: 25,
        cumulativeCompletions: 200,
      );
      final merged = cloud.mergeWithLocal(
        localCurrentStreak: 3,
        localBestStreak: 12,
        localCumulativeCompletions: 80,
      );
      expect(merged.currentStreak, 10);
      expect(merged.bestStreak, 25);
      expect(merged.cumulativeCompletions, 200);
    });

    test('local values win when higher than server', () {
      const cloud = CloudStats(
        currentStreak: 2,
        bestStreak: 7,
        cumulativeCompletions: 40,
      );
      final merged = cloud.mergeWithLocal(
        localCurrentStreak: 15,
        localBestStreak: 30,
        localCumulativeCompletions: 120,
      );
      expect(merged.currentStreak, 15);
      expect(merged.bestStreak, 30);
      expect(merged.cumulativeCompletions, 120);
    });

    test('each field resolved independently', () {
      // Server wins on streak, local wins on total.
      const cloud = CloudStats(
        currentStreak: 20,
        bestStreak: 5,
        cumulativeCompletions: 100,
      );
      final merged = cloud.mergeWithLocal(
        localCurrentStreak: 8,
        localBestStreak: 50,
        localCumulativeCompletions: 150,
      );
      expect(merged.currentStreak, 20);   // server wins
      expect(merged.bestStreak, 50);      // local wins
      expect(merged.cumulativeCompletions, 150); // local wins
    });

    test('counts never go backwards — equal values stay the same', () {
      const cloud = CloudStats(
        currentStreak: 5,
        bestStreak: 10,
        cumulativeCompletions: 50,
      );
      final merged = cloud.mergeWithLocal(
        localCurrentStreak: 5,
        localBestStreak: 10,
        localCumulativeCompletions: 50,
      );
      expect(merged.currentStreak, 5);
      expect(merged.bestStreak, 10);
      expect(merged.cumulativeCompletions, 50);
    });

    test('zero local values: server values are restored on fresh install', () {
      const cloud = CloudStats(
        currentStreak: 7,
        bestStreak: 21,
        cumulativeCompletions: 108,
      );
      final merged = cloud.mergeWithLocal(
        localCurrentStreak: 0,
        localBestStreak: 0,
        localCumulativeCompletions: 0,
      );
      expect(merged.currentStreak, 7);
      expect(merged.bestStreak, 21);
      expect(merged.cumulativeCompletions, 108);
    });
  });

  // ── fromMap / toMap roundtrip ─────────────────────────────────────────────

  group('CloudStats serialisation', () {
    test('fromMap parses all fields correctly', () {
      final map = {
        'current_streak': 3,
        'best_streak': 12,
        'cumulative_completions': 55,
        'updated_at': '2026-03-24T10:00:00.000Z',
      };
      final stats = CloudStats.fromMap(map);
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 12);
      expect(stats.cumulativeCompletions, 55);
      expect(stats.updatedAt, isNotNull);
    });

    test('toMap includes user_id and all counters', () {
      const stats = CloudStats(
        currentStreak: 4,
        bestStreak: 9,
        cumulativeCompletions: 33,
      );
      final map = stats.toMap('user-abc');
      expect(map['user_id'], 'user-abc');
      expect(map['current_streak'], 4);
      expect(map['best_streak'], 9);
      expect(map['cumulative_completions'], 33);
      expect(map['updated_at'], isNotNull);
    });
  });
}
