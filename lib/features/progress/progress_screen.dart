import 'package:flutter/material.dart';
import '../../core/date_utils.dart';
import '../../core/streak_calculator.dart';
import '../../core/auth_service.dart';
import '../../core/remote_config_service.dart';
import '../../main.dart';
import '../../data/models/daily_stat.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/repositories/daily_stat_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../paywall/paywall_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _repo = SqliteDailyStatRepository();

  List<DailyStat> _stats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final to = DateTime.now();
      final from = to.subtract(const Duration(days: 364));
      final stats = await _repo.getRange(dateToDbString(from), dateToDbString(to));
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      debugPrint('ProgressScreen._load failed: $e');
      if (mounted) setState(() { _loading = false; _error = 'Could not load your progress. Pull down to retry.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(_error!, textAlign: TextAlign.center)),
              ),
            ],
          ),
        ),
      );
    }

    final activeDates = _stats
        .where((s) => s.completionCount > 0)
        .map((s) => s.date)
        .toList();

    final today = DateTime.now();
    final localCurrent = StreakCalculator.currentStreak(activeDates, today);
    final localBest = StreakCalculator.bestStreak(activeDates);
    final localTotal =
        _stats.fold<int>(0, (sum, s) => sum + s.completionCount);

    // Use cloud backup values if they're higher (handles multi-device / restore).
    final cloud = cloudStatsNotifier.value;
    final current =
        cloud != null && cloud.currentStreak > localCurrent ? cloud.currentStreak : localCurrent;
    final best =
        cloud != null && cloud.bestStreak > localBest ? cloud.bestStreak : localBest;
    final totalCompletions =
        cloud != null && cloud.cumulativeCompletions > localTotal ? cloud.cumulativeCompletions : localTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsRow(current: current, best: best, total: totalCompletions),
            const SizedBox(height: 24),
            Text('Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _Heatmap(stats: _stats),
            const SizedBox(height: 24),
            _WeeklySummary(
              stats: _stats,
              today: today,
              totalCompletions: totalCompletions,
            ),
            ValueListenableBuilder(
              valueListenable: RemoteConfigService.instance.flags,
              builder: (context, flags, _) {
                if (!(flags['leaderboard_enabled'] ?? true)) {
                  return const SizedBox.shrink();
                }
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 24),
                    _LeaderboardSection(),
                    SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int current;
  final int best;
  final int total;
  const _StatsRow(
      {required this.current, required this.best, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Current\nStreak', value: '$current 🔥'),
        const SizedBox(width: 12),
        _StatCard(label: 'Best\nStreak', value: '$best ⭐'),
        const SizedBox(width: 12),
        _StatCard(label: 'Total\nCompletions', value: '$total'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: colors.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  final List<DailyStat> stats;
  const _Heatmap({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final map = {for (final s in stats) s.date: s.completionCount};

    // Show last 10 weeks (70 days), aligned to Mon-Sun columns
    final today = DateTime.now();
    final startOffset = today.weekday - 1; // days since last Monday
    final startDay = today.subtract(Duration(days: startOffset + 63)); // 10 weeks back

    final weeks = <List<DateTime>>[];
    var cursor = startDay;
    for (int w = 0; w < 10; w++) {
      final week = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        week.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return SizedBox(
      height: 100,
      child: Row(
        children: weeks.map((week) {
          return Expanded(
            child: Column(
              children: week.map((day) {
                final key = dateToDbString(day);
                final count = map[key] ?? 0;
                final opacity = count == 0
                    ? 0.08
                    : (count >= 3 ? 1.0 : 0.3 + count * 0.2);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Weekly summary ────────────────────────────────────────────────────────────

class _WeeklySummary extends StatelessWidget {
  final List<DailyStat> stats;
  final DateTime today;
  final int totalCompletions;
  const _WeeklySummary({
    required this.stats,
    required this.today,
    required this.totalCompletions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weekStats = stats.where((s) {
      final d = DateTime.parse(s.date);
      return !d.isBefore(startOfWeek) && !d.isAfter(today);
    }).toList();

    final weekCompletions =
        weekStats.fold<int>(0, (s, e) => s + e.completionCount);
    final activeDays = weekStats.where((s) => s.completionCount > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '$weekCompletions completions · $activeDays active days',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          // Weekly reflection paywall CTA — shown only to free users.
          ValueListenableBuilder(
            valueListenable: entitlementNotifier,
            builder: (context, entitlement, _) {
              if (entitlement.isActive) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'You completed $weekCompletions recitations this week — '
                    'go deeper with Premium.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showPaywall(
                      context,
                      variant: PaywallVariant.milestone,
                      completionCount: totalCompletions,
                    ),
                    icon: const Icon(Icons.workspace_premium, size: 18),
                    label: const Text('Unlock Premium Insights'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard section ────────────────────────────────────────────────────────

class _LeaderboardSection extends StatefulWidget {
  const _LeaderboardSection();

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  final _repo = LeaderboardRepository();
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;
  List<LeaderboardEntry> _entries = [];
  int? _myRank;
  bool _loading = true;
  bool _unavailable = false;
  bool _fetchError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() { _loading = true; _unavailable = false; _fetchError = false; });
    try {
      final entries = await _repo.fetchTop10(_period);
      final userId = SupabaseAuthService.instance.userId;
      final myRank =
          userId != null ? await _repo.fetchMyRank(userId, _period) : null;
      if (mounted) {
        setState(() {
          _entries = entries;
          _myRank = myRank;
          _loading = false;
          _unavailable = entries.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('Leaderboard._fetch failed: $e');
      if (mounted) setState(() { _loading = false; _fetchError = true; });
    }
  }

  void _onPeriodChanged(LeaderboardPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final myUserId = SupabaseAuthService.instance.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Leaderboard',
                style: Theme.of(context).textTheme.titleMedium),
            _PeriodToggle(value: _period, onChanged: _onPeriodChanged),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _fetchError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Could not load leaderboard',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _fetch, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _unavailable
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No entries yet — be the first!',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            ..._entries.map((e) => _LeaderboardRow(
                                  entry: e,
                                  isMe: e.userId == myUserId,
                                )),
                            if (_myRank != null &&
                                !_entries.any((e) => e.userId == myUserId))
                              _MyRankFooter(rank: _myRank!),
                          ],
                        ),
        ),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final LeaderboardPeriod value;
  final ValueChanged<LeaderboardPeriod> onChanged;
  const _PeriodToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LeaderboardPeriod>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(
            value: LeaderboardPeriod.allTime, label: Text('All-time')),
        ButtonSegment(value: LeaderboardPeriod.weekly, label: Text('Week')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  const _LeaderboardRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isTop3 = entry.rank <= 3;
    final medals = ['', '🥇', '🥈', '🥉'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? colors.primaryContainer.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              isTop3 ? medals[entry.rank] : '#${entry.rank}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${entry.displayName} (you)' : entry.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    color: isMe ? colors.primary : null,
                  ),
            ),
          ),
          Text(
            '${entry.completedCount}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _MyRankFooter extends StatelessWidget {
  final int rank;
  const _MyRankFooter({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Text(
        'Your rank: #$rank',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
