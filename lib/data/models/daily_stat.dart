class DailyStat {
  final int? id;
  final String date; // 'YYYY-MM-DD'
  final int completionCount;
  final int totalPlaySeconds;

  const DailyStat({
    this.id,
    required this.date,
    required this.completionCount,
    required this.totalPlaySeconds,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'completion_count': completionCount,
        'total_play_seconds': totalPlaySeconds,
      };

  factory DailyStat.fromMap(Map<String, dynamic> map) => DailyStat(
        id: map['id'] as int?,
        date: map['date'] as String,
        completionCount: map['completion_count'] as int,
        totalPlaySeconds: map['total_play_seconds'] as int,
      );
}
