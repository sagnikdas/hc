class UserSettings {
  final int targetCount;
  final bool hapticEnabled;
  final bool continuousPlay;

  const UserSettings({
    this.targetCount = 11,
    this.hapticEnabled = true,
    this.continuousPlay = false,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'target_count': targetCount,
        'haptic_enabled': hapticEnabled ? 1 : 0,
        'continuous_play': continuousPlay ? 1 : 0,
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        targetCount: m['target_count'] as int? ?? 11,
        hapticEnabled: (m['haptic_enabled'] as int? ?? 1) == 1,
        continuousPlay: (m['continuous_play'] as int? ?? 0) == 1,
      );

  UserSettings copyWith({
    int? targetCount,
    bool? hapticEnabled,
    bool? continuousPlay,
  }) =>
      UserSettings(
        targetCount: targetCount ?? this.targetCount,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        continuousPlay: continuousPlay ?? this.continuousPlay,
      );
}
