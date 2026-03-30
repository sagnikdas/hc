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

class PlayScreen extends StatefulWidget {
  final int? initialTarget;
  final String? initialVoice;
  final String? initialTrackId;
  @visibleForTesting
  final Set<int>? debugMilestones;
  @visibleForTesting
  final Future<String> Function()? debugReferralCodeProvider;
  @visibleForTesting
  final Future<void> Function()? debugSaveSessionOverride;
  const PlayScreen({
    super.key,
    this.initialTarget,
    this.initialVoice,
    this.initialTrackId,
    this.debugMilestones,
    this.debugReferralCodeProvider,
    this.debugSaveSessionOverride,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
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

  @override
  void initState() {
    super.initState();
    _currentTrack = trackById(widget.initialTrackId ?? widget.initialVoice);
    // Defer to avoid setState-during-build on the parent MainShell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isPlayScreenOpen.value = true;
    });
    if (widget.initialTarget != null) _targetCount = widget.initialTarget!;
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
      if (widget.initialTarget == null) _targetCount = settings.targetCount;
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

  void _initAudio(HanumanAudioHandler handler) {
    if (_audioInitialized) return;
    _audioInitialized = true;
    _loadAudio();
    _playerStateSub = handler.playerStateStream.listen(_onPlayerState);
  }

  Future<void> _loadAudio() async {
    try {
      final handler = audioHandler!;
      // If audio is already loaded (e.g. returning via mini-player), skip
      // reloading so playback continues uninterrupted.
      if (handler.duration > Duration.zero) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      await lyricsService.loadTrack(_currentTrack.lyricsPath);
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
    await lyricsService.loadTrack(newTrack.lyricsPath);
    await audioHandler!.loadVoice(newTrack.assetPath);
    if (!mounted) return;
    await audioHandler!.seek(Duration.zero);
    await audioHandler!.play();
    if (mounted) setState(() {});
  }

  Future<void> _showTrackPicker() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131313),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Recitation',
                  style: GoogleFonts.notoSerif(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                for (final track in kAudioTracks) ...[
                  _TrackPickerTile(
                    track: track,
                    selected: track.id == _currentTrack.id,
                    cs: cs,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _switchTrack(track);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
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

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131313),
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
                  cs.surfaceContainerLow
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Decorative saffron/gold stripe.
                  Container(
                    height: 10,
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
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
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
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Milestone complete!',
                    style: GoogleFonts.notoSerif(
                      fontSize: 22,
                      color: cs.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have completed $count recitations today.',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.86),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
          return const Scaffold(
            backgroundColor: Color(0xFF131313),
            body: Center(child: CircularProgressIndicator()),
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
          backgroundColor: const Color(0xFF131313),
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
                        positionStream: handler.positionStream,
                        cs: cs,
                      ),
                    ),
                    _buildPlayerSection(context, cs, isPlaying, handler),
                  ],
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
                    color: done ? cs.secondary : cs.primary,
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

          // ── Chips — only updates when user taps ───────────────────────
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(
                          horizontal: context.sp(18), vertical: context.sp(8)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.3),
                                    blurRadius: 18)
                              ]
                            : null,
                      ),
                      child: Text(
                        '${c}X',
                        style: GoogleFonts.manrope(
                          fontSize: context.sp(11),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isSelected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: context.sp(10)),

          // ── Track switcher chip ───────────────────────────────────────
          GestureDetector(
            onTap: _showTrackPicker,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.sp(12), vertical: context.sp(6)),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: context.sp(13)),
                  SizedBox(width: context.sp(5)),
                  Text(
                    _currentTrack.name,
                    style: GoogleFonts.manrope(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: context.sp(4)),
                  Icon(Icons.expand_more_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.6),
                      size: context.sp(14)),
                ],
              ),
            ),
          ),

          SizedBox(height: context.sp(10)),

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
                      inactiveTrackColor: const Color(0xFF353534),
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
      child: GestureDetector(
        onTap: () => setState(() => _showVolume = false),
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: overlayWidth,
          height: overlayHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1B).withValues(alpha: 0.95),
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
                      inactiveTrackColor: const Color(0xFF353534),
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
      child: GestureDetector(
        onTap: () => setState(() => _showSpeed = false),
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: overlayWidth,
          height: overlayHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(100),
          ),
          padding: EdgeInsets.symmetric(vertical: context.sp(12)),
          child: Column(
            children: [
              Text(
                '5×',
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
                      inactiveTrackColor: const Color(0xFF353534),
                      thumbColor: cs.primary,
                      overlayColor: cs.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _speed,
                      min: 0.5,
                      max: 5.0,
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
                const Color(0xFF131313).withValues(alpha: 0.5),
                Colors.transparent,
                const Color(0xFF131313),
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
          color: active
              ? cs.primary.withValues(alpha: 0.2)
              : const Color(0xFF1C1B1B),
        ),
        child: Icon(
          icon,
          color: active
              ? cs.primary
              : onTap != null
                  ? cs.onSurfaceVariant
                  : cs.onSurfaceVariant.withValues(alpha: 0.3),
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
          color: active
              ? cs.primary.withValues(alpha: 0.2)
              : const Color(0xFF1C1B1B),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w700,
            color: active ? cs.primary : cs.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Track picker tile (used inside modal bottom sheet) ─────────────────────────
class _TrackPickerTile extends StatelessWidget {
  final AudioTrack track;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TrackPickerTile({
    required this.track,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  static const _icons = {
    'traditional': Icons.surround_sound_rounded,
    'male': Icons.record_voice_over_rounded,
    'female': Icons.mic_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? cs.primary : Colors.white12;
    final bgColor = selected
        ? cs.primary.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              _icons[track.id] ?? Icons.music_note_rounded,
              color: selected ? cs.primary : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: GoogleFonts.notoSerif(
                      color: selected ? cs.primary : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    track.description,
                    style: GoogleFonts.manrope(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
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
  final ColorScheme cs;
  const _LyricsPanel({required this.positionStream, required this.cs});

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
    if (old.positionStream != widget.positionStream) {
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
    final idx = lyricsService.currentLineIndex(pos);
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
        color: const Color(0xFF252424),
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
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(context.sp(14)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF131313)
                : cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
