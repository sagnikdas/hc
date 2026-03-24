class CloudStats {
  final int currentStreak;
  final int bestStreak;
  final int cumulativeCompletions;
  final DateTime? updatedAt;

  const CloudStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.cumulativeCompletions,
    this.updatedAt,
  });

  factory CloudStats.fromMap(Map<String, dynamic> map) => CloudStats(
        currentStreak: (map['current_streak'] as num).toInt(),
        bestStreak: (map['best_streak'] as num).toInt(),
        cumulativeCompletions: (map['cumulative_completions'] as num).toInt(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'current_streak': currentStreak,
        'best_streak': bestStreak,
        'cumulative_completions': cumulativeCompletions,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// Merge with local values — always take the higher of each counter.
  CloudStats mergeWithLocal({
    required int localCurrentStreak,
    required int localBestStreak,
    required int localCumulativeCompletions,
  }) =>
      CloudStats(
        currentStreak:
            currentStreak > localCurrentStreak ? currentStreak : localCurrentStreak,
        bestStreak:
            bestStreak > localBestStreak ? bestStreak : localBestStreak,
        cumulativeCompletions: cumulativeCompletions > localCumulativeCompletions
            ? cumulativeCompletions
            : localCumulativeCompletions,
        updatedAt: updatedAt,
      );
}
