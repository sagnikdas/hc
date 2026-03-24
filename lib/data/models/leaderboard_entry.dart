enum LeaderboardPeriod { allTime, weekly }

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final int completedCount;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.completedCount,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) =>
      LeaderboardEntry(
        rank: (map['rank'] as num).toInt(),
        userId: map['user_id'] as String,
        displayName: map['display_name'] as String? ?? 'Anonymous',
        completedCount: (map['completed_count'] as num).toInt(),
      );
}
