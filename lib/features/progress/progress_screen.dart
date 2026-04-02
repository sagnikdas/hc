import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';
import '../../core/transitions.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/models/play_session.dart';
import '../auth/sign_in_screen.dart';

class ProgressScreen extends StatefulWidget {
  final int refreshSignal;
  const ProgressScreen({super.key, this.refreshSignal = 0});

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
  Map<String, int> _heatmapData = {};
  bool _loading = true;

  bool _isSignedIn = false;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _isSignedIn = SupabaseService.currentUser != null;
    _authSub = SupabaseService.authStateChanges.listen((_) {
      if (!mounted) return;
      final signedIn = SupabaseService.currentUser != null;
      if (signedIn != _isSignedIn) {
        setState(() => _isSignedIn = signedIn);
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void didUpdateWidget(ProgressScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshSignal != widget.refreshSignal) _loadData();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final repo = AppRepository.instance;
      final results = await Future.wait([
        repo.getStreaks(),
        repo.getCountsForLastDays(7),
        repo.getRecentSessions(limit: 5),
        repo.getTotalSessionCount(),
        repo.getCountsForLastDays(84),
      ]);

      final streaks = results[0] as ({int current, int best});
      final weekMap = results[1] as Map<String, int>;
      final sessions = results[2] as List<PlaySession>;
      final allTime = results[3] as int;
      final heatmap = results[4] as Map<String, int>;

      final now = DateTime.now();
      final bars = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        return weekMap[AppRepository.dateStr(d)] ?? 0;
      });

      // For unsigned-in users, only expose sessions from the last 30 minutes.
      final visibleSessions = _isSignedIn
          ? sessions
          : sessions.where((s) {
              final age = now.millisecondsSinceEpoch - s.completedAt;
              return age <= const Duration(minutes: 30).inMilliseconds;
            }).toList();

      if (!mounted) return;
      setState(() {
        _currentStreak = streaks.current;
        _bestStreak = streaks.best;
        _allTimeTotal = allTime;
        _weeklyTotal = bars.fold(0, (a, b) => a + b);
        _weeklyBars = bars;
        _recentSessions = visibleSessions;
        _heatmapData = heatmap;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('ProgressScreen._loadData error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: cs.primary,
        backgroundColor: cs.surfaceContainerLow,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, cs)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.sp(24), context.sp(8), context.sp(24), context.sp(32)),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel(context, cs),
                  SizedBox(height: context.sp(20)),
                  _buildRecentSessions(cs),
                  SizedBox(height: context.sp(28)),
                  if (!_isSignedIn) ...[
                    _SignInUpsellCard(cs: cs),
                    SizedBox(height: context.sp(28)),
                  ] else ...[
                    _buildHeatmapSection(context, cs),
                    SizedBox(height: context.sp(28)),
                    _buildMilestones(context, cs),
                    SizedBox(height: context.sp(28)),
                    _WeeklyCard(
                        total: _weeklyTotal,
                        bars: _weeklyBars,
                        loading: _loading,
                        cs: cs),
                    SizedBox(height: context.sp(14)),
                    _StreakCard(
                        current: _currentStreak,
                        best: _bestStreak,
                        loading: _loading,
                        cs: cs),
                  ],
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLow, cs.surface.withValues(alpha: 0)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.auto_graph_rounded,
              color: cs.primary.withValues(alpha: 0.6), size: context.sp(24)),
          Flexible(
            child: Text(
              'Your Devotional Journey',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                  fontSize: context.sp(20), color: cs.primary, letterSpacing: -0.3),
            ),
          ),
          SizedBox(width: context.sp(24)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, ColorScheme cs) {
    return Text('SADHANA PROGRESS',
        style: GoogleFonts.manrope(
            fontSize: context.sp(10),
            color: cs.primary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600));
  }

  Widget _buildHeatmapSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.all(context.sp(24)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spiritual Consistency',
                        style: GoogleFonts.notoSerif(
                            fontSize: context.sp(17), color: cs.onSurface)),
                    SizedBox(height: context.sp(3)),
                    Text(
                      'JOURNEY OVER THE LAST 12 WEEKS',
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(8),
                          color: cs.onSurfaceVariant,
                          letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today_outlined,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  size: context.sp(18)),
            ],
          ),
          SizedBox(height: context.sp(18)),
          _HeatmapGrid(cs: cs, data: _heatmapData),
          SizedBox(height: context.sp(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(8), color: cs.onSurfaceVariant)),
              SizedBox(width: context.sp(6)),
              ...[0.0, 0.4, 0.8, 1.0].map((o) => Container(
                    width: context.sp(9),
                    height: context.sp(9),
                    margin: EdgeInsets.symmetric(horizontal: context.sp(2)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: o == 0
                          ? cs.surfaceContainerHighest
                          : cs.primary.withValues(alpha: o),
                    ),
                  )),
              SizedBox(width: context.sp(6)),
              Text('More',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(8), color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < milestones.length; i++) ...[
                Builder(builder: (ctx) {
                  final m = milestones[i];
                  return Opacity(
                    opacity: m.unlocked ? 1.0 : 0.45,
                    child: Container(
                      width: ctx.sp(120),
                      padding: EdgeInsets.all(ctx.sp(14)),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(ctx.sp(16)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: ctx.sp(40),
                            height: ctx.sp(40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: m.unlocked
                                  ? cs.primary.withValues(alpha: 0.15)
                                  : cs.surfaceContainerHighest,
                            ),
                            child: Icon(
                              m.icon,
                              color: m.unlocked
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              size: ctx.sp(20),
                            ),
                          ),
                          SizedBox(height: ctx.sp(8)),
                          Text(
                            m.label,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: GoogleFonts.manrope(
                              fontSize: ctx.sp(10),
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          SizedBox(height: ctx.sp(2)),
                          Text(
                            m.sub,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: ctx.sp(8),
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (i != milestones.length - 1) SizedBox(width: context.sp(10)),
              ],
            ],
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
      backgroundColor: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.sp(24)))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Builder(builder: (ctx) => SizedBox(height: ctx.sp(12))),
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
                              fontSize: context.sp(13), color: cs.onSurfaceVariant)))
                  : ListView.separated(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(context.sp(24), 0, context.sp(24), context.sp(32)),
                      itemCount: sessions.length,
                      separatorBuilder: (context, index) => SizedBox(height: context.sp(10)),
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
    final isSignedIn = _isSignedIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('Recent Sessions',
                  style: GoogleFonts.notoSerif(
                      fontSize: context.sp(20), color: cs.onSurface)),
            ),
            if (isSignedIn)
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
        if (!isSignedIn) ...[
          SizedBox(height: context.sp(6)),
          Text(
            'Showing recitations from the last 30 minutes',
            style: GoogleFonts.manrope(
                fontSize: context.sp(11),
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic),
          ),
        ],
        SizedBox(height: context.sp(14)),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_recentSessions.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.sp(24)),
            child: Center(
              child: Text(
                'No sessions yet.\nStart your first recitation!',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                    fontSize: context.sp(13), color: cs.onSurfaceVariant),
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

// ── Sign-in upsell card (shown when user is not authenticated) ─────────────

class _SignInUpsellCard extends StatelessWidget {
  final ColorScheme cs;
  const _SignInUpsellCard({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.sp(24)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(24)),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.sp(40),
                height: context.sp(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.lock_open_rounded,
                    color: cs.primary, size: context.sp(20)),
              ),
              SizedBox(width: context.sp(14)),
              Expanded(
                child: Text(
                  'Unlock Your Full Journey',
                  style: GoogleFonts.notoSerif(
                      fontSize: context.sp(17), color: cs.onSurface),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(16)),
          Text(
            'Sign in with Google to sync your practice and unlock:',
            style: GoogleFonts.manrope(
                fontSize: context.sp(12),
                color: cs.onSurfaceVariant,
                height: 1.5),
          ),
          SizedBox(height: context.sp(12)),
          _UpsellBullet(
            icon: Icons.calendar_today_outlined,
            label: '12-week heatmap of your spiritual consistency',
            cs: cs,
          ),
          SizedBox(height: context.sp(8)),
          _UpsellBullet(
            icon: Icons.auto_graph_rounded,
            label: 'Weekly & all-time recitation streaks',
            cs: cs,
          ),
          SizedBox(height: context.sp(8)),
          _UpsellBullet(
            icon: Icons.emoji_events_rounded,
            label: 'Community leaderboard — see where you rank',
            cs: cs,
          ),
          SizedBox(height: context.sp(8)),
          _UpsellBullet(
            icon: Icons.devices_rounded,
            label: 'Full history synced across your devices',
            cs: cs,
          ),
          SizedBox(height: context.sp(20)),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
                  slideUpRoute(
                    const SignInScreen(launchGoogleSignInImmediately: true),
                  ),
                ),
            child: Container(
              width: double.infinity,
              height: context.sp(48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(context.sp(12)),
              ),
              child: Center(
                child: Text(
                  'Sign in with Google',
                  style: GoogleFonts.notoSerif(
                      fontSize: context.sp(15),
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsellBullet extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _UpsellBullet({required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: cs.primary.withValues(alpha: 0.7), size: context.sp(14)),
        SizedBox(width: context.sp(8)),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
                fontSize: context.sp(11),
                color: cs.onSurfaceVariant,
                height: 1.4),
          ),
        ),
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
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(context.sp(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.auto_graph_rounded, color: cs.primary, size: context.sp(26)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.sp(8), vertical: context.sp(4)),
                  decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(context.sp(4))),
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
                    GoogleFonts.notoSerif(fontSize: context.sp(34), color: cs.primary)),
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
                                ? cs.primary
                                : count > 0
                                    ? cs.primary.withValues(alpha: 0.6)
                                    : cs.surfaceContainerHighest,
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
                              ? cs.primary
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
          color: cs.surfaceContainerLow,
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
                      fontSize: context.sp(44), color: cs.primary)),
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
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
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
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.sp(16))),
      child: Row(
        children: [
          Container(
            width: context.sp(38),
            height: context.sp(38),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: cs.surfaceContainerHighest),
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
                    fontSize: context.sp(18), color: cs.primary)),
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

class _HeatmapGrid extends StatelessWidget {
  final ColorScheme cs;
  final Map<String, int> data;
  const _HeatmapGrid({required this.cs, required this.data});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final maxCount =
        data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    final spacing = context.sp(3.0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 12,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemCount: 84,
      itemBuilder: (_, i) {
        final date = today.subtract(Duration(days: 83 - i));
        final key = AppRepository.dateStr(date);
        final count = data[key] ?? 0;
        final opacity =
            count == 0 ? 0.0 : (count / maxCount).clamp(0.2, 1.0);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: opacity == 0
                ? cs.surfaceContainerHighest
                : cs.primary.withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
