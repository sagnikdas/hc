import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'auth_service.dart';
import 'date_utils.dart';
import 'streak_calculator.dart';
import '../data/models/cloud_stats.dart';
import '../data/repositories/daily_stat_repository.dart';

/// Pushes local progress (streak, total completions) to Supabase `user_stats`
/// and can restore it on a fresh install / new device.
///
/// Conflict strategy:
/// - Leaderboard counts are always server-authoritative (driven by listen_events).
/// - Streak and cumulative display counts use max(local, server) so progress
///   never appears to go backwards.
class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  final _repo = SqliteDailyStatRepository();

  SupabaseClient get _client => Supabase.instance.client;

  /// Reads local SQLite stats and pushes them to Supabase.
  /// Safe to call fire-and-forget after every completion.
  Future<void> syncStats() async {
    if (!AppConfig.isSupabaseConfigured) return;
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) return;

    try {
      final stats = await _buildLocalStats();
      await _client.from('user_stats').upsert(stats.toMap(userId));
      debugPrint(
        'CloudBackupService: pushed streak=${stats.currentStreak} '
        'best=${stats.bestStreak} total=${stats.cumulativeCompletions}',
      );
    } catch (e) {
      // Non-fatal — local data is the source of truth.
      debugPrint('CloudBackupService.syncStats failed: $e');
    }
  }

  /// Fetches the cloud backup for the current user.
  /// Returns null if unavailable (offline, unconfigured, no backup yet).
  Future<CloudStats?> pull() async {
    if (!AppConfig.isSupabaseConfigured) return null;
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) return null;

    try {
      final data = await _client
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return CloudStats.fromMap(data);
    } catch (e) {
      debugPrint('CloudBackupService.pull failed: $e');
      return null;
    }
  }

  /// Pulls cloud stats and reconciles with local using max() on each counter.
  /// Returns the merged result, or null if no cloud data is available.
  Future<CloudStats?> pullAndMerge() async {
    final cloud = await pull();
    if (cloud == null) return null;

    try {
      final local = await _buildLocalStats();
      return cloud.mergeWithLocal(
        localCurrentStreak: local.currentStreak,
        localBestStreak: local.bestStreak,
        localCumulativeCompletions: local.cumulativeCompletions,
      );
    } catch (e) {
      debugPrint('CloudBackupService.pullAndMerge local read failed: $e');
      return cloud;
    }
  }

  // ── Private ──────────────────────────────────────────────────────────────────

  Future<CloudStats> _buildLocalStats() async {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 364));
    final stats = await _repo.getRange(dateToDbString(from), dateToDbString(to));

    final activeDates = stats
        .where((s) => s.completionCount > 0)
        .map((s) => s.date)
        .toList();

    final currentStreak = StreakCalculator.currentStreak(activeDates, to);
    final bestStreak = StreakCalculator.bestStreak(activeDates);
    final total = stats.fold<int>(0, (sum, s) => sum + s.completionCount);

    return CloudStats(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      cumulativeCompletions: total,
    );
  }
}
