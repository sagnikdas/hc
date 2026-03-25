import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Hanuman Chalisa audio handler.
///
/// Extends [BaseAudioHandler] so audio_service can:
/// - Keep playback alive when the app is backgrounded.
/// - Show a persistent media notification on Android.
/// - Populate the lockscreen / Control Centre on iOS.
///
/// The public API (streams + loadVoice/play/pause/seek) is unchanged so
/// play_screen.dart needs no edits.
class HanumanAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  // ── Public API used by PlayScreen ─────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get duration => _player.duration ?? Duration.zero;
  Duration get position => _player.position;
  bool get playing => _player.playing;
  double get volume => _player.volume;
  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    // Tell the OS this is a music app — handles audio focus and routing.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Populate lockscreen / notification with static metadata.
    mediaItem.add(const MediaItem(
      id: 'assets/audio/hc_real.mp3',
      title: 'Hanuman Chalisa',
      artist: 'Traditional Devotional',
      album: 'Hanuman Chalisa',
      displayTitle: 'Hanuman Chalisa',
      displaySubtitle: 'Traditional Devotional',
    ));

    // Broadcast every playback event to the system (notification + lockscreen).
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) =>
          debugPrint('HanumanAudioHandler playback error: $e'),
    );

    // Keep duration in media item up to date.
    _player.durationStream.listen((d) {
      if (d != null) {
        mediaItem.add(mediaItem.value?.copyWith(duration: d));
      }
    });
  }

  Future<void> loadVoice(String assetPath) async {
    await _player.setAudioSource(AudioSource.asset(assetPath));
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

  Future<void> dispose() => _player.dispose();

  // ── Private helpers ───────────────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    final isPlaying = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.rewind,
      },
      androidCompactActionIndices: const [0, 1],
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
    ));
  }
}

// ── Factory ───────────────────────────────────────────────────────────────────

/// Creates the handler and initialises it.
///
/// Attempts to register with [AudioService] for lockscreen / notification
/// support. If that fails (e.g. platform restrictions), falls back to a
/// standalone handler so basic playback always works.
Future<HanumanAudioHandler> initAudioHandler() async {
  try {
    final handler = await AudioService.init<HanumanAudioHandler>(
      builder: HanumanAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.hanumanchalisa.audio',
        androidNotificationChannelName: 'Hanuman Chalisa',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
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
