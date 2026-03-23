import 'package:flutter/material.dart';
import '../../core/streak_calculator.dart';
import '../../data/models/daily_stat.dart';
import '../../data/repositories/daily_stat_repository.dart';
import '../../main.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load the past 365 days
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 364));
    final stats = await _repo.getRange(_fmt(from), _fmt(to));
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeDates = _stats
        .where((s) => s.completionCount > 0)
        .map((s) => s.date)
        .toList();

    final today = DateTime.now();
    final current = StreakCalculator.currentStreak(activeDates, today);
    final best = StreakCalculator.bestStreak(activeDates);
    final totalCompletions =
        _stats.fold<int>(0, (sum, s) => sum + s.completionCount);

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
          children: [
            Text(value,
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
                final key =
                    '${day.year.toString().padLeft(4,'0')}-'
                    '${day.month.toString().padLeft(2,'0')}-'
                    '${day.day.toString().padLeft(2,'0')}';
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
                    'आपने इस हफ्ते $weekCompletions पाठ किए — '
                    'Premium के साथ और गहरी साधना करें।',
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
