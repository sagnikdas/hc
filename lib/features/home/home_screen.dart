import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../play/play_screen.dart';
import '../../core/transitions.dart';
import '../../core/responsive.dart';
import '../../data/repositories/app_repository.dart';

class HomeScreen extends StatefulWidget {
  final int refreshSignal;
  const HomeScreen({super.key, this.refreshSignal = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayCount = 0;
  int _bestStreak = 0;
  Map<String, int> _heatmapData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = AppRepository.instance;
    final results = await Future.wait([
      repo.getTodayCount(),
      repo.getStreaks(),
      repo.getCountsForLastDays(84),
    ]);
    if (!mounted) return;
    final streaks = results[1] as ({int current, int best});
    setState(() {
      _todayCount = results[0] as int;
      _bestStreak = streaks.best;
      _heatmapData = results[2] as Map<String, int>;
      _loading = false;
    });
  }

  void _openPlay({String? assetPath}) {
    Navigator.of(context)
        .push(slideUpRoute(PlayScreen(initialVoice: assetPath)))
        .then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: cs.primary,
        backgroundColor: const Color(0xFF1C1B1B),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, cs)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.sp(24), context.sp(8), context.sp(24), context.sp(32)),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeroCard(context, cs),
                  const SizedBox(height: 20),
                  _buildQuickStats(cs),
                  const SizedBox(height: 20),
                  _buildSacredMelodies(context, cs),
                  const SizedBox(height: 20),
                  _buildHeatmapSection(context, cs),
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
          colors: [const Color(0xFF1C1B1B), cs.surface.withValues(alpha: 0)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.menu_rounded,
              color: cs.primary.withValues(alpha: 0.6), size: context.sp(24)),
          Text(
            'Hanuman Chalisa',
            style: GoogleFonts.notoSerif(
                fontSize: context.sp(20), color: cs.primary, letterSpacing: -0.3),
          ),
          SizedBox(width: context.sp(24)),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme cs) {
    return GestureDetector(
      onTap: () => _openPlay(),
      child: Container(
        height: context.sp(360),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFF1C1B1B),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/hanuman_hero.png',
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.5),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stack) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A2A2A),
                      cs.primaryContainer.withValues(alpha: 0.3)
                    ],
                  ),
                ),
                child: Center(
                  child: Text('ॐ',
                      style: GoogleFonts.notoSerif(
                          fontSize: 80,
                          color: cs.secondary.withValues(alpha: 0.3))),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF131313).withValues(alpha: 0.95)
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TODAY'S SANKALPA",
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(9),
                      color: cs.secondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                  SizedBox(height: context.sp(8)),
                  Text(
                    'Begin your sacred\nrecitation',
                    style: GoogleFonts.notoSerif(
                        fontSize: context.sp(26), color: cs.onSurface, height: 1.2),
                  ),
                  SizedBox(height: context.sp(6)),
                  Text(
                    'Focus your mind and find peace through\nthe verses of devotion.',
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(12),
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: context.sp(18)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.sp(24), vertical: context.sp(13)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: LinearGradient(
                          colors: [cs.primary, cs.primaryContainer]),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primaryContainer.withValues(alpha: 0.35),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: cs.onPrimary, size: context.sp(20)),
                        SizedBox(width: context.sp(8)),
                        Text(
                          'START NOW',
                          style: GoogleFonts.manrope(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontSize: context.sp(13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.auto_awesome_rounded,
            label: 'TODAY',
            value: _loading ? '–' : '$_todayCount',
            unit: 'times',
            cs: cs,
          ),
        ),
        SizedBox(width: context.sp(14)),
        Expanded(
          child: _StatCard(
            icon: Icons.bolt_rounded,
            label: 'BEST STREAK',
            value: _loading ? '–' : '$_bestStreak',
            unit: 'days',
            cs: cs,
          ),
        ),
      ],
    );
  }

  Widget _buildSacredMelodies(BuildContext context, ColorScheme cs) {
    final tracks = [
      (
        asset: 'assets/audio/hc_real.mp3',
        title: 'Hanuman Chalisa',
        subtitle: 'Traditional Devotional',
        icon: Icons.surround_sound_rounded,
      ),
      (
        asset: 'assets/audio/voice_1.mp3',
        title: 'Voice Recitation',
        subtitle: 'Sacred Chant',
        icon: Icons.record_voice_over_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sacred Melodies',
                style: GoogleFonts.notoSerif(fontSize: context.sp(20), color: cs.onSurface)),
            Text('ALL',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(9),
                    color: cs.primary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: context.sp(110),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            separatorBuilder: (context, index) => SizedBox(width: context.sp(12)),
            itemBuilder: (context, i) {
              final t = tracks[i];
              return GestureDetector(
                onTap: () => _openPlay(assetPath: t.asset),
                child: Container(
                  width: context.sp(180),
                  padding: EdgeInsets.all(context.sp(16)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1B1B),
                    borderRadius: BorderRadius.circular(context.sp(20)),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: context.sp(36),
                        height: context.sp(36),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(t.icon, color: cs.primary, size: context.sp(18)),
                      ),
                      const Spacer(),
                      Text(t.title,
                          style: GoogleFonts.notoSerif(
                              fontSize: context.sp(13),
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: context.sp(2)),
                      Text(t.subtitle,
                          style: GoogleFonts.manrope(
                              fontSize: context.sp(10), color: cs.onSurfaceVariant)),
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

  Widget _buildHeatmapSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.all(context.sp(24)),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(context.sp(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spiritual Consistency',
                      style:
                          GoogleFonts.notoSerif(fontSize: context.sp(17), color: cs.onSurface)),
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
              Icon(Icons.calendar_today_outlined,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: context.sp(18)),
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
                          ? const Color(0xFF353534)
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
}


class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final ColorScheme cs;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.sp(20)),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(context.sp(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.secondary, size: context.sp(20)),
          SizedBox(height: context.sp(10)),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: context.sp(9),
              color: cs.onSurfaceVariant,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(4)),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: GoogleFonts.notoSerif(fontSize: context.sp(26), color: cs.primary),
              ),
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(11),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ]),
          ),
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

    // 12 columns, 7 rows, 3px gaps — compute height from actual width
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 12;
      const rows = 7;
      final spacing = context.sp(3.0);
      final cellSize = (constraints.maxWidth - (cols - 1) * spacing) / cols;
      final gridHeight = rows * cellSize + (rows - 1) * spacing;

      return SizedBox(
        height: gridHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
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
                    ? const Color(0xFF353534)
                    : cs.primary.withValues(alpha: opacity),
              ),
            );
          },
        ),
      );
    });
  }
}
