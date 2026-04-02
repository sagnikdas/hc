import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/user_settings.dart';

/// Hanuman Chalisa audio handler.
///
/// Extends [BaseAudioHandler] so audio_service can:
/// - Keep playback alive when the app is backgrounded.
/// - Show a persistent media notification on Android.
/// - Populate the lockscreen / Control Centre on iOS.
class HanumanAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  StreamSubscription? _playbackEventSub;
  StreamSubscription? _durationSub;
  String? _currentAssetPath;
  int _completionCount = 0;

  // ── Public API used by PlayScreen ─────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get duration => _player.duration ?? Duration.zero;
  Duration get position => _player.position;
  bool get playing => _player.playing;
  double get volume => _player.volume;
  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  double get speed => _player.speed;
  String? get currentAssetPath => _currentAssetPath;
  int get completionCount => _completionCount;

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(
      speed.clamp(
        UserSettings.minPlaybackSpeed,
        UserSettings.maxPlaybackSpeed,
      ),
    );
    _updateMediaItem();
  }

  /// Update completion count and reflect on lock screen.
  void setCompletionCount(int count) {
    _completionCount = count;
    _updateMediaItem();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    final item = const MediaItem(
      id: 'assets/audio/hc_real.mp3',
      title: 'Hanuman Chalisa',
      artist: 'Traditional Devotional',
      album: 'Hanuman Chalisa',
      displayTitle: 'Hanuman Chalisa',
      displaySubtitle: 'Traditional Devotional',
    );

    // Set both mediaItem and queue for proper notification display
    mediaItem.add(item);
    queue.add([item]);

    // Broadcast every playback event to the system (notification + lockscreen).
    _playbackEventSub = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) =>
          debugPrint('HanumanAudioHandler playback error: $e'),
    );

    // Keep duration in media item up to date.
    _durationSub = _player.durationStream.listen((d) {
      if (d != null) {
        final current = mediaItem.value;
        if (current != null) mediaItem.add(current.copyWith(duration: d));
      }
    });
  }

  Future<void> loadVoice(String assetPath) async {
    await _player.setAudioSource(AudioSource.asset(assetPath));
    _currentAssetPath = assetPath;
  }

  // ── BaseAudioHandler overrides ────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Maps the hardware/notification rewind button to restart from beginning.
  @override
  Future<void> rewind() => _player.seek(Duration.zero);

  /// Increase playback speed (mapped to next button on lock screen).
  @override
  Future<void> skipToNext() async {
    final newSpeed = (_player.speed + 0.25).clamp(
      UserSettings.minPlaybackSpeed,
      UserSettings.maxPlaybackSpeed,
    );
    await setSpeed(newSpeed);
  }

  /// Decrease playback speed (mapped to previous button on lock screen).
  @override
  Future<void> skipToPrevious() async {
    final newSpeed = (_player.speed - 0.25).clamp(
      UserSettings.minPlaybackSpeed,
      UserSettings.maxPlaybackSpeed,
    );
    await setSpeed(newSpeed);
  }

  Future<void> dispose() async {
    await _playbackEventSub?.cancel();
    await _durationSub?.cancel();
    await _player.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    final isPlaying = _player.playing;
    final state = PlaybackState(
      controls: [
        MediaControl.skipToPrevious, // Speed down
        MediaControl.rewind,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext, // Speed up
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: isPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
    playbackState.add(state);
    debugPrint('AudioHandler state updated: playing=$isPlaying, speed=${_player.speed}');
  }

  /// Update media item with current speed and completion count.
  void _updateMediaItem() {
    final current = mediaItem.value;
    if (current != null) {
      final speedText = _player.speed != 1.0 ? ' (${_player.speed.toStringAsFixed(2)}x)' : '';
      final countText = _completionCount > 0 ? ' • $_completionCount completed' : '';
      final newSubtitle = 'Traditional Devotional$speedText$countText';
      final updated = current.copyWith(displaySubtitle: newSubtitle);
      mediaItem.add(updated);
      // Also update queue to reflect changes
      final currentQueue = queue.value;
      if (currentQueue.isNotEmpty) {
        queue.add([updated]);
      }
      debugPrint('MediaItem updated: $newSubtitle');
    }
  }
}

// ── Factory ───────────────────────────────────────────────────────────────────

Future<HanumanAudioHandler> initAudioHandler() async {
  try {
    final handler = await AudioService.init<HanumanAudioHandler>(
      builder: HanumanAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.hanumanchalisa.audio',
        androidNotificationChannelName: 'Hanuman Chalisa',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true, // Notification persists during playback
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    await handler.init();
    return handler;
  } catch (e) {
    debugPrint('AudioService.init failed, using standalone handler: $e');
    final handler = HanumanAudioHandler();
    await handler.init();
    return handler;
  }
}
