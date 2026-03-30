import 'dart:convert';
import 'package:flutter/services.dart';

class LyricsLine {
  final double startSeconds;
  final String text;
  final String? transliteration;
  const LyricsLine({
    required this.startSeconds,
    required this.text,
    this.transliteration,
  });
}

class LyricsService {
  static const _defaultAsset = 'assets/lyrics/hanuman_chalisa.json';

  final Map<String, List<LyricsLine>> _cache = {};
  List<LyricsLine> _lines = [];

  List<LyricsLine> get lines => _lines;

  /// Preloads the default (traditional) track. Called at app startup.
  Future<void> load() => loadTrack(_defaultAsset);

  /// Loads lyrics for [assetPath] (cached after first load) and sets it as current.
  Future<void> loadTrack(String assetPath) async {
    if (_cache.containsKey(assetPath)) {
      _lines = _cache[assetPath]!;
      return;
    }
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['lines'] as List<dynamic>;
    final parsed = list
        .map((e) => LyricsLine(
              startSeconds: (e['startSeconds'] as num).toDouble(),
              text: e['text'] as String,
              transliteration: e['en'] as String?,
            ))
        .toList();
    _cache[assetPath] = parsed;
    _lines = parsed;
  }

  /// Returns the index of the line to highlight at [position].
  /// Uses binary search — O(log n).
  int currentLineIndex(Duration position) {
    if (_lines.isEmpty) return 0;
    final secs = position.inMilliseconds / 1000.0;
    int lo = 0, hi = _lines.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lines[mid].startSeconds <= secs) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return idx;
  }
}
