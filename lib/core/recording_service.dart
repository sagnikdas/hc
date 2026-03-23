import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Loop presets for recording sessions.
enum LoopPreset { eleven, twentyOne, fiftyOne, custom }

extension LoopPresetCount on LoopPreset {
  int get defaultCount {
    switch (this) {
      case LoopPreset.eleven:
        return 11;
      case LoopPreset.twentyOne:
        return 21;
      case LoopPreset.fiftyOne:
        return 51;
      case LoopPreset.custom:
        return 1;
    }
  }
}

/// Manages a single multi-loop recording session.
class RecordingSession {
  final AudioRecorder _recorder = AudioRecorder();
  final int targetLoops;

  int completedLoops = 0;
  bool _recording = false;
  final List<String> _paths = [];

  RecordingSession({required this.targetLoops});

  bool get isRecording => _recording;
  bool get allLoopsDone => completedLoops >= targetLoops;
  List<String> get recordedPaths => List.unmodifiable(_paths);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startLoop() async {
    if (_recording) return;
    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory(p.join(dir.path, 'recordings'));
    if (!await recDir.exists()) await recDir.create(recursive: true);

    final filename =
        'loop_${completedLoops + 1}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = p.join(recDir.path, filename);

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recording = true;
  }

  /// Stops current loop. Returns the saved file path, or null on error.
  Future<String?> stopLoop() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;
    if (path != null) {
      _paths.add(path);
      completedLoops++;
    }
    return path;
  }

  Future<void> dispose() async {
    if (_recording) await _recorder.stop();
    _recorder.dispose();
  }
}
