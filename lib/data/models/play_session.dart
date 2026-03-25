class PlaySession {
  final int? id;
  final String date; // YYYY-MM-DD
  final int count;
  final int completedAt; // epoch millis

  const PlaySession({
    this.id,
    required this.date,
    required this.count,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'count': count,
        'completed_at': completedAt,
      };

  factory PlaySession.fromMap(Map<String, dynamic> m) => PlaySession(
        id: m['id'] as int?,
        date: m['date'] as String,
        count: m['count'] as int,
        completedAt: m['completed_at'] as int,
      );
}
