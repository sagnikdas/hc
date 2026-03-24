import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

abstract interface class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, dynamic>? params});
}

/// No-op implementation used until a real analytics SDK is wired in.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, dynamic>? params}) async {}
}

/// Writes analytics events to Supabase for simple conversion dashboards.
///
/// Fails silently so analytics never break devotional flow.
class SupabaseAnalyticsService implements AnalyticsService {
  const SupabaseAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, dynamic>? params}) async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('analytics_events').insert({
        'event_name': name,
        'user_id': userId,
        'event_params': params ?? <String, dynamic>{},
      });
    } catch (_) {
      // Non-fatal: analytics must never interrupt user flow or tests.
    }
  }
}

// Playback event names
const kEventPlayStarted = 'play_started';
const kEventPlayCompleted = 'play_completed';
const kEventPlayAbandoned = 'play_abandoned';
const kEventStreakMilestone = 'streak_milestone';

// Paywall event names
const kEventPaywallViewed = 'paywall_viewed';
const kEventPaywallClosed = 'paywall_closed';
const kEventTrialStarted = 'trial_started';
const kEventSubscriptionStarted = 'subscription_started';
const kEventSubscriptionCancelled = 'subscription_cancelled';
const kEventPremiumFeatureTapped = 'premium_feature_tapped';
