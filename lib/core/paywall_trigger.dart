import 'package:flutter/material.dart' show DateUtils;

/// Milestone totals at which the paywall is shown (post-completion).
const kMilestoneCompletions = {11, 21, 51};

/// Daily completion count that triggers a proactive paywall impression.
const kDailyCompletionTrigger = 3;

/// Pure logic: decides whether to show a proactive paywall impression.
///
/// All state is passed in so this class is easily unit-testable and has no
/// side-effects.
class PaywallTrigger {
  const PaywallTrigger._();

  /// Returns true when the app should show the paywall proactively.
  ///
  /// Rules (all must hold):
  /// 1. User is not premium.
  /// 2. Audio is not currently playing — never interrupt chanting.
  /// 3. At most 1 proactive impression per calendar day (hard cap).
  /// 4. A high-intent moment has occurred:
  ///    - [dailyCompletions] just reached [kDailyCompletionTrigger], or
  ///    - [totalCompletions] is a milestone (11 / 21 / 51).
  static bool shouldShow({
    required bool isPremium,
    required bool isPlaying,
    required int dailyCompletions,
    required int totalCompletions,
    DateTime? lastShownAt,
  }) {
    if (isPremium) return false;
    if (isPlaying) return false;
    if (_shownTodayAlready(lastShownAt)) return false;

    return dailyCompletions == kDailyCompletionTrigger ||
        kMilestoneCompletions.contains(totalCompletions);
  }

  /// Returns true when a premium-feature tap should show the paywall.
  ///
  /// Unlike [shouldShow], this is *intent-driven* and ignores the daily cap
  /// — the user explicitly tapped a locked feature.
  static bool shouldShowForFeatureTap({
    required bool isPremium,
    required bool isPlaying,
  }) {
    if (isPremium) return false;
    if (isPlaying) return false;
    return true;
  }

  static bool _shownTodayAlready(DateTime? lastShownAt) {
    if (lastShownAt == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDay = DateUtils.dateOnly(lastShownAt);
    return today == lastDay;
  }
}
