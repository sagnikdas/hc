import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/paywall_trigger.dart';

// Helpers
bool _check({
  bool isPremium = false,
  bool isPlaying = false,
  int dailyCompletions = 0,
  int totalCompletions = 0,
  DateTime? lastShownAt,
}) =>
    PaywallTrigger.shouldShow(
      isPremium: isPremium,
      isPlaying: isPlaying,
      dailyCompletions: dailyCompletions,
      totalCompletions: totalCompletions,
      lastShownAt: lastShownAt,
    );

void main() {
  group('PaywallTrigger.shouldShow', () {
    test('returns false for premium user', () {
      expect(_check(isPremium: true, dailyCompletions: 3), isFalse);
    });

    test('never shows during active playback', () {
      expect(_check(isPlaying: true, dailyCompletions: 3), isFalse);
    });

    test('triggers after 3rd daily completion', () {
      expect(_check(dailyCompletions: 3), isTrue);
    });

    test('does not trigger at 2 daily completions', () {
      expect(_check(dailyCompletions: 2), isFalse);
    });

    test('does not trigger at 4 daily completions (already past trigger)', () {
      expect(_check(dailyCompletions: 4), isFalse);
    });

    test('triggers at milestone 11', () {
      expect(_check(totalCompletions: 11), isTrue);
    });

    test('triggers at milestone 21', () {
      expect(_check(totalCompletions: 21), isTrue);
    });

    test('triggers at milestone 51', () {
      expect(_check(totalCompletions: 51), isTrue);
    });

    test('does not trigger at non-milestone total', () {
      expect(_check(totalCompletions: 10), isFalse);
      expect(_check(totalCompletions: 22), isFalse);
    });

    test('enforces daily cap — does not show twice on same day', () {
      final today = DateTime.now();
      expect(
        _check(dailyCompletions: 3, lastShownAt: today),
        isFalse,
      );
    });

    test('shows again the next calendar day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        _check(dailyCompletions: 3, lastShownAt: yesterday),
        isTrue,
      );
    });

    test('shows when lastShownAt is null (first time ever)', () {
      expect(_check(dailyCompletions: 3, lastShownAt: null), isTrue);
    });
  });

  group('PaywallTrigger.shouldShowForFeatureTap', () {
    test('returns true for free user not playing', () {
      expect(
        PaywallTrigger.shouldShowForFeatureTap(
            isPremium: false, isPlaying: false),
        isTrue,
      );
    });

    test('returns false if premium', () {
      expect(
        PaywallTrigger.shouldShowForFeatureTap(
            isPremium: true, isPlaying: false),
        isFalse,
      );
    });

    test('returns false if playing — never interrupt', () {
      expect(
        PaywallTrigger.shouldShowForFeatureTap(
            isPremium: false, isPlaying: true),
        isFalse,
      );
    });
  });
}
