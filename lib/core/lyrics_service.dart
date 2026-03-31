import 'dart:convert';
import 'dart:math' as math;
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

  static String _cacheKey(String assetPath, double curveExponent) =>
      '$assetPath#$curveExponent';

  /// Preloads the default (traditional) track. Called at app startup.
  Future<void> load() => loadTrack(_defaultAsset);

  /// Loads lyrics for [assetPath] (cached after first load) and sets it as current.
  ///
  /// [lyricSyncCurveExponent]: see [AudioTrack.lyricSyncCurveExponent]. Must match
  /// how the track was configured so cache entries stay correct.
  Future<void> loadTrack(
    String assetPath, {
    double lyricSyncCurveExponent = 1.0,
  }) async {
    final key = _cacheKey(assetPath, lyricSyncCurveExponent);
    if (_cache.containsKey(key)) {
      _lines = _cache[key]!;
      return;
    }
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['lines'] as List<dynamic>;
    final fitSeconds =
        (json['totalDurationSeconds'] as num?)?.toDouble();
    var parsed = list
        .map((e) => LyricsLine(
              startSeconds: (e['startSeconds'] as num).toDouble(),
              text: e['text'] as String,
              transliteration: e['en'] as String?,
            ))
        .toList();
    if (lyricSyncCurveExponent != 1.0 &&
        fitSeconds != null &&
        fitSeconds > 1 &&
        parsed.isNotEmpty) {
      parsed = _warpLineStarts(parsed, lyricSyncCurveExponent, fitSeconds);
    }
    _cache[key] = parsed;
    _lines = parsed;
  }

  /// Pushes cue times later in the song for exponents in (0, 1): same JSON order,
  /// but each line "starts" closer to when the chant is usually heard.
  static List<LyricsLine> _warpLineStarts(
    List<LyricsLine> lines,
    double exponent,
    double fitDurationSec,
  ) {
    final first = lines.first.startSeconds;
    final last = lines.last.startSeconds;
    final span = last - first;
    if (span <= 0) return lines;
    final endAnchor = math.min(fitDurationSec * 0.97, fitDurationSec - 0.75);
    final range = endAnchor - first;
    double prev = -1.0;
    return lines.map((l) {
      final u = ((l.startSeconds - first) / span).clamp(0.0, 1.0);
      var t = first + math.pow(u, exponent) * range;
      if (t <= prev) t = prev + 0.02;
      prev = t;
      return LyricsLine(
        startSeconds: t,
        text: l.text,
        transliteration: l.transliteration,
      );
    }).toList();
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
