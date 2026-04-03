import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';
import '../../core/audio_handler.dart';
import '../../core/responsive.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/models/play_session.dart';
import '../../data/models/audio_track.dart';
import '../../data/models/user_settings.dart';

class PlayScreen extends StatefulWidget {
  final String? initialTrackId;

  /// When true (e.g. opened from a reminder tap), start playback from the
  /// beginning once audio is ready, including when the same track is cached.
  final bool beginPaathImmediately;
  @visibleForTesting
  final Set<int>? debugMilestones;
  @visibleForTesting
  final Future<String> Function()? debugReferralCodeProvider;
  @visibleForTesting
  final Future<void> Function()? debugSaveSessionOverride;
  @visibleForTesting
  final bool debugChipsOpen;
  const PlayScreen({
    super.key,
    this.initialTrackId,
    this.beginPaathImmediately = false,
    this.debugMilestones,
    this.debugReferralCodeProvider,
    this.debugSaveSessionOverride,
    this.debugChipsOpen = false,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  static const _quickCounts = [1, 11, 21, 108];
  // Milestone bottom-sheet triggers.
  static const _milestones = {11, 21, 108};

  late AudioTrack _currentTrack;
  Set<int> get _activeMilestones => widget.debugMilestones ?? _milestones;

  // Guard: _initAudio must only wire up once even if handler becomes ready
  // after initState fires the listener path.
  bool _audioInitialized = false;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _loaded = false;
  bool _continuousPlay = false;
  bool _hapticEnabled = true;
  double _volume = 1.0;
  bool _showVolume = false;
  double _speed = 1.0;
  bool _showSpeed = false;
  Timer? _volumeTimer;
  Timer? _speedTimer;

  int _completedCount = 0;
  int _targetCount = 11;
  bool _seekForwardThisRound = false;
  bool _completionHandled = false;
  final Set<int> _shownMilestones = <int>{};

  // Chip panel animation
  bool _chipsOpen = false;
  late AnimationController _chipsCtrl;
  late Animation<double> _chipsAnim;

  @override
  void initState() {
    super.initState();
    _currentTrack = trackById(widget.initialTrackId);
    // Defer to avoid setState-during-build on the parent MainShell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isPlayScreenOpen.value = true;
    });
    _chipsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _chipsAnim = CurvedAnimation(
      parent: _chipsCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (widget.debugChipsOpen) {
      _chipsOpen = true;
      _chipsCtrl.value = 1.0;
    }
    _loadSettings();
    final handler = audioHandler;
    if (handler != null) {
      _initAudio(handler);
    } else {
      audioHandlerNotifier.addListener(_onHandlerReady);
    }
  }

  Future<void> _loadSettings() async {
    final settings = await AppRepository.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _continuousPlay = settings.continuousPlay;
      _hapticEnabled = settings.hapticEnabled;
      _speed = settings.playbackSpeed;
      // Only read volume from handler if it's already available.
      final h = audioHandler;
      if (h != null) {
        _volume = h.volume;
        h.setSpeed(_speed);
      }
    });
  }

  void _onHandlerReady() {
    final handler = audioHandlerNotifier.value;
    if (handler != null) {
      audioHandlerNotifier.removeListener(_onHandlerReady);
      _initAudio(handler);
    }
  }

  String _getCountLabel(int count) {
    switch (count) {
      case 1:
        return 'ONCE';
      case 11:
        return 'EKADASHA';
      case 21:
        return 'VIMSATI';
      case 108:
        return 'MALA';
      default:
        return '';
    }
  }

  void _initAudio(HanumanAudioHandler handler) {
    if (_audioInitialized) return;
    _audioInitialized = true;
    _loadAudio();
    _playerStateSub = handler.playerStateStream.listen(_onPlayerState);
  }

  Future<void> _loadAudio() async {
    try {
      final handler = audioHandler!;
      await lyricsService.loadTrack(
        _currentTrack.lyricsPath,
        lyricSyncCurveExponent: _currentTrack.lyricSyncCurveExponent,
      );
      // If audio is already loaded, only reuse it when it matches the
      // selected track. Otherwise, force-load the selected track to keep
      // audio and lyrics aligned.
      if (handler.duration > Duration.zero &&
          handler.currentAssetPath == _currentTrack.assetPath) {
        if (mounted) setState(() => _loaded = true);
        if (widget.beginPaathImmediately) {
          try {
            await handler.seek(Duration.zero);
            await handler.play();
          } catch (e) {
            debugPrint('beginPaathImmediately: $e');
          }
        }
        return;
      }
      await handler.loadVoice(_currentTrack.assetPath);
      if (!mounted) return;
      setState(() => _loaded = true);
      await handler.play();
    } catch (e) {
      debugPrint('Audio load failed: $e');
    }
  }

  Future<void> _switchTrack(AudioTrack newTrack) async {
    if (newTrack.id == _currentTrack.id) return;
    setState(() {
      _currentTrack = newTrack;
      _completedCount = 0;
      _seekForwardThisRound = false;
      _completionHandled = false;
      _shownMilestones.clear();
    });
    final s = await AppRepository.instance.getSettings();
    await AppRepository.instance.saveSettings(s.copyWith(preferredTrack: newTrack.id));
    await lyricsService.loadTrack(
      newTrack.lyricsPath,
      lyricSyncCurveExponent: newTrack.lyricSyncCurveExponent,
    );
    await audioHandler!.loadVoice(newTrack.assetPath);
    if (!mounted) return;
    await audioHandler!.seek(Duration.zero);
    await audioHandler!.play();
    if (mounted) setState(() {});
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed &&
        !_completionHandled) {
      _completionHandled = true;
      _handleCompletion();
    }
  }

  Future<void> _handleCompletion() async {
    if (!mounted) return;
    final counted = !_seekForwardThisRound;
    if (counted) {
      setState(() => _completedCount++);
      await _saveSession();
      audioHandler?.setCompletionCount(_completedCount);
      if (_hapticEnabled) HapticFeedback.mediumImpact();
      await _maybeShowMilestoneSheet(_completedCount);
    }
    _seekForwardThisRound = false;

    final done = _targetCount > 0 && _completedCount >= _targetCount;
    if (done) {
      if (_hapticEnabled) {
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.heavyImpact();
      }
    } else {
      if (!_continuousPlay) await audioHandler!.pause();
      await audioHandler!.seek(Duration.zero);
      if (_continuousPlay) await audioHandler!.play();
      if (mounted) setState(() => _completionHandled = false);
    }
  }

  Future<void> _saveSession() async {
    final override = widget.debugSaveSessionOverride;
    if (override != null) {
      await override();
      return;
    }
    final now = DateTime.now();
    await AppRepository.instance.insertSession(PlaySession(
      date: AppRepository.dateStr(now),
      count: 1,
      completedAt: now.millisecondsSinceEpoch,
    ));

    // Track completion event for analytics
    try {
      final duration = audioHandler?.duration ?? Duration.zero;
      await analytics.logEvent(
        name: 'audio_completed',
        parameters: {
          'duration_seconds': duration.inSeconds,
          'completed_count': _completedCount,
          'target_count': _targetCount,
          'timestamp': now.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  Future<void> _maybeShowMilestoneSheet(int count) async {
    if (!_activeMilestones.contains(count)) return;
    if (_shownMilestones.contains(count)) return;
    _shownMilestones.add(count);
    if (!mounted) return;

    final provider = widget.debugReferralCodeProvider;
    final referralCode = provider != null
        ? await provider()
        : await AppRepository.instance.getOrCreateReferralCode();
    if (!mounted) return;
    final shareText =
        'Jai Hanuman! I completed $count Hanuman Chalisa recitations today.\n\n'
        'Join me on this daily sankalp. Use my referral code: $referralCode';

    final sheetCs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetCs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surfaceContainerLow,
                  cs.surfaceContainer,
                  cs.surfaceContainerLow,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(ctx.sp(20), ctx.sp(16), ctx.sp(20), ctx.sp(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Decorative saffron/gold stripe.
                  Container(
                    height: ctx.sp(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary, cs.tertiary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: ctx.sp(14)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: ctx.sp(64),
                        height: ctx.sp(64),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [cs.primary.withValues(alpha: 0.20), cs.secondary.withValues(alpha: 0.12)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.25),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/hanumanji_icon.png',
                            width: ctx.sp(38),
                            height: ctx.sp(38),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(width: ctx.sp(14)),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ctx.sp(12),
                            vertical: ctx.sp(8),
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primaryContainer.withValues(alpha: 0.22),
                                blurRadius: 26,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            'Milestone: $count',
                            style: GoogleFonts.notoSerif(
                              fontSize: ctx.sp(16),
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ctx.sp(14)),
                  Text(
                    'Milestone complete!',
                    style: GoogleFonts.notoSerif(
                      fontSize: ctx.sp(22),
                      color: cs.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: ctx.sp(8)),
                  Text(
                    'You have completed $count recitations today.',
                    style: GoogleFonts.manrope(
                      fontSize: ctx.sp(14),
                      color: cs.onSurface.withValues(alpha: 0.86),
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: ctx.sp(16)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: ctx.sp(14)),
                        side: BorderSide(color: Colors.white, width: ctx.sp(1.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ctx.sp(14)),
                        ),
                      ),
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(
                            text: shareText,
                            subject: 'Hanuman Chalisa Milestone',
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share on WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onPlay() => audioHandler!.play();
  Future<void> _onPause() => audioHandler!.pause();
  Future<void> _onPlayAgainFromStart() async {
    // When the session is "done" (completed >= targetCount), the track is
    // typically at end-of-media. Calling play() alone may not restart.
    setState(() {
      _completedCount = 0;
      _seekForwardThisRound = false;
      _completionHandled = false;
      _shownMilestones.clear(); // allow milestones again for the new run
    });
    await audioHandler!.seek(Duration.zero);
    await audioHandler!.play();
  }

  Future<void> _onSeek(double value) async {
    final handler = audioHandler!;
    final targetMs = (value * handler.duration.inMilliseconds).round();
    if (targetMs > handler.position.inMilliseconds + 5000) {
      setState(() => _seekForwardThisRound = true);
    }
    await handler.seek(Duration(milliseconds: targetMs));
  }

  Future<void> _onRestart() async {
    setState(() {
      _seekForwardThisRound = false;
      _completionHandled = false;
    });
    await audioHandler!.seek(Duration.zero);
    await audioHandler!.play();
  }

  Future<void> _onSkipNext() async {
    if (!_loaded) return;
    final handler = audioHandler!;
    setState(() => _seekForwardThisRound = true);
    final nearEndMs = math.max(0, handler.duration.inMilliseconds - 300);
    final nearEnd = Duration(milliseconds: nearEndMs);
    await handler.seek(nearEnd);
    if (!handler.playing) await handler.play();
  }

  void _setTarget(int target) => setState(() {
        _targetCount = target;
        _completedCount = 0;
        _seekForwardThisRound = false;
        _completionHandled = false;
      });

  static const _overlayAutohide = Duration(seconds: 3);

  void _startVolumeTimer() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer(_overlayAutohide, () {
      if (mounted) setState(() => _showVolume = false);
    });
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = Timer(_overlayAutohide, () {
      if (mounted) setState(() => _showSpeed = false);
    });
  }

  void _dismissControlOverlays() {
    _volumeTimer?.cancel();
    _speedTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showVolume = false;
      _showSpeed = false;
    });
  }

  void _onVolumeChanged(double v) {
    setState(() => _volume = v);
    audioHandler?.setVolume(v);
    _startVolumeTimer(); // reset the countdown on every drag tick
  }

  void _onSpeedSlide(double s) {
    setState(() => _speed = s);
    audioHandler?.setSpeed(s);
    _startSpeedTimer(); // reset the countdown on every drag tick
  }

  Future<void> _onSpeedEnd(double s) async {
    final settings = await AppRepository.instance.getSettings();
    await AppRepository.instance.saveSettings(settings.copyWith(playbackSpeed: s));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _volumeTimer?.cancel();
    _speedTimer?.cancel();
    _chipsCtrl.dispose();
    // Avoid notifying listeners while the framework is finalizing the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isPlayScreenOpen.value = false;
    });
    audioHandlerNotifier.removeListener(_onHandlerReady);
    _playerStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HanumanAudioHandler?>(
      valueListenable: audioHandlerNotifier,
      builder: (context, handler, child) {
        if (handler == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildPlayer(context, handler);
      },
    );
  }

  Widget _buildPlayer(BuildContext context, HanumanAudioHandler handler) {
    final cs = Theme.of(context).colorScheme;

    // StreamBuilder only covers play/pause state changes — low frequency.
    // Position-driven rebuilds are isolated inside _LyricsPanel and
    // the StreamBuilder<Duration> in _buildProgressBar.
    return StreamBuilder<PlayerState>(
      stream: handler.playerStateStream,
      builder: (context, snap) {
        final ps = snap.data;
        // Some audio backends may keep `playing=true` after the track
        // transitions to `completed`. For UI purposes, treat completed as
        // paused/stopped.
        final isPlaying =
            (ps?.playing ?? false) && ps?.processingState != ProcessingState.completed;
        return Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Static background — never rebuilds during playback ──────
              _BackgroundLayer(cs: cs),
              // ── Content ───────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, cs),
                    // Lyrics panel manages its own position subscription.
                    Expanded(
                      child: _LyricsPanel(
                        key: ValueKey<String>(_currentTrack.id),
                        positionStream: handler.positionStream,
                        lyricSyncClockLead: _currentTrack.lyricSyncClockLead,
                        cs: cs,
                      ),
                    ),
                    _buildPlayerSection(context, cs, isPlaying, handler),
                  ],
                ),
              ),
              if (_showVolume || _showSpeed)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _dismissControlOverlays,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
              if (_showVolume) _buildVolumeOverlay(context, cs),
              if (_showSpeed) _buildSpeedOverlay(context, cs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(20), vertical: context.sp(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: cs.primary, size: context.sp(22)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text('Hanuman Chalisa',
              style: GoogleFonts.notoSerif(fontSize: context.sp(19), color: cs.primary)),
          IconButton(
            icon: Icon(Icons.share_outlined, color: cs.primary, size: context.sp(20)),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'जय हनुमान! I\'ve been doing Hanuman Chalisa paath daily. Join me 🙏\n\nSearch \'Hanuman Chalisa\' on the Play Store.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSection(
    BuildContext context,
    ColorScheme cs,
    bool isPlaying,
    HanumanAudioHandler handler,
  ) {
    final done = _targetCount > 0 && _completedCount >= _targetCount;

    return Container(
      padding: EdgeInsets.fromLTRB(context.sp(20), 0, context.sp(20), context.sp(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Counter — only updates on completion (~11 times per session) ──
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_completedCount',
                  style: GoogleFonts.notoSerif(
                    fontSize: context.sp(42),
                    color: done ? cs.secondary : cs.onPrimary,
                    height: 1,
                  ),
                ),
                Text(
                  ' / $_targetCount',
                  style: GoogleFonts.manrope(
                    fontSize: context.sp(16),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (done) ...[
                  SizedBox(width: context.sp(10)),
                  Text('जय हनुमान',
                      style: GoogleFonts.notoSerif(
                          fontSize: context.sp(14), color: cs.secondary)),
                ],
              ],
            ),
          ),

          // ── Tune FAB Button ───────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              setState(() => _chipsOpen = !_chipsOpen);
              if (_chipsOpen) {
                _chipsCtrl.forward();
              } else {
                _chipsCtrl.reverse();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(16),
                vertical: context.sp(10),
              ),
              decoration: BoxDecoration(
                gradient: _chipsOpen
                    ? LinearGradient(
                        colors: [cs.primary, cs.secondary, cs.tertiary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : LinearGradient(
                        colors: [
                          cs.surfaceContainerHigh,
                          cs.surfaceContainerHigh.withValues(alpha: 0.6),
                        ],
                      ),
                borderRadius: BorderRadius.circular(context.sp(20)),
                border: Border.all(
                  color: _chipsOpen
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant.withValues(alpha: 0.2),
                  width: _chipsOpen ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _chipsOpen
                        ? cs.primary.withValues(alpha: 0.25)
                        : Colors.transparent,
                    blurRadius: _chipsOpen ? 12 : 0,
                    offset: Offset(0, _chipsOpen ? 4 : 0),
                    spreadRadius: _chipsOpen ? 1 : 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: _chipsOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _chipsOpen ? cs.onPrimary : cs.onSurfaceVariant,
                      size: context.sp(18),
                    ),
                  ),
                  SizedBox(width: context.sp(8)),
                  Text(
                    _chipsOpen ? 'Hide' : 'Settings',
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                      color: _chipsOpen ? cs.onPrimary : cs.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: context.sp(8)),

          // ── Animated Chip Panel ────────────────────────────────────────────
          ClipRect(
            child: SizeTransition(
              sizeFactor: _chipsAnim,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _chipsAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                  // ── Count Chips ─────────────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _quickCounts.map((c) {
                      final isSelected = c == _targetCount;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.sp(4)),
                        child: GestureDetector(
                          onTap: () => _setTarget(c),
                          child: SizedBox(
                            width: context.sp(76),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                vertical: context.sp(12),
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          cs.primary,
                                          cs.secondary,
                                          cs.tertiary
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          cs.surfaceContainerHigh,
                                          cs.surfaceContainerHigh
                                              .withValues(alpha: 0.6),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(context.sp(16)),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary.withValues(alpha: 0.5)
                                      : cs.outlineVariant.withValues(alpha: 0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? cs.primary.withValues(alpha: 0.35)
                                        : Colors.transparent,
                                    blurRadius: isSelected ? 24 : 0,
                                    offset: Offset(0, isSelected ? 8 : 0),
                                    spreadRadius: isSelected ? 2 : 0,
                                  ),
                                  if (isSelected)
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                    ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${c}×',
                                    style: GoogleFonts.notoSerif(
                                      fontSize: context.sp(16),
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? cs.onPrimary
                                          : cs.onSurfaceVariant,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: context.sp(2)),
                                  Text(
                                    _getCountLabel(c),
                                    style: GoogleFonts.manrope(
                                      fontSize: context.sp(8),
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? cs.onPrimary.withValues(alpha: 0.9)
                                          : cs.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    ),
                  ),

                  SizedBox(height: context.sp(10)),

                  // ── Track Chips ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final track in kAudioTracks)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.sp(4)),
                          child: GestureDetector(
                            onTap: () => _switchTrack(track),
                            child: SizedBox(
                              width: context.sp(76),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(
                                  vertical: context.sp(14),
                                ),
                                decoration: BoxDecoration(
                                  gradient: track.id == _currentTrack.id
                                      ? LinearGradient(
                                          colors: [
                                            cs.primary,
                                            cs.secondary,
                                            cs.tertiary
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            cs.surfaceContainerHigh,
                                            cs.surfaceContainerHigh
                                                .withValues(alpha: 0.5),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(context.sp(18)),
                                  border: Border.all(
                                    color: track.id == _currentTrack.id
                                        ? cs.primary.withValues(alpha: 0.6)
                                        : cs.outlineVariant.withValues(alpha: 0.15),
                                    width:
                                        track.id == _currentTrack.id ? 2.5 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: track.id == _currentTrack.id
                                          ? cs.primary.withValues(alpha: 0.4)
                                          : Colors.transparent,
                                      blurRadius:
                                          track.id == _currentTrack.id ? 28 : 0,
                                      offset: Offset(
                                          0,
                                          track.id == _currentTrack.id
                                              ? 10
                                              : 0),
                                      spreadRadius:
                                          track.id == _currentTrack.id ? 3 : 0,
                                    ),
                                    if (track.id == _currentTrack.id)
                                      BoxShadow(
                                        color: cs.primary.withValues(alpha: 0.12),
                                        blurRadius: 16,
                                        spreadRadius: 6,
                                      ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      scale: track.id == _currentTrack.id
                                          ? 1.2
                                          : 1.0,
                                      child: Icon(
                                        track.id == 'male'
                                            ? Icons.man_rounded
                                            : Icons.woman_rounded,
                                        color: track.id == _currentTrack.id
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                        size: context.sp(24),
                                      ),
                                    ),
                                    SizedBox(height: context.sp(6)),
                                    Text(
                                      track.id == 'male' ? 'Male' : 'Female',
                                      style: GoogleFonts.manrope(
                                        fontSize: context.sp(11),
                                        fontWeight: FontWeight.w700,
                                        color: track.id == _currentTrack.id
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                    SizedBox(height: context.sp(10)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Progress bar + time — isolated StreamBuilder, ~1fps ───────
          StreamBuilder<Duration>(
            stream: handler.positionStream,
            builder: (context, posSnap) {
              final pos = posSnap.data ?? Duration.zero;
              final total = handler.duration;
              final progress = total.inMilliseconds > 0
                  ? (pos.inMilliseconds / total.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: context.sp(2),
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: context.sp(4)),
                      overlayShape:
                          RoundSliderOverlayShape(overlayRadius: context.sp(12)),
                      activeTrackColor: cs.secondary,
                      inactiveTrackColor: cs.surfaceContainerHighest,
                      thumbColor: cs.secondary,
                      overlayColor: cs.secondary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                        value: progress,
                        onChanged: _loaded ? _onSeek : null),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.sp(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: GoogleFonts.manrope(
                                fontSize: context.sp(10),
                                color: cs.onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5)),
                        Text(_fmt(total),
                            style: GoogleFonts.manrope(
                                fontSize: context.sp(10),
                                color: cs.onSurface.withValues(alpha: 0.5),
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.sp(12)),

          // ── Controls — updates only when isPlaying changes ────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SpeedButton(
                speed: _speed,
                active: _showSpeed,
                cs: cs,
                onTap: () {
                  setState(() => _showSpeed = !_showSpeed);
                  if (_showSpeed) _startSpeedTimer();
                },
              ),
              Row(children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded,
                      color: cs.onSurface, size: context.sp(28)),
                  onPressed: _loaded ? _onRestart : null,
                ),
                SizedBox(width: context.sp(12)),
                GestureDetector(
                  onTap: _loaded
                      ? (done ? _onPlayAgainFromStart : (isPlaying ? _onPause : _onPlay))
                      : null,
                  child: Container(
                    width: context.sp(72),
                    height: context.sp(72),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primary, cs.primaryContainer],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: cs.onPrimary,
                      size: context.sp(38),
                    ),
                  ),
                ),
                SizedBox(width: context.sp(12)),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded,
                      color: cs.onSurface, size: context.sp(28)),
                  onPressed: _loaded && !done ? _onSkipNext : null,
                ),
              ]),
              _ControlButton(
                icon: _volume == 0
                    ? Icons.volume_off_rounded
                    : _volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                onTap: () {
                  setState(() => _showVolume = !_showVolume);
                  if (_showVolume) _startVolumeTimer();
                },
                cs: cs,
                active: _showVolume,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVolumeOverlay(BuildContext context, ColorScheme cs) {
    // Anchor above the player section. Player section is roughly 200 dp tall
    // (counter + chips + progress + controls) plus safe area bottom.
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final overlayBottom = safeBottom + context.sp(190);
    final overlayWidth = context.sp(52);
    final overlayHeight = context.sp(200);

    return Positioned(
      bottom: overlayBottom,
      right: context.sp(20),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: overlayWidth,
          height: overlayHeight,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(100),
          ),
          padding: EdgeInsets.symmetric(vertical: context.sp(12)),
          child: Column(
            children: [
              Icon(Icons.volume_up_rounded, color: cs.primary, size: context.sp(18)),
              SizedBox(height: context.sp(4)),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: context.sp(2),
                      thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: context.sp(6)),
                      overlayShape: RoundSliderOverlayShape(
                          overlayRadius: context.sp(12)),
                      activeTrackColor: cs.primary,
                      inactiveTrackColor: cs.surfaceContainerHighest,
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _volume,
                      onChanged: _onVolumeChanged,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.sp(4)),
              Icon(Icons.volume_off_rounded,
                  color: cs.primary.withValues(alpha: 0.5),
                  size: context.sp(16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedOverlay(BuildContext context, ColorScheme cs) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final overlayBottom = safeBottom + context.sp(190);
    final overlayWidth = context.sp(52);
    final overlayHeight = context.sp(200);

    return Positioned(
      bottom: overlayBottom,
      left: context.sp(20),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: overlayWidth,
          height: overlayHeight,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(100),
          ),
          padding: EdgeInsets.symmetric(vertical: context.sp(12)),
          child: Column(
            children: [
              Text(
                '${UserSettings.maxPlaybackSpeed.toStringAsFixed(1)}×',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(10),
                    color: cs.primary,
                    fontWeight: FontWeight.w700),
              ),
              SizedBox(height: context.sp(4)),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: context.sp(2),
                      thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: context.sp(6)),
                      overlayShape: RoundSliderOverlayShape(
                          overlayRadius: context.sp(12)),
                      activeTrackColor: cs.primary,
                      inactiveTrackColor: cs.surfaceContainerHighest,
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _speed.clamp(
                        UserSettings.minPlaybackSpeed,
                        UserSettings.maxPlaybackSpeed,
                      ),
                      min: UserSettings.minPlaybackSpeed,
                      max: UserSettings.maxPlaybackSpeed,
                      onChanged: _onSpeedSlide,
                      onChangeEnd: _onSpeedEnd,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.sp(4)),
              Text(
                '0.5×',
                style: GoogleFonts.manrope(
                    fontSize: context.sp(10),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Static background — extracted so it never participates in rebuilds ─────────
class _BackgroundLayer extends StatelessWidget {
  final ColorScheme cs;
  const _BackgroundLayer({required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColor = isDark ? cs.primaryContainer : cs.primary;
    final gradientTopColor = gradientColor.withValues(alpha: 0.55);
    final gradientBottomColor = gradientColor.withValues(alpha: 0.68);

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.20,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: Image.asset(
              'assets/images/hanuman_player_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientTopColor,
                Colors.transparent,
                gradientBottomColor,
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
        ),
        // ॐ symbol: per original design, it sits enlarged in the lower-right.
        Positioned(
          right: context.sp(22),
          bottom: context.sp(18),
          child: Text(
            'ॐ',
            style: GoogleFonts.notoSerif(
              fontSize: context.sp(220),
              color: cs.secondary.withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Control button ─────────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool active;
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.sp(44),
        height: context.sp(44),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primaryContainer],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? cs.onPrimary
              : cs.onPrimary.withValues(alpha: 0.35),
          size: context.sp(20),
        ),
      ),
    );
  }
}

// ── Speed button — shows current speed label, toggles speed overlay ────────────
class _SpeedButton extends StatelessWidget {
  final double speed;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _SpeedButton({
    required this.speed,
    required this.active,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '${speed.toStringAsFixed(1)}×';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: context.sp(44),
        height: context.sp(44),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primaryContainer],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w700,
            color: cs.onPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Lyrics panel — self-manages its own position subscription ──────────────────
// Only rebuilds when the active lyric line changes (~once every 10-30 seconds),
// not on every position tick.
class _LyricsPanel extends StatefulWidget {
  final Stream<Duration> positionStream;
  final Duration lyricSyncClockLead;
  final ColorScheme cs;
  const _LyricsPanel({
    super.key,
    required this.positionStream,
    required this.lyricSyncClockLead,
    required this.cs,
  });

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  // Updated in build() so _scrollToIndex always uses the correct scaled value.
  double _itemExtent = 56.0;
  final _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSub;
  int _currentIdx = 0;
  bool _showEnglish = false;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.positionStream.listen(_onPosition);
  }

  @override
  void didUpdateWidget(_LyricsPanel old) {
    super.didUpdateWidget(old);
    if (old.positionStream != widget.positionStream ||
        old.lyricSyncClockLead != widget.lyricSyncClockLead) {
      _positionSub?.cancel();
      _positionSub = widget.positionStream.listen(_onPosition);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPosition(Duration pos) {
    final shifted = pos - widget.lyricSyncClockLead;
    final forLyrics =
        shifted.isNegative ? Duration.zero : shifted;
    final idx = lyricsService.currentLineIndex(forLyrics);
    if (idx == _currentIdx) return; // no line change — skip rebuild entirely
    setState(() => _currentIdx = idx);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToIndex(_currentIdx));
  }

  void _scrollToIndex(int idx) {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final target = (idx * _itemExtent) - (viewport * 0.4);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    _itemExtent = context.sp(56.0);
    final lines = lyricsService.lines;
    final cs = widget.cs;

    if (lines.isEmpty) {
      return Center(
        child: Text('ॐ',
            style: GoogleFonts.notoSerif(
                fontSize: context.sp(64),
                color: cs.secondary.withValues(alpha: 0.4))),
      );
    }

    final hasTransliteration = lines.any((l) => l.transliteration != null);

    return Column(
      children: [
        // ── Language toggle ────────────────────────────────────────────────
        if (hasTransliteration)
          Padding(
            padding: EdgeInsets.only(top: context.sp(6), bottom: context.sp(2)),
            child: _LangToggle(
              showEnglish: _showEnglish,
              cs: cs,
              onToggle: (v) => setState(() => _showEnglish = v),
            ),
          ),

        // ── Lyrics list ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemExtent: _itemExtent,
            padding: EdgeInsets.symmetric(
                vertical: context.sp(8), horizontal: context.sp(32)),
            itemCount: lines.length,
            itemBuilder: (ctx, i) {
              final line = lines[i];
              final isActive = i == _currentIdx;
              final isNear = (i - _currentIdx).abs() == 1;
              final displayText = (_showEnglish && line.transliteration != null)
                  ? line.transliteration!
                  : line.text;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.center,
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (_showEnglish
                          ? GoogleFonts.manrope
                          : GoogleFonts.notoSerif)(
                    fontSize: isActive
                        ? context.sp(20)
                        : (isNear ? context.sp(15) : context.sp(13)),
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? cs.secondary
                        : isNear
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : cs.onSurface.withValues(alpha: 0.2),
                    height: 1.35,
                    shadows: isActive
                        ? [
                            Shadow(
                                color: cs.secondary.withValues(alpha: 0.3),
                                blurRadius: 12)
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Language toggle pill ────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final bool showEnglish;
  final ColorScheme cs;
  final ValueChanged<bool> onToggle;
  const _LangToggle(
      {required this.showEnglish,
      required this.cs,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.sp(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(context.sp(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(context, label: 'हि', selected: !showEnglish, onTap: () => onToggle(false)),
          _pill(context, label: 'EN', selected: showEnglish,  onTap: () => onToggle(true)),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: context.sp(44),
        height: context.sp(28),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [cs.primary, cs.secondary, cs.tertiary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(context.sp(14)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w600,
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
