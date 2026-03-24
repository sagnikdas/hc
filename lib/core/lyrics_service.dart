import 'dart:convert';
import 'package:flutter/services.dart';

class LyricsLine {
  final double startSeconds;
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
              startSeconds: (e['startSeconds'] as num).toDouble(),
              text: e['text'] as String,
            ))
        .toList();
  }

  List<LyricsLine> get lines => _lines ?? [];

  /// Returns the index of the line to highlight at [position].
  /// Uses binary search — O(log n) instead of O(n).
  int currentLineIndex(Duration position) {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return 0;
    final secs = position.inMilliseconds / 1000.0;
    int lo = 0, hi = lines.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].startSeconds <= secs) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return idx;
  }
}
