import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../main.dart';
import '../../core/audio_handler.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const _audioAsset = 'assets/audio/hc_real.mp3';
  static const _presets = [11, 18, 21, 41, 51, 108, 0]; // 0 = ∞

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool _loaded = false;
  bool _showLyrics = false;

  // ── Loop / completion state ───────────────────────────────────────────────
  int _completedCount = 0;
  int _targetCount = 11;
  bool _seekForwardThisRound = false;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    if (audioHandler != null) {
      _initAudio(audioHandler!);
    } else {
      audioHandlerNotifier.addListener(_onHandlerReady);
    }
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
      await audioHandler!.loadVoice(_audioAsset);
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      debugPrint('Audio load failed: $e');
    }
  }

  void _onPosition(Duration _) {
    if (mounted) setState(() {});
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed && !_completionHandled) {
      _completionHandled = true;
      _handleCompletion();
    }
  }

  Future<void> _handleCompletion() async {
    if (!mounted) return;

    final counted = !_seekForwardThisRound;
    if (counted) setState(() => _completedCount++);
    _seekForwardThisRound = false;

    final done = _targetCount > 0 && _completedCount >= _targetCount;
    if (!done) {
      // Loop: restart without interrupting the devotion
      await audioHandler!.seek(Duration.zero);
      await audioHandler!.play();
      if (mounted) setState(() => _completionHandled = false);
    }
  }

  Future<void> _onPlay() => audioHandler!.play();
  Future<void> _onPause() => audioHandler!.pause();

  /// Seek from slider — detects forward seeks that invalidate the round.
  Future<void> _onSeek(double value) async {
    final handler = audioHandler!;
    final targetMs = (value * handler.duration.inMilliseconds).round();
    if (targetMs > handler.position.inMilliseconds + 5000) {
      setState(() => _seekForwardThisRound = true);
    }
    await handler.seek(Duration(milliseconds: targetMs));
  }

  /// Manual restart — starts a fresh round, no invalidation.
  Future<void> _onRestart() async {
    setState(() {
      _seekForwardThisRound = false;
      _completionHandled = false;
    });
    await audioHandler!.seek(Duration.zero);
    await audioHandler!.play();
  }

  void _setTarget(int target) => setState(() {
        _targetCount = target;
        _completedCount = 0;
        _seekForwardThisRound = false;
        _completionHandled = false;
      });

  void _showCustomDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set count'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 27'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) _setTarget(v);
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HanumanAudioHandler?>(
      valueListenable: audioHandlerNotifier,
      builder: (context, handler, _) {
        if (handler == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _buildPlayer(context, handler);
      },
    );
  }

  Widget _buildPlayer(BuildContext context, HanumanAudioHandler handler) {
    final colors = Theme.of(context).colorScheme;
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
          backgroundColor: colors.surface,
          body: SafeArea(
            child: Column(
              children: [
                _buildTitleBar(context, colors),
                Expanded(
                  child: _showLyrics
                      ? _LyricsSheet(position: pos)
                      : _buildCenter(context, colors),
                ),
                _buildControls(context, colors, isPlaying, progress, pos, total),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleBar(BuildContext context, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hanuman Chalisa',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
          IconButton(
            icon: Icon(
              _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
        ],
      ),
    );
  }

  Widget _buildCenter(BuildContext context, ColorScheme colors) {
    final done = _targetCount > 0 && _completedCount >= _targetCount;
    final targetLabel = _targetCount == 0 ? '∞' : '$_targetCount';
    final isCustom = !_presets.contains(_targetCount);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Deity icon
        Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primaryContainer.withValues(alpha: 0.35),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/idol_placeholder.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.self_improvement, size: 72, color: colors.primary),
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$_completedCount',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: done ? colors.primary : colors.onSurface,
                    fontWeight: FontWeight.w200,
                    height: 1,
                    fontSize: 76,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                ' / $targetLabel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                    ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Status label
        SizedBox(
          height: 18,
          child: _seekForwardThisRound
              ? Text(
                  'skipped · won\'t count',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error.withValues(alpha: 0.75),
                      ),
                )
              : done
                  ? Text(
                      'जय हनुमान',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                    )
                  : null,
        ),

        const SizedBox(height: 28),

        // Target selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ..._presets.map((p) {
                final label = p == 0 ? '∞' : '$p';
                final selected = !isCustom && p == _targetCount;
                return _Pill(
                  label: label,
                  selected: selected,
                  onTap: () => _setTarget(p),
                  colors: colors,
                );
              }),
              _Pill(
                label: isCustom ? '$_targetCount' : 'custom',
                selected: isCustom,
                onTap: _showCustomDialog,
                colors: colors,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    ColorScheme colors,
    bool isPlaying,
    double progress,
    Duration pos,
    Duration total,
  ) {
    final bottom = MediaQuery.of(context).padding.bottom + 20;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: progress,
              onChanged: _loaded ? _onSeek : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(pos),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
                Text(_fmt(total),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                child: IconButton(
                  icon: Icon(Icons.replay, color: colors.onSurfaceVariant),
                  iconSize: 22,
                  onPressed: _loaded ? _onRestart : null,
                ),
              ),
              const SizedBox(width: 24),
              FilledButton(
                onPressed: _loaded ? (isPlaying ? _onPause : _onPlay) : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                ),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
              ),
              const SizedBox(width: 24),
              const SizedBox(width: 44), // balance
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pill chip ─────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Lyrics view ───────────────────────────────────────────────────────────────

class _LyricsSheet extends StatefulWidget {
  final Duration position;
  const _LyricsSheet({required this.position});

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  static const _itemExtent = 52.0;
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
    if (lines.isEmpty) return const Center(child: Text('Lyrics not loaded'));

    final currentIdx = lyricsService.currentLineIndex(widget.position);
    final colors = Theme.of(context).colorScheme;

    if (currentIdx != _lastIdx) {
      _lastIdx = currentIdx;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(currentIdx));
    }

    return ListView.builder(
      controller: _scrollController,
      itemExtent: _itemExtent,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: lines.length,
      itemBuilder: (ctx, i) {
        final isActive = i == currentIdx;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: isActive
              ? colors.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          child: Text(
            lines[i].text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: isActive ? 17 : 15,
                  color: isActive ? colors.primary : null,
                ),
          ),
        );
      },
    );
  }
}
