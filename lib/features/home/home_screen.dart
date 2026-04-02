import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../play/audio_track_selection_screen.dart';
import '../play/play_screen.dart';
import '../recitation/recitation_screen.dart';
import '../../core/transitions.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';
import '../../data/repositories/app_repository.dart';

class HomeScreen extends StatefulWidget {
  final int refreshSignal;
  final VoidCallback? onSwitchToSettings;
  const HomeScreen({super.key, this.refreshSignal = 0, this.onSwitchToSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Pick one Hanuman Ji background per app session (survives HomeScreen rebuilds).
  // When you add more background photos under `assets/images/`, also extend
  // `_heroBackgroundAssets` below.
  static String? _sessionHeroBackgroundAsset;
  static const List<String> _heroBackgroundAssets = [
    'assets/images/hanuman_hero.png',
    'assets/images/hanuman_player_bg.png',
  ];

  int _todayCount = 0;
  int _bestStreak = 0;
  bool _loading = true;

  Map<String, dynamic>? _profile;
  bool _authLoading = false;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _sessionHeroBackgroundAsset ??= _pickRandomHeroBackgroundAsset();
    _loadStats();
    _loadProfile();
    _authSub = SupabaseService.authStateChanges.listen((_) {
      if (mounted) _loadProfile();
    });
  }

  String _pickRandomHeroBackgroundAsset() {
    // Use time-based seed so a new app launch yields a different hero image.
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    return _heroBackgroundAssets[rng.nextInt(_heroBackgroundAssets.length)];
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _loadStats();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile().catchError((_) => null);
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _signIn() async {
    setState(() => _authLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
    } catch (e) {
      debugPrint('Sign-in error: $e');
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _loadStats() async {
    final repo = AppRepository.instance;
    final results = await Future.wait([
      repo.getTodayCount(),
      repo.getStreaks(),
    ]);
    if (!mounted) return;
    final streaks = results[1] as ({int current, int best});
    setState(() {
      _todayCount = results[0] as int;
      _bestStreak = streaks.best;
      _loading = false;
    });
  }

  void _openPlay({String? assetPath}) {
    Navigator.of(context)
        .push(slideUpRoute(PlayScreen(initialVoice: assetPath)))
        .then((_) => _loadStats());
  }

  Future<void> _openChalisaTile() async {
    final settings = await AppRepository.instance.getSettings();
    if (!mounted) return;
    if (settings.preferredTrack == null) {
      // First time — show track selection screen.
      Navigator.of(context)
          .push(slideUpRoute(const AudioTrackSelectionScreen()))
          .then((_) => _loadStats());
    } else {
      // Returning user — play directly with saved preference.
      Navigator.of(context)
          .push(slideUpRoute(PlayScreen(initialTrackId: settings.preferredTrack)))
          .then((_) => _loadStats());
    }
  }

  void _openRecitation() {
    Navigator.of(context).push(slideUpRoute(const RecitationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      drawer: _AppDrawer(
        todayCount: _todayCount,
        profile: _profile,
        authLoading: _authLoading,
        onSignIn: _signIn,
        onGoToSettings: widget.onSwitchToSettings,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: cs.primary,
        backgroundColor: cs.surfaceContainerLow,
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
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Icon(Icons.menu_rounded,
                color: cs.primary.withValues(alpha: 0.6), size: context.sp(24)),
          ),
          Expanded(
            child: Text(
              'Hanuman Chalisa',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerif(
                  fontSize: context.sp(20), color: cs.primary, letterSpacing: -0.3),
            ),
          ),
          SizedBox(width: context.sp(24)),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageBlendColor = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : cs.primary.withValues(alpha: 0.35);
    final imageBlendMode = isDark ? BlendMode.darken : BlendMode.srcOver;
    final gradientEndColor = isDark
        ? Colors.black.withValues(alpha: 0.9)
        : cs.primary.withValues(alpha: 0.92);
    final textOnHero = isDark ? cs.onSurface : cs.onPrimary;
    final subTextOnHero = isDark
        ? cs.onSurfaceVariant.withValues(alpha: 0.8)
        : cs.onPrimary.withValues(alpha: 0.78);
    final labelOnHero = isDark ? cs.secondary : cs.onPrimary.withValues(alpha: 0.72);

    return GestureDetector(
      onTap: () => _openPlay(),
      child: Container(
        height: context.sp(360),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: cs.surfaceContainerLow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _sessionHeroBackgroundAsset ?? 'assets/images/hanuman_hero.png',
              fit: BoxFit.cover,
              color: imageBlendColor,
              colorBlendMode: imageBlendMode,
              errorBuilder: (context, error, stack) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surfaceContainerHigh,
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
                    gradientEndColor,
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned(
              left: context.sp(24),
              right: context.sp(24),
              bottom: context.sp(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TODAY'S SANKALPA",
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(9),
                      color: labelOnHero,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                  SizedBox(height: context.sp(8)),
                  Text(
                    'Begin your sacred\nrecitation',
                    style: GoogleFonts.notoSerif(
                        fontSize: context.sp(26), color: textOnHero, height: 1.2),
                  ),
                  SizedBox(height: context.sp(6)),
                  Text(
                    'Focus your mind and find peace through\nthe verses of devotion.',
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(12),
                      color: subTextOnHero,
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
        isRecitation: false,
      ),
      (
        asset: '',
        title: 'Voice Recitation',
        subtitle: 'Sacred Chant',
        icon: Icons.record_voice_over_rounded,
        isRecitation: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sacred Melodies',
            style: GoogleFonts.notoSerif(fontSize: context.sp(20), color: cs.onSurface)),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < tracks.length; i++) ...[
              if (i > 0) SizedBox(width: context.sp(12)),
              Expanded(
                child: GestureDetector(
                  onTap: () => tracks[i].isRecitation
                      ? _openRecitation()
                      : _openChalisaTile(),
                  child: Container(
                    padding: EdgeInsets.all(context.sp(16)),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(context.sp(20)),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: context.sp(36),
                          height: context.sp(36),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            tracks[i].icon,
                            color: cs.primary,
                            size: context.sp(18),
                          ),
                        ),
                        SizedBox(height: context.sp(10)),
                        Text(
                          tracks[i].title,
                          softWrap: true,
                          style: GoogleFonts.notoSerif(
                            fontSize: context.sp(13),
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: context.sp(4)),
                        Text(
                          tracks[i].subtitle,
                          softWrap: true,
                          style: GoogleFonts.manrope(
                            fontSize: context.sp(10),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: context.sp(20)),
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


// ── Drawer ─────────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final int todayCount;
  final Map<String, dynamic>? profile;
  final bool authLoading;
  final VoidCallback onSignIn;
  final VoidCallback? onGoToSettings;

  const _AppDrawer({
    required this.todayCount,
    required this.profile,
    required this.authLoading,
    required this.onSignIn,
    this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = SupabaseService.currentUser;
    final name = (profile?['name'] as String?)?.isNotEmpty == true
        ? profile!['name'] as String
        : user?.userMetadata?['full_name'] as String? ?? 'Devotee';
    final email = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header — avatar + name ─────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  context.sp(24), context.sp(28), context.sp(24), context.sp(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: context.sp(30),
                    backgroundColor: cs.primaryContainer,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            user != null && name.isNotEmpty
                                ? name[0].toUpperCase()
                                : 'ॐ',
                            style: GoogleFonts.notoSerif(
                                fontSize: context.sp(22),
                                color: cs.onPrimaryContainer),
                          )
                        : null,
                  ),
                  SizedBox(height: context.sp(14)),
                  Text(
                    name,
                    style: GoogleFonts.notoSerif(
                        fontSize: context.sp(18),
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600),
                  ),
                  if (email.isNotEmpty) ...[
                    SizedBox(height: context.sp(3)),
                    Text(
                      email,
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(11),
                          color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),

            Divider(color: cs.outlineVariant.withValues(alpha: 0.15), height: 1),

            // ── Today's recitation count ───────────────────────────────
            Padding(
              padding: EdgeInsets.all(context.sp(20)),
              child: Row(
                children: [
                  Container(
                    width: context.sp(42),
                    height: context.sp(42),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: cs.primary, size: context.sp(18)),
                  ),
                  SizedBox(width: context.sp(14)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S RECITATIONS",
                        style: GoogleFonts.manrope(
                            fontSize: context.sp(9),
                            color: cs.onSurfaceVariant,
                            letterSpacing: 1.2),
                      ),
                      SizedBox(height: context.sp(2)),
                      Text(
                        '$todayCount',
                        style: GoogleFonts.notoSerif(
                            fontSize: context.sp(28), color: cs.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(color: cs.outlineVariant.withValues(alpha: 0.15), height: 1),

            // ── SSO CTA or synced status ───────────────────────────────
            if (user == null)
              Padding(
                padding: EdgeInsets.all(context.sp(20)),
                child: GestureDetector(
                  onTap: authLoading ? null : onSignIn,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.sp(16), vertical: context.sp(14)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [cs.primary, cs.primaryContainer]),
                      borderRadius: BorderRadius.circular(context.sp(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (authLoading)
                          SizedBox(
                            width: context.sp(16),
                            height: context.sp(16),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary),
                          )
                        else
                          Icon(Icons.sync_rounded,
                              color: cs.onPrimary, size: context.sp(16)),
                        SizedBox(width: context.sp(8)),
                        Text(
                          authLoading ? 'Signing in…' : 'Sync Your Path',
                          style: GoogleFonts.manrope(
                              fontSize: context.sp(13),
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.sp(20), vertical: context.sp(16)),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded,
                        color: cs.primary, size: context.sp(16)),
                    SizedBox(width: context.sp(8)),
                    Text(
                      'Path is synced',
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(12), color: cs.primary),
                    ),
                  ],
                ),
              ),

            Divider(color: cs.outlineVariant.withValues(alpha: 0.15), height: 1),

            // ── Settings link ──────────────────────────────────────────
            if (onGoToSettings != null)
              _DrawerItem(
                icon: Icons.tune_rounded,
                label: 'Sankalp Settings',
                cs: cs,
                onTap: () {
                  Navigator.of(context).pop();
                  onGoToSettings!();
                },
              ),

            const Spacer(),

            // ── Branding footer ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(context.sp(24)),
              child: Text(
                'Hanuman Chalisa',
                style: GoogleFonts.notoSerif(
                    fontSize: context.sp(11),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _DrawerItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: cs.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.sp(20), vertical: context.sp(14)),
        child: Row(
          children: [
            Icon(icon, color: cs.primary, size: context.sp(20)),
            SizedBox(width: context.sp(16)),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface),
              ),
            ),
            SizedBox(width: context.sp(8)),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                size: context.sp(18)),
          ],
        ),
      ),
    );
  }
}
