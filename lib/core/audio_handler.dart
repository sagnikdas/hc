import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Wraps AudioPlayer directly — no audio_service background layer.
/// Background + lock-screen controls can be layered on top later.
class HanumanAudioHandler {
  final _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Duration get duration => _player.duration ?? Duration.zero;
  Duration get position => _player.position;
  bool get playing => _player.playing;

  Future<void> init() async {
    // Configure the audio session so the system treats this as music.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> loadVoice(String assetPath) async {
    await _player.setAudioSource(AudioSource.asset(assetPath));
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}

/// Creates and initialises the handler. Replaces the old AudioService.init call.
Future<HanumanAudioHandler> initAudioHandler() async {
  final handler = HanumanAudioHandler();
  await handler.init();
  return handler;
}
