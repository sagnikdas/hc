import 'dart:convert';
import 'package:flutter/services.dart';

class LyricsLine {
  final int startSeconds;
  final String text;
  const LyricsLine({required this.startSeconds, required this.text});
}

class LyricsService {
  static const _assetPath = 'assets/lyrics/hanuman_chalisa.json';

  List<LyricsLine>? _lines;

  Future<void> load() async {
    if (_lines != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['lines'] as List<dynamic>;
    _lines = list
        .map((e) => LyricsLine(
              // Use toInt() to handle both int and double in JSON
              startSeconds: (e['startSeconds'] as num).toInt(),
              text: e['text'] as String,
            ))
        .toList();
  }

  List<LyricsLine> get lines => _lines ?? [];

  /// Returns the index of the line to highlight at [position].
  /// Timestamps in the JSON are matched directly — no scaling.
  int currentLineIndex(Duration position) {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return 0;
    final secs = position.inSeconds;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startSeconds <= secs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }
}
