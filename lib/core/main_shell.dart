import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import 'reminder_navigation.dart';
import '../data/repositories/app_repository.dart';
import '../features/home/home_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/play/play_screen.dart';
import 'audio_handler.dart';
import 'responsive.dart';
import 'transitions.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _homeRefreshSignal = 0;
  int _progressRefreshSignal = 0;
  bool _wasPlayScreenOpen = false;
  int _lastConsumedReminderTapVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rebuild when PlayScreen opens/closes or when the handler becomes ready.
    isPlayScreenOpen.addListener(_onPlayScreenChanged);
    audioHandlerNotifier.addListener(_onStateChanged);
    reminderNotificationTapVersion.addListener(_onReminderTapVersion);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _tryOpenPlayFromReminder());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isPlayScreenOpen.removeListener(_onPlayScreenChanged);
    audioHandlerNotifier.removeListener(_onStateChanged);
    reminderNotificationTapVersion.removeListener(_onReminderTapVersion);
    super.dispose();
  }

  void _onReminderTapVersion() {
    _tryOpenPlayFromReminder();
  }

  Future<void> _tryOpenPlayFromReminder() async {
    if (!mounted) return;
    final v = reminderNotificationTapVersion.value;
    if (v <= _lastConsumedReminderTapVersion) return;
    if (isPlayScreenOpen.value) return;

    final settings = await AppRepository.instance.getSettings();
    if (!mounted) return;
    if (isPlayScreenOpen.value) return;

    _lastConsumedReminderTapVersion = v;
    await Navigator.of(context).push(
      slideUpRoute(
        PlayScreen(
          initialTarget: settings.targetCount,
          initialTrackId: settings.preferredTrack,
          beginPaathImmediately: true,
        ),
      ),
    );
  }

  void _onPlayScreenChanged() {
    final isNowOpen = isPlayScreenOpen.value;
    // Play screen just closed — reload progress data so heatmap/stats are fresh.
    if (_wasPlayScreenOpen && !isNowOpen) {
      _progressRefreshSignal++;
    }
    _wasPlayScreenOpen = isNowOpen;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppRepository.instance.flushPendingSyncs());
    }
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handler = audioHandlerNotifier.value;
    final showMiniPlayer =
        handler != null &&
        handler.duration > Duration.zero &&
        !isPlayScreenOpen.value;

    final screens = [
      HomeScreen(
        refreshSignal: _homeRefreshSignal,
        onSwitchToSettings: () => setState(() => _currentIndex = 3),
      ),
      ProgressScreen(refreshSignal: _progressRefreshSignal),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
          // Mini-player slides in/out smoothly above the bottom nav.
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: showMiniPlayer
                ? _MiniPlayer(handler: handler)
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _SacredNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 0 && _currentIndex != 0) _homeRefreshSignal++;
          if (i == 1 && _currentIndex != 1) _progressRefreshSignal++;
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

// ── Mini-player ────────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final HanumanAudioHandler handler;
  const _MiniPlayer({required this.handler});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        final settings = await AppRepository.instance.getSettings();
        if (!context.mounted) return;
        Navigator.of(context).push(
          slideUpRoute(PlayScreen(initialTrackId: settings.preferredTrack)),
        );
      },
      child: Container(
        color: cs.surfaceContainerLow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Thin progress bar at the very top ─────────────────────
            StreamBuilder<Duration>(
              stream: handler.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = handler.duration;
                final progress = total.inMilliseconds > 0
                    ? (pos.inMilliseconds / total.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: context.sp(2),
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.secondary),
                );
              },
            ),

            // ── Track info + controls ──────────────────────────────────
            StreamBuilder<PlayerState>(
              stream: handler.playerStateStream,
              builder: (context, snap) {
                final ps = snap.data;
                // Some audio backends may leave `playing=true` even after the
                // track transitions to `completed`. Treat completed as paused
                // for UI purposes.
                final isPlaying = (ps?.playing ?? false) &&
                    ps?.processingState != ProcessingState.completed;
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.sp(20),
                      vertical: context.sp(10)),
                  child: Row(
                    children: [
                      // Animated playing indicator
                      _PlayingDots(isPlaying: isPlaying, cs: cs),
                      SizedBox(width: context.sp(12)),

                      // Track title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hanuman Chalisa',
                              style: GoogleFonts.notoSerif(
                                  fontSize: context.sp(14),
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              isPlaying ? 'Playing' : 'Paused',
                              style: GoogleFonts.manrope(
                                  fontSize: context.sp(10),
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),

                      // Play / Pause
                      GestureDetector(
                        onTap: () async {
                          // If the track is in `completed`, `play()` may not restart
                          // from the beginning. Seek to 0 first for a smoother UX.
                          if (ps?.processingState == ProcessingState.completed) {
                            await handler.seek(Duration.zero);
                            await handler.play();
                            return;
                          }
                          if (isPlaying) {
                            await handler.pause();
                          } else {
                            await handler.play();
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: context.sp(40),
                          height: context.sp(40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: cs.primary,
                            size: context.sp(22),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Small animated dots to signal active playback.
class _PlayingDots extends StatefulWidget {
  final bool isPlaying;
  final ColorScheme cs;
  const _PlayingDots({required this.isPlaying, required this.cs});

  @override
  State<_PlayingDots> createState() => _PlayingDotsState();
}

class _PlayingDotsState extends State<_PlayingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PlayingDots old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return SizedBox(
      width: context.sp(20),
      height: context.sp(28),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              // Stagger each bar with a phase offset.
              final phase = ((_ctrl.value + i * 0.33) % 1.0);
              final h = context.sp(6) +
                  context.sp(16) * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Container(
                width: context.sp(4),
                height: h,
                decoration: BoxDecoration(
                  color: widget.isPlaying
                      ? cs.secondary
                      : cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Bottom nav bar ─────────────────────────────────────────────────────────────

class _SacredNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SacredNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    const icons = [
      Icons.home_rounded,
      Icons.auto_graph_rounded,
      Icons.emoji_events_rounded,
      Icons.settings_rounded,
    ];
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.95),
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.sp(28))),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(context.sp(16), context.sp(14), context.sp(16), context.sp(14) + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (i) {
          final isSelected = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: context.sp(48),
              height: context.sp(48),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: cs.primary.withValues(alpha: 0.4),
                            blurRadius: 15)
                      ]
                    : null,
              ),
              child: Icon(
                icons[i],
                color: isSelected
                    ? cs.onPrimary
                    : cs.primary.withValues(alpha: 0.5),
                size: context.sp(22),
              ),
            ),
          );
        }),
      ),
    );
  }
}
