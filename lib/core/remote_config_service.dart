import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

/// Fetches feature flags from the `app_config` table in Supabase.
///
/// Fails open — if the fetch fails or Supabase is not configured, all flags
/// default to true so the app never degrades due to a config fetch failure.
///
/// To kill-switch a feature without a new app build, update the row in
/// Supabase: `update app_config set value = 'false' where key = 'leaderboard_enabled';`
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final ValueNotifier<Map<String, bool>> flags =
      ValueNotifier(const {'leaderboard_enabled': true});

  /// Fetches all flags from Supabase and updates [flags].
  /// Safe to call fire-and-forget on app start.
  Future<void> fetch() async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select('key, value');
      final rows = (response as List<dynamic>?) ?? [];

      final updated = Map<String, bool>.from(flags.value);
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'] as String?;
        if (key != null && value != null) {
          updated[key] = value.toLowerCase() == 'true';
        }
      }
      flags.value = updated;
      debugPrint('RemoteConfigService: fetched ${updated.length} flag(s)');
    } catch (e) {
      // Fail open — keep defaults.
      debugPrint('RemoteConfigService.fetch failed (using defaults): $e');
    }
  }

  bool get leaderboardEnabled => flags.value['leaderboard_enabled'] ?? true;
}
