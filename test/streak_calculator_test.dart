import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/streak_calculator.dart';

void main() {
  final today = DateTime(2024, 1, 20);

  group('StreakCalculator.currentStreak', () {
    test('returns 0 for empty list', () {
      expect(StreakCalculator.currentStreak([], today), 0);
    });

    test('returns 1 when only today is active', () {
      expect(StreakCalculator.currentStreak(['2024-01-20'], today), 1);
    });

    test('returns 1 when only yesterday is active', () {
      expect(StreakCalculator.currentStreak(['2024-01-19'], today), 1);
    });

    test('returns 0 when last active was 2 days ago', () {
      expect(StreakCalculator.currentStreak(['2024-01-18'], today), 0);
    });

    test('counts consecutive days correctly', () {
      final dates = ['2024-01-17', '2024-01-18', '2024-01-19', '2024-01-20'];
      expect(StreakCalculator.currentStreak(dates, today), 4);
    });

    test('stops at gap', () {
      final dates = ['2024-01-15', '2024-01-18', '2024-01-19', '2024-01-20'];
      expect(StreakCalculator.currentStreak(dates, today), 3);
    });
  });

  group('StreakCalculator.bestStreak', () {
    test('returns 0 for empty list', () {
      expect(StreakCalculator.bestStreak([]), 0);
    });

    test('returns 1 for single date', () {
      expect(StreakCalculator.bestStreak(['2024-01-20']), 1);
    });

    test('finds best run across a gap', () {
      final dates = [
        '2024-01-01',
        '2024-01-02',
        '2024-01-03', // run of 3
        '2024-01-10',
        '2024-01-11',
        '2024-01-12',
        '2024-01-13', // run of 4
      ];
      expect(StreakCalculator.bestStreak(dates), 4);
    });
  });
}
