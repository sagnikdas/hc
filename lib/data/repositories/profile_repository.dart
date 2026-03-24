import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  /// Returns the profile for [userId], or null if not yet created.
  Future<UserProfile?> get(String userId);

  /// Upserts the profile. Creates it on first call.
  Future<void> save(UserProfile profile);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserProfile?> get(String userId) async {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    } catch (e) {
      debugPrint('ProfileRepository.get failed: $e');
      return null;
    }
  }

  @override
  Future<void> save(UserProfile profile) async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      await _client.from('profiles').upsert(profile.toMap());
    } catch (e) {
      debugPrint('ProfileRepository.save failed: $e');
    }
  }
}
