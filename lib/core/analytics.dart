abstract interface class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, dynamic>? params});
}

/// No-op implementation used until a real analytics SDK is wired in.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, dynamic>? params}) async {}
}

// Standard event names
const kEventPlayStarted = 'play_started';
const kEventPlayCompleted = 'play_completed';
const kEventPlayAbandoned = 'play_abandoned';
const kEventStreakMilestone = 'streak_milestone';
