import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChange);
    _currentUserId = SupabaseService.currentUser?.id;
    _authSub = SupabaseService.authStateChanges.listen((state) {
      if (mounted) setState(() => _currentUserId = SupabaseService.currentUser?.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load once when the screen becomes part of the tree.
    if (!_loadedOnce) {
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
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 14, 24, 8),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'Leaderboard',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              color: cs.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          if (!_loading)
            GestureDetector(
              onTap: () => _load(weekly: _tabs.index == 0),
              child: Icon(Icons.refresh_rounded,
                  color: cs.onSurfaceVariant, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'All Time'),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: cs.onSurfaceVariant, size: 48),
              const SizedBox(height: 16),
              Text(
                'No internet connection',
                style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to view the leaderboard.',
                style: GoogleFonts.manrope(
                    fontSize: 13, color: cs.onSurfaceVariant),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🙏', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'No completions yet this period.',
                style: GoogleFonts.manrope(
                    fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first on the board!',
                style: GoogleFonts.manrope(
                    fontSize: 12, color: cs.onSurfaceVariant),
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
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe
            ? cs.primary.withValues(alpha: 0.08)
            : const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(14),
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
            width: 32,
            child: rank <= 3
                ? Text(
                    rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '#$rank',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _rankColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      color: isMe ? cs.primary : cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('you',
                        style: GoogleFonts.manrope(
                            fontSize: 9,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? _rankColor : cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text('paaths',
                  style: GoogleFonts.manrope(
                      fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
