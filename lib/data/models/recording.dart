class Recording {
  final int? id;
  final String filePath;
  final DateTime recordedAt;
  final int durationSeconds;
  final String? label;

  const Recording({
    this.id,
    required this.filePath,
    required this.recordedAt,
    required this.durationSeconds,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'file_path': filePath,
        'recorded_at': recordedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'label': label,
      };

  factory Recording.fromMap(Map<String, dynamic> map) => Recording(
        id: map['id'] as int?,
        filePath: map['file_path'] as String,
        recordedAt: DateTime.parse(map['recorded_at'] as String),
        durationSeconds: map['duration_seconds'] as int,
        label: map['label'] as String?,
      );
}
