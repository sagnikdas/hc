import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../main.dart';
import '../../core/audio_handler.dart';
import '../../core/completion_detector.dart';
import '../../core/paywall_trigger.dart';
import '../../data/models/play_session.dart';
import '../../data/models/daily_stat.dart';
import '../../data/repositories/play_session_repository.dart';
import '../../data/repositories/daily_stat_repository.dart';
import '../../data/repositories/user_settings_repository.dart';
import '../paywall/paywall_screen.dart';
import '../../data/repositories/entitlement_repository.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const _audioAsset = 'assets/audio/hc_real.mp3';

  final _playSessionRepo = SqlitePlaySessionRepository();
  final _dailyStatRepo = SqliteDailyStatRepository();
  final _settingsRepo = SqliteUserSettingsRepository();

  late final CompletionDetector _completionDetector;
  StreamSubscription<Duration>? _positionSub;

  int? _activeSessionId;
  bool _loaded = false;
  bool _showLyrics = false;
  int _todayCount = 0;

  /// Set after a completion event; consumed on the next pause/stop.
  bool _paywallPending = false;

  @override
  void initState() {
    super.initState();
    _completionDetector = CompletionDetector(onCompleted: _onCompleted);
    _loadTodayCount();
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
  }

  Future<void> _loadAudio() async {
    await audioHandler!.loadVoice(_audioAsset);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _loadTodayCount() async {
    final today = _todayStr();
    final stat = await _dailyStatRepo.getByDate(today);
    if (mounted) setState(() => _todayCount = stat?.completionCount ?? 0);
  }

  void _onPosition(Duration pos) {
    final total = audioHandler!.duration;
    _completionDetector.update(pos, total);
    if (mounted) setState(() {});
  }

  Future<void> _onCompleted() async {
    final now = DateTime.now();
    final today = _todayStr();

    if (_activeSessionId != null) {
      final existing = await _playSessionRepo.getById(_activeSessionId!);
      if (existing != null) {
        await _playSessionRepo.update(existing.copyWith(
          completedAt: now,
          durationSeconds: audioHandler!.duration.inSeconds,
          completed: true,
        ));
      }
      _activeSessionId = null;
    }

    final stat = await _dailyStatRepo.getByDate(today);
    final updated = DailyStat(
      id: stat?.id,
      date: today,
      completionCount: (stat?.completionCount ?? 0) + 1,
      totalPlaySeconds:
          (stat?.totalPlaySeconds ?? 0) + audioHandler!.duration.inSeconds,
    );
    await _dailyStatRepo.upsert(updated);

    if (mounted) setState(() => _todayCount = updated.completionCount);

    // Flag for paywall check — fires when audio next stops/pauses.
    _paywallPending = true;
  }

  Future<void> _maybeShowPaywall() async {
    if (!_paywallPending) return;
    _paywallPending = false;

    final settings = await _settingsRepo.get();
    final total = await _dailyStatRepo.totalCompletions();
    final isPremium = entitlementNotifier.value.isActive;

    if (!PaywallTrigger.shouldShow(
      isPremium: isPremium,
      isPlaying: audioHandler?.playing ?? false,
      dailyCompletions: _todayCount,
      totalCompletions: total,
      lastShownAt: settings.lastPaywallShownAt,
    )) {
      return;
    }

    if (!mounted) return;

    // Determine variant: milestone moments → milestone, otherwise benefits.
    final isMilestone = kMilestoneCompletions.contains(total);
    final variant =
        isMilestone ? PaywallVariant.milestone : PaywallVariant.benefits;

    final purchased = await showPaywall(
      context,
      variant: variant,
      completionCount: total,
    );

    if (purchased) {
      entitlementNotifier.value = await SqliteEntitlementRepository().get();
    }

    // Update last shown timestamp regardless of outcome.
    await _settingsRepo.save(
      settings.copyWith(lastPaywallShownAt: DateTime.now()),
    );
  }

  Future<void> _onPlay() async {
    if (_activeSessionId == null && !_completionDetector.isCompleted) {
      _completionDetector.reset();
      final id = await _playSessionRepo.insert(PlaySession(
        startedAt: DateTime.now(),
        durationSeconds: 0,
        completed: false,
      ));
      _activeSessionId = id;
    }
    await audioHandler!.play();
  }

  Future<void> _onPause() => audioHandler!.pause();

  Future<void> _onSeek(double value) async {
    final total = audioHandler!.duration;
    await audioHandler!
        .seek(Duration(milliseconds: (value * total.inMilliseconds).round()));
  }

  Future<void> _onRestart() async {
    _completionDetector.reset();
    _activeSessionId = null;
    await audioHandler!.seek(Duration.zero);
    await _onPlay();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    audioHandlerNotifier.removeListener(_onHandlerReady);
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HanumanAudioHandler?>(
      valueListenable: audioHandlerNotifier,
      builder: (context, handler, _) {
        if (handler == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _buildPlayer(context, handler);
      },
    );
  }

  Widget _buildPlayer(BuildContext context, HanumanAudioHandler handler) {
    final colors = Theme.of(context).colorScheme;
    final total = handler.duration;
    final pos = handler.position;
    final progress =
        total.inMilliseconds > 0 ? pos.inMilliseconds / total.inMilliseconds : 0.0;

    return StreamBuilder<PlayerState>(
      stream: handler.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;
        // Check paywall when audio stops after a completed session.
        if (!isPlaying && _paywallPending) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _maybeShowPaywall());
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hanuman Chalisa'),
            actions: [
              IconButton(
                icon: Icon(
                  _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
                  color: Colors.white,
                ),
                tooltip: 'Lyrics',
                onPressed: () => setState(() => _showLyrics = !_showLyrics),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _showLyrics
                    ? _LyricsSheet(position: pos)
                    : _IdolView(todayCount: _todayCount, colors: colors),
              ),
              _PlayerControls(
                loaded: _loaded,
                isPlaying: isPlaying,
                progress: progress.clamp(0.0, 1.0),
                position: pos,
                total: total,
                onPlay: _onPlay,
                onPause: _onPause,
                onSeek: _onSeek,
                onRestart: _onRestart,
                formatDuration: _formatDuration,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Idol / counter view ────────────────────────────────────────────────────────

class _IdolView extends StatelessWidget {
  final int todayCount;
  final ColorScheme colors;
  const _IdolView({required this.todayCount, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
            child: Icon(Icons.self_improvement, size: 100, color: colors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            'आज: $todayCount',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
          ),
          Text(
            todayCount == 0 ? 'पहली जय करें 🙏' : 'जय हनुमान! 🙏',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
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
    final viewportHeight = _scrollController.position.viewportDimension;
    final target = (idx * _itemExtent) - (viewportHeight * 0.4);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = lyricsService.lines;

    if (lines.isEmpty) {
      return const Center(child: Text('Lyrics not loaded'));
    }

    final currentIdx = lyricsService.currentLineIndex(widget.position);
    final colors = Theme.of(context).colorScheme;

    if (currentIdx != _lastIdx) {
      _lastIdx = currentIdx;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToIndex(currentIdx));
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

// ── Player controls ───────────────────────────────────────────────────────────

class _PlayerControls extends StatelessWidget {
  final bool loaded;
  final bool isPlaying;
  final double progress;
  final Duration position;
  final Duration total;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onRestart;
  final String Function(Duration) formatDuration;

  const _PlayerControls({
    required this.loaded,
    required this.isPlaying,
    required this.progress,
    required this.position,
    required this.total,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onRestart,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: progress,
            onChanged: loaded ? onSeek : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(position),
                    style: Theme.of(context).textTheme.bodySmall),
                Text(formatDuration(total),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay),
                tooltip: 'Restart',
                onPressed: loaded ? onRestart : null,
                iconSize: 28,
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: loaded ? (isPlaying ? onPause : onPlay) : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
