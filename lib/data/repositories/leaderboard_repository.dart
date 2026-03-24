import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Returns the top-10 list for [period].
  /// Returns an empty list if Supabase is unreachable or not configured.
  Future<List<LeaderboardEntry>> fetchTop10(LeaderboardPeriod period) async {
    if (!AppConfig.isSupabaseConfigured) return [];
    try {
      final rows = await _client.rpc(
        'leaderboard_top10',
        params: {
          'period': period == LeaderboardPeriod.weekly ? 'weekly' : 'all_time',
        },
      ) as List<dynamic>;
      return rows
          .map((r) => LeaderboardEntry.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('LeaderboardRepository.fetchTop10 failed: $e');
      return [];
    }
  }

  /// Returns the current user's rank, or null if not ranked / not in top list.
  Future<int?> fetchMyRank(String userId, LeaderboardPeriod period) async {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      final rows = await _client.rpc(
        'my_leaderboard_rank',
        params: {
          'uid': userId,
          'period': period == LeaderboardPeriod.weekly ? 'weekly' : 'all_time',
        },
      ) as List<dynamic>;
      if (rows.isEmpty) return null;
      final rank = rows.first['rank'];
      return rank != null ? (rank as num).toInt() : null;
    } catch (e) {
      debugPrint('LeaderboardRepository.fetchMyRank failed: $e');
      return null;
    }
  }
}
