import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<Map<String, dynamic>> _entries = [];
  bool _loading = false;
  bool _offline = false;
  String? _currentUserId;
  bool _loadedOnce = false;

  StreamSubscription? _authSub;

  bool get _isSignedIn => _currentUserId != null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChange);
    _currentUserId = SupabaseService.currentUser?.id;
    _authSub = SupabaseService.authStateChanges.listen((state) {
      if (!mounted) return;
      final newId = SupabaseService.currentUser?.id;
      setState(() => _currentUserId = newId);
      // Auto-load leaderboard when user signs in from the gate
      if (newId != null && !_loadedOnce) {
        _loadedOnce = true;
        _load(weekly: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce && _isSignedIn) {
      _loadedOnce = true;
      _load(weekly: true);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabs.indexIsChanging) return;
    _load(weekly: _tabs.index == 0);
  }

  Future<void> _load({required bool weekly}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final data = await SupabaseService.fetchLeaderboard(weekly: weekly);
      if (!mounted) return;
      setState(() {
        _entries = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final isOffline = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('failed host');
      setState(() {
        _loading = false;
        _offline = isOffline;
        if (!isOffline) _entries = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          _buildHeader(context, cs),
          if (_isSignedIn) ...[
            _buildTabBar(cs),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildList(cs),
                  _buildList(cs),
                ],
              ),
            ),
          ] else
            Expanded(child: _buildSignInGate(context, cs)),
        ],
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
          Icon(Icons.emoji_events_rounded,
              color: cs.primary.withValues(alpha: 0.6), size: context.sp(24)),
          Text(
            'Leaderboard',
            style: GoogleFonts.notoSerif(
                fontSize: context.sp(20), color: cs.primary, letterSpacing: -0.3),
          ),
          if (_isSignedIn && !_loading)
            GestureDetector(
              onTap: () => _load(weekly: _tabs.index == 0),
              child: Icon(Icons.refresh_rounded,
                  color: cs.onSurfaceVariant, size: context.sp(20)),
            )
          else
            SizedBox(width: context.sp(24)),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.sp(24), 0, context.sp(24), context.sp(12)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(context.sp(12)),
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(context.sp(10)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: GoogleFonts.manrope(
              fontSize: context.sp(13), fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInGate(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.sp(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.sp(80),
              height: context.sp(80),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: cs.primary, size: context.sp(40)),
            ),
            SizedBox(height: context.sp(24)),
            Text(
              'Join the Community',
              style: GoogleFonts.notoSerif(
                  fontSize: context.sp(22), color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sp(12)),
            Text(
              'Sign in with Google to see how you rank among thousands of devoted practitioners around the world.',
              style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  color: cs.onSurfaceVariant,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sp(10)),
            Text(
              'Your recitations will sync and appear on the global leaderboard.',
              style: GoogleFonts.manrope(
                  fontSize: context.sp(12),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sp(32)),
            _SignInButton(cs: cs),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: cs.primary),
      );
    }

    if (_offline) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: cs.onSurfaceVariant, size: context.sp(48)),
              SizedBox(height: context.sp(16)),
              Text(
                'No internet connection',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
              SizedBox(height: context.sp(8)),
              Text(
                'Connect to view the leaderboard.',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(13), color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🙏', style: TextStyle(fontSize: context.sp(48))),
              SizedBox(height: context.sp(16)),
              Text(
                'No completions yet this period.',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(14), color: cs.onSurfaceVariant),
              ),
              SizedBox(height: context.sp(8)),
              Text(
                'Be the first on the board!',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(12), color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(weekly: _tabs.index == 0),
      color: cs.primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(context.sp(24), 0, context.sp(24), context.sp(24)),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final rank = (entry['rank'] as num?)?.toInt() ?? (index + 1);
          final name = entry['display_name'] as String? ?? 'Devotee';
          final count = (entry['total_count'] as num?)?.toInt() ?? 0;
          final userId = entry['user_id'] as String?;
          final isMe = userId != null && userId == _currentUserId;

          return _LeaderboardRow(
            rank: rank,
            name: name,
            count: count,
            isMe: isMe,
            cs: cs,
          );
        },
      ),
    );
  }
}

// ── Sign-in button used inside the leaderboard gate ───────────────────────────

class _SignInButton extends StatefulWidget {
  final ColorScheme cs;
  const _SignInButton({required this.cs});

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
    } catch (e, st) {
      debugPrint('Leaderboard sign-in error: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = kDebugMode
              ? '$e'
              : (e is StateError)
                  ? '$e'
                  : 'Sign-in failed. Please try again.';
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Column(
      children: [
        GestureDetector(
          onTap: _loading ? null : _signIn,
          child: Container(
            width: double.infinity,
            height: context.sp(54),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(context.sp(14)),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: context.sp(22),
                          height: context.sp(22),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4285F4),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: context.sp(10)),
                        Text(
                          'Sign in with Google',
                          style: GoogleFonts.notoSerif(
                              fontSize: context.sp(16),
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: context.sp(10)),
          Text(
            _error!,
            style: GoogleFonts.manrope(
                fontSize: context.sp(12), color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int count;
  final bool isMe;
  final ColorScheme cs;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.isMe,
    required this.cs,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700); // gold
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: context.sp(8)),
      padding: EdgeInsets.symmetric(horizontal: context.sp(16), vertical: context.sp(14)),
      decoration: BoxDecoration(
        color: isMe
            ? cs.primary.withValues(alpha: 0.08)
            : const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(context.sp(14)),
        border: Border.all(
          color: isMe
              ? cs.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: isMe ? 1 : 0,
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: context.sp(32),
            child: rank <= 3
                ? Text(
                    rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                    style: TextStyle(fontSize: context.sp(22)),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '#$rank',
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                      color: _rankColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(width: context.sp(12)),
          // Name
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(14),
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      color: isMe ? cs.primary : cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  SizedBox(width: context.sp(6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.sp(6), vertical: context.sp(2)),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(context.sp(6)),
                    ),
                    child: Text('you',
                        style: GoogleFonts.manrope(
                            fontSize: context.sp(9),
                            color: cs.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          // Count
          Row(
            children: [
              Text(
                '$count',
                style: GoogleFonts.notoSerif(
                  fontSize: context.sp(18),
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? _rankColor : cs.onSurface,
                ),
              ),
              SizedBox(width: context.sp(4)),
              Text('paaths',
                  style: GoogleFonts.manrope(
                      fontSize: context.sp(10), color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
