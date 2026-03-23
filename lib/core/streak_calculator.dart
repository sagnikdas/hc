/// Pure streak calculation from a sorted list of active dates ('YYYY-MM-DD').
class StreakCalculator {
  /// Current streak: consecutive days ending today (or yesterday if today has no entry).
  static int currentStreak(List<String> activeDates, DateTime today) {
    if (activeDates.isEmpty) return 0;
    final sorted = _sorted(activeDates);
    final todayStr = _fmt(today);
    final yesterdayStr = _fmt(today.subtract(const Duration(days: 1)));

    // Streak must end today or yesterday
    if (sorted.last != todayStr && sorted.last != yesterdayStr) return 0;

    int streak = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      final curr = DateTime.parse(sorted[i]);
      final prev = DateTime.parse(sorted[i - 1]);
      if (curr.difference(prev).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Best streak ever across the full history.
  static int bestStreak(List<String> activeDates) {
    if (activeDates.isEmpty) return 0;
    final sorted = _sorted(activeDates);
    int best = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  static List<String> _sorted(List<String> dates) =>
      [...dates]..sort();

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
