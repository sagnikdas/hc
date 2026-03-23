/// Tracks a single play session and fires [onCompleted] exactly once
/// when ≥95 % of the track has been heard.
///
/// Rules enforced:
/// - Completion fires at most once per [reset] cycle.
/// - Seeking forward past the 95 % mark counts.
/// - Seeking backward after completion does NOT re-fire.
class CompletionDetector {
  static const _threshold = 0.95;

  final void Function() onCompleted;

  bool _completed = false;

  CompletionDetector({required this.onCompleted});

  /// Call on every position tick.
  void update(Duration position, Duration total) {
    if (_completed) return;
    if (total.inMilliseconds <= 0) return;
    final ratio = position.inMilliseconds / total.inMilliseconds;
    if (ratio >= _threshold) {
      _completed = true;
      onCompleted();
    }
  }

  /// Call when a new play session starts (new tap on Play from beginning).
  void reset() => _completed = false;

  bool get isCompleted => _completed;
}
