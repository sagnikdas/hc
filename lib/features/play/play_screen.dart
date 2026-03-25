import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../../main.dart';
import '../../core/audio_handler.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/models/play_session.dart';

class PlayScreen extends StatefulWidget {
  final int? initialTarget;
  final String? initialVoice;
  const PlayScreen({super.key, this.initialTarget, this.initialVoice});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const _audioAsset = 'assets/audio/hc_real.mp3';
  static const _quickCounts = [1, 11, 21, 108];

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _loaded = false;
  bool _continuousPlay = false;
  bool _hapticEnabled = true;
  double _volume = 1.0;
  bool _showVolume = false;

  // ── Loop / completion state ───────────────────────────────────────────────
  int _completedCount = 0;
  int _targetCount = 11;
  bool _seekForwardThisRound = false;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      _targetCount = widget.initialTarget!;
    }
    _loadSettings();
    if (audioHandler != null) {
      _initAudio(audioHandler!);
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
      _volume = audioHandler?.volume ?? 1.0;
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
    _loadAudio();
    _positionSub = handler.positionStream.listen(_onPosition);
    _playerStateSub = handler.playerStateStream.listen(_onPlayerState);
  }

  Future<void> _loadAudio() async {
    try {
      final asset = widget.initialVoice ?? _audioAsset;
      await audioHandler!.loadVoice(asset);
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      debugPrint('Audio load failed: $e');
    }
  }

  void _onPosition(Duration _) {
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
      _saveSession();
      if (_hapticEnabled) HapticFeedback.mediumImpact();
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
      if (_continuousPlay) {
        await audioHandler!.play();
      }
      // If continuousPlay is false, stay paused — user taps play for next round
      if (mounted) setState(() => _completionHandled = false);
    }
  }

  void _saveSession() {
    final now = DateTime.now();
    final dateStr = AppRepository.dateStr(now);
    AppRepository.instance.insertSession(PlaySession(
      date: dateStr,
      count: 1,
      completedAt: now.millisecondsSinceEpoch,
    ));
  }

  Future<void> _onPlay() => audioHandler!.play();
  Future<void> _onPause() => audioHandler!.pause();

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

  // Skip current round (don't count), start next
  Future<void> _onSkipNext() async {
    if (!_loaded) return;
    final handler = audioHandler!;
    setState(() => _seekForwardThisRound = true);
    final nearEnd =
        Duration(milliseconds: handler.duration.inMilliseconds - 300);
    await handler.seek(nearEnd);
    if (!handler.playing) await handler.play();
  }

  void _setTarget(int target) => setState(() {
        _targetCount = target;
        _completedCount = 0;
        _seekForwardThisRound = false;
        _completionHandled = false;
      });

  void _onVolumeChanged(double v) {
    setState(() => _volume = v);
    audioHandler?.setVolume(v);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    audioHandlerNotifier.removeListener(_onHandlerReady);
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HanumanAudioHandler?>(
      valueListenable: audioHandlerNotifier,
      builder: (context, handler, _) {
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
    final total = handler.duration;
    final pos = handler.position;
    final progress = total.inMilliseconds > 0
        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return StreamBuilder<PlayerState>(
      stream: handler.playerStateStream,
      builder: (context, snap) {
        final isPlaying = snap.data?.playing ?? false;
        return Scaffold(
          backgroundColor: const Color(0xFF131313),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Sacred background — image + gradient overlay
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
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
              // Gradient overlay: dark at bottom and top
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
              // Pulsing Om
              Center(
                child: Text(
                  'ॐ',
                  style: GoogleFonts.notoSerif(
                    fontSize: 160,
                    color: cs.secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, cs),
                    Expanded(child: _LyricsPanel(position: pos, cs: cs)),
                    _buildPlayerSection(
                        context, cs, isPlaying, progress, pos, total),
                  ],
                ),
              ),
              // Volume overlay
              if (_showVolume) _buildVolumeOverlay(cs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: cs.primary, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text('Hanuman Chalisa',
              style: GoogleFonts.notoSerif(fontSize: 19, color: cs.primary)),
          IconButton(
            icon: Icon(Icons.share_outlined, color: cs.primary, size: 20),
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
    double progress,
    Duration pos,
    Duration total,
  ) {
    final done = _targetCount > 0 && _completedCount >= _targetCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Counter display ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$_completedCount',
                  style: GoogleFonts.notoSerif(
                    fontSize: 42,
                    color: done ? cs.secondary : cs.primary,
                    height: 1,
                  ),
                ),
                Text(
                  ' / $_targetCount',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (done) ...[
                  const SizedBox(width: 10),
                  Text('जय हनुमान',
                      style: GoogleFonts.notoSerif(
                          fontSize: 14, color: cs.secondary)),
                ],
              ],
            ),
          ),

          // ── Repetition chips ─────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _quickCounts.map((c) {
                final isSelected = c == _targetCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _setTarget(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
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
                          fontSize: 11,
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

          const SizedBox(height: 14),

          // ── Progress bar ─────────────────────────────────────────────
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(pos),
                    style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5)),
                Text(
                  done
                      ? 'Complete!'
                      : 'Chant ${_completedCount + 1} of $_targetCount',
                  style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: cs.secondary,
                      letterSpacing: 0.5),
                ),
                Text(_fmt(total),
                    style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Controls ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Restart
              _ControlButton(
                icon: Icons.replay_rounded,
                onTap: _loaded ? _onRestart : null,
                cs: cs,
              ),
              // Prev + Play/Pause + Next
              Row(children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded,
                      color: cs.onSurface, size: 28),
                  onPressed: _loaded ? _onRestart : null,
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _loaded
                      ? (isPlaying ? _onPause : _onPlay)
                      : null,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [cs.primary, cs.primaryContainer],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primaryContainer
                              .withValues(alpha: 0.4),
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
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded,
                      color: cs.onSurface, size: 28),
                  onPressed: _loaded && !done ? _onSkipNext : null,
                ),
              ]),
              // Volume
              _ControlButton(
                icon: _volume == 0
                    ? Icons.volume_off_rounded
                    : _volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                onTap: () => setState(() => _showVolume = !_showVolume),
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

  Widget _buildVolumeOverlay(ColorScheme cs) {
    return Positioned(
      bottom: 180,
      right: 20,
      child: GestureDetector(
        onTap: () => setState(() => _showVolume = false),
        behavior: HitTestBehavior.translucent,
        child: Container(
          width: 52,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B1B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(Icons.volume_up_rounded,
                  color: cs.primary, size: 18),
              const SizedBox(height: 8),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12),
                      activeTrackColor: cs.primary,
                      inactiveTrackColor:
                          const Color(0xFF353534),
                      thumbColor: cs.primary,
                    ),
                    child: Slider(
                      value: _volume,
                      onChanged: _onVolumeChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.volume_off_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Control button ─────────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final bool active;
  const _ControlButton(
      {required this.icon,
      required this.onTap,
      required this.cs,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
          size: 20,
        ),
      ),
    );
  }
}

// ── Lyrics panel ───────────────────────────────────────────────────────────────
class _LyricsPanel extends StatefulWidget {
  final Duration position;
  final ColorScheme cs;
  const _LyricsPanel({required this.position, required this.cs});

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const _itemExtent = 56.0;
  final _scrollController = ScrollController();
  int _lastIdx = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final lines = lyricsService.lines;
    final cs = widget.cs;

    if (lines.isEmpty) {
      return Center(
        child: Text('ॐ',
            style: GoogleFonts.notoSerif(
                fontSize: 64,
                color: cs.secondary.withValues(alpha: 0.4))),
      );
    }

    final currentIdx = lyricsService.currentLineIndex(widget.position);

    if (currentIdx != _lastIdx) {
      _lastIdx = currentIdx;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToIndex(currentIdx));
    }

    return ListView.builder(
      controller: _scrollController,
      itemExtent: _itemExtent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      itemCount: lines.length,
      itemBuilder: (ctx, i) {
        final isActive = i == currentIdx;
        final isNear = (i - currentIdx).abs() == 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          child: Text(
            lines[i].text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerif(
              fontSize: isActive ? 22 : (isNear ? 16 : 14),
              fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? cs.secondary
                  : isNear
                      ? cs.onSurface.withValues(alpha: 0.5)
                      : cs.onSurface.withValues(alpha: 0.2),
              height: 1.3,
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
    );
  }
}
