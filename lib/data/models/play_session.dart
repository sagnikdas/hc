class PlaySession {
  final int? id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final bool completed; // true only if >=95% played

  const PlaySession({
    this.id,
    required this.startedAt,
    this.completedAt,
    required this.durationSeconds,
    required this.completed,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'completed': completed ? 1 : 0,
      };

  factory PlaySession.fromMap(Map<String, dynamic> map) => PlaySession(
        id: map['id'] as int?,
        startedAt: DateTime.parse(map['started_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        durationSeconds: map['duration_seconds'] as int,
        completed: (map['completed'] as int) == 1,
      );

  PlaySession copyWith({
    int? id,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    bool? completed,
  }) =>
      PlaySession(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        completed: completed ?? this.completed,
      );
}
