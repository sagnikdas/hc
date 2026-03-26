import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/responsive.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/models/play_session.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _weeklyTotal = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _allTimeTotal = 0;
  List<int> _weeklyBars = List.filled(7, 0);
  List<PlaySession> _recentSessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = AppRepository.instance;
    final results = await Future.wait([
      repo.getStreaks(),
      repo.getCountsForLastDays(7),
      repo.getRecentSessions(limit: 5),
      repo.getTotalSessionCount(),
    ]);

    final streaks = results[0] as ({int current, int best});
    final weekMap = results[1] as Map<String, int>;
    final sessions = results[2] as List<PlaySession>;
    final allTime = results[3] as int;

    final now = DateTime.now();
    final bars = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return weekMap[AppRepository.dateStr(d)] ?? 0;
    });

    if (!mounted) return;
    setState(() {
      _currentStreak = streaks.current;
      _bestStreak = streaks.best;
      _allTimeTotal = allTime;
      _weeklyTotal = bars.fold(0, (a, b) => a + b);
      _weeklyBars = bars;
      _recentSessions = sessions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: cs.primary,
        backgroundColor: const Color(0xFF1C1B1B),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, cs)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.sp(24), context.sp(8), context.sp(24), context.sp(32)),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel(context, cs),
                  const SizedBox(height: 20),
                  _WeeklyCard(
                      total: _weeklyTotal,
                      bars: _weeklyBars,
                      loading: _loading,
                      cs: cs),
                  const SizedBox(height: 14),
                  _StreakCard(
                      current: _currentStreak,
                      best: _bestStreak,
                      loading: _loading,
                      cs: cs),
                  const SizedBox(height: 28),
                  _buildMilestones(context, cs),
                  const SizedBox(height: 28),
                  _buildRecentSessions(cs),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          context.sp(24), MediaQuery.of(context).padding.top + context.sp(12), context.sp(24), context.sp(16)),
      color: cs.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.menu_rounded, color: cs.primary, size: context.sp(24)),
            SizedBox(width: context.sp(14)),
            Text('Hanuman Chalisa',
                style:
                    GoogleFonts.notoSerif(fontSize: context.sp(20), color: cs.primary)),
          ]),
          CircleAvatar(
            radius: context.sp(16),
            backgroundColor: const Color(0xFF2A2A2A),
            child: Icon(Icons.person_outline_rounded,
                size: context.sp(18), color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SADHANA PROGRESS',
            style: GoogleFonts.manrope(
                fontSize: context.sp(10),
                color: cs.secondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w600)),
        SizedBox(height: context.sp(6)),
        Text('Your Devotional Journey',
            style: GoogleFonts.notoSerif(
                fontSize: context.sp(28),
                color: cs.onSurface,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildMilestones(BuildContext context, ColorScheme cs) {
    final milestones = [
      (
        icon: Icons.workspace_premium_rounded,
        label: 'First Chanting',
        sub: _allTimeTotal >= 1 ? 'COMPLETED' : 'IN PROGRESS',
        unlocked: _allTimeTotal >= 1
      ),
      (
        icon: Icons.emoji_events_rounded,
        label: '7-Day Streak',
        sub: _bestStreak >= 7 ? 'COMPLETED' : 'IN PROGRESS',
        unlocked: _bestStreak >= 7
      ),
      (
        icon: Icons.nights_stay_outlined,
        label: 'Brahma Muhurta',
        sub: 'LOCKED',
        unlocked: false
      ),
      (
        icon: Icons.church_outlined,
        label: 'Pilgrim Soul',
        sub: 'LOCKED',
        unlocked: false
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sadhana Milestones',
            style:
                GoogleFonts.notoSerif(fontSize: context.sp(20), color: cs.onSurface)),
        SizedBox(height: context.sp(16)),
        SizedBox(
          height: context.sp(130),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: milestones.length,
            separatorBuilder: (ctx, index) => SizedBox(width: ctx.sp(10)),
            itemBuilder: (ctx, i) {
              final m = milestones[i];
              return Opacity(
                opacity: m.unlocked ? 1.0 : 0.45,
                child: Container(
                  width: ctx.sp(120),
                  padding: EdgeInsets.all(ctx.sp(14)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(ctx.sp(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: ctx.sp(40),
                        height: ctx.sp(40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.unlocked
                              ? cs.primary.withValues(alpha: 0.15)
                              : const Color(0xFF353534),
                        ),
                        child: Icon(m.icon,
                            color: m.unlocked
                                ? cs.secondary
                                : cs.onSurfaceVariant,
                            size: ctx.sp(20)),
                      ),
                      SizedBox(height: ctx.sp(8)),
                      Text(m.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                              fontSize: ctx.sp(10),
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      SizedBox(height: ctx.sp(2)),
                      Text(m.sub,
                          style: GoogleFonts.manrope(
                              fontSize: ctx.sp(8),
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAllSessions(
      BuildContext context, ColorScheme cs) async {
    final sessions = await AppRepository.instance.getAllSessions(limit: 100);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1B1B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Builder(builder: (ctx) => Container(
                width: ctx.sp(40),
                height: ctx.sp(4),
                decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2)))),
            Builder(builder: (ctx) => SizedBox(height: ctx.sp(16))),
            Builder(builder: (ctx) => Padding(
              padding: EdgeInsets.symmetric(horizontal: ctx.sp(24)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('All Sessions',
                    style: GoogleFonts.notoSerif(
                        fontSize: ctx.sp(22), color: cs.onSurface)),
              ),
            )),
            Builder(builder: (ctx) => SizedBox(height: ctx.sp(16))),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text('No sessions yet.',
                          style: GoogleFonts.manrope(
                              fontSize: 13, color: cs.onSurfaceVariant)))
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      itemCount: sessions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = sessions[i];
                        final date =
                            DateTime.fromMillisecondsSinceEpoch(s.completedAt);
                        final isToday = AppRepository.dateStr(date) ==
                            AppRepository.dateStr(DateTime.now());
                        final label =
                            isToday ? 'Today' : AppRepository.formatDate(date);
                        return _SessionTile(
                          title: 'Recitation',
                          subtitle:
                              '$label • ${AppRepository.formatTime(s.completedAt)}',
                          count: s.count,
                          cs: cs,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessions(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Sessions',
                style: GoogleFonts.notoSerif(
                    fontSize: context.sp(20), color: cs.onSurface)),
            GestureDetector(
              onTap: () => _showAllSessions(context, cs),
              child: Text('VIEW ALL',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(9),
                      color: cs.primary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_recentSessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No sessions yet.\nStart your first recitation!',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...List.generate(_recentSessions.length, (i) {
            final s = _recentSessions[i];
            final date =
                DateTime.fromMillisecondsSinceEpoch(s.completedAt);
            final isToday = AppRepository.dateStr(date) ==
                AppRepository.dateStr(DateTime.now());
            final label =
                isToday ? 'Today' : AppRepository.formatDate(date);
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < _recentSessions.length - 1 ? 10 : 0),
              child: _SessionTile(
                title: 'Recitation',
                subtitle:
                    '$label • ${AppRepository.formatTime(s.completedAt)}',
                count: s.count,
                cs: cs,
              ),
            );
          }),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _WeeklyCard extends StatelessWidget {
  final int total;
  final List<int> bars;
  final bool loading;
  final ColorScheme cs;
  const _WeeklyCard(
      {required this.total,
      required this.bars,
      required this.loading,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final maxBar =
        bars.isEmpty ? 1 : bars.reduce((a, b) => a > b ? a : b);
    return Builder(builder: (context) {
      final barHeight = context.sp(56);
      return Container(
        padding: EdgeInsets.all(context.sp(22)),
        decoration: BoxDecoration(
            color: const Color(0xFF1C1B1B),
            borderRadius: BorderRadius.circular(context.sp(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.auto_graph_rounded, color: cs.secondary, size: context.sp(26)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.sp(8), vertical: context.sp(4)),
                  decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('WEEKLY',
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(9),
                          color: cs.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            SizedBox(height: context.sp(10)),
            Text(loading ? '–' : '$total',
                style:
                    GoogleFonts.notoSerif(fontSize: context.sp(34), color: cs.onSurface)),
            Text('Recitations this week',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(11), color: cs.onSurfaceVariant)),
            SizedBox(height: context.sp(14)),
            Column(
              children: [
                SizedBox(
                  height: barHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(bars.length, (i) {
                      final count = bars[i];
                      final frac = maxBar == 0
                          ? 0.05
                          : (count / maxBar).clamp(0.05, 1.0);
                      final isToday = i == bars.length - 1;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: context.sp(2)),
                          height: barHeight * frac,
                          decoration: BoxDecoration(
                            color: isToday && count > 0
                                ? cs.secondary
                                : count > 0
                                    ? cs.primary.withValues(alpha: 0.6)
                                    : const Color(0xFF353534),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: context.sp(6)),
                Row(
                  children: List.generate(7, (i) {
                    final now = DateTime.now();
                    final d = now.subtract(Duration(days: 6 - i));
                    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final label = labels[d.weekday - 1];
                    final isToday = i == 6;
                    return Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: context.sp(9),
                          color: isToday
                              ? cs.secondary
                              : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _StreakCard extends StatelessWidget {
  final int current;
  final int best;
  final bool loading;
  final ColorScheme cs;
  const _StreakCard(
      {required this.current,
      required this.best,
      required this.loading,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final nextMilestone =
        current < 7 ? 7 : current < 21 ? 21 : current < 30 ? 30 : 108;
    final progress =
        (current / nextMilestone).clamp(0.0, 1.0);

    return Builder(builder: (context) => Container(
      padding: EdgeInsets.all(context.sp(22)),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(context.sp(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT STREAK',
              style: GoogleFonts.manrope(
                  fontSize: context.sp(9),
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.5)),
          SizedBox(height: context.sp(4)),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: loading ? '– ' : '$current ',
                  style: GoogleFonts.notoSerif(
                      fontSize: context.sp(44), color: cs.secondary)),
              TextSpan(
                  text: 'Days',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(15),
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic)),
            ]),
          ),
          SizedBox(height: context.sp(14)),
          Divider(
              color: cs.outlineVariant.withValues(alpha: 0.2), height: 1),
          SizedBox(height: context.sp(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEXT MILESTONE',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(9),
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.2)),
              Text('$nextMilestone Days',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(11), color: cs.primary)),
            ],
          ),
          SizedBox(height: context.sp(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF353534),
              valueColor: AlwaysStoppedAnimation(cs.secondary),
              minHeight: context.sp(4),
            ),
          ),
        ],
      ),
    ));
  }
}

class _SessionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final ColorScheme cs;
  const _SessionTile(
      {required this.title,
      required this.subtitle,
      required this.count,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.sp(14)),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(context.sp(16))),
      child: Row(
        children: [
          Container(
            width: context.sp(38),
            height: context.sp(38),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF353534)),
            child:
                Icon(Icons.history_rounded, color: cs.primary, size: context.sp(18)),
          ),
          SizedBox(width: context.sp(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(11), color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('x $count',
                style: GoogleFonts.notoSerif(
                    fontSize: context.sp(18), color: cs.secondary)),
            Text('COUNTS',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(8),
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2)),
          ]),
        ],
      ),
    );
  }
}
