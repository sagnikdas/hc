class UserSettings {
  final int? id;
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool reminderEnabled;
  final String? reminderTime; // 'HH:MM'
  final String selectedVoice;

  const UserSettings({
    this.id,
    this.themeMode = 'system',
    this.reminderEnabled = false,
    this.reminderTime,
    this.selectedVoice = 'default',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'theme_mode': themeMode,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_time': reminderTime,
        'selected_voice': selectedVoice,
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        id: map['id'] as int?,
        themeMode: map['theme_mode'] as String,
        reminderEnabled: (map['reminder_enabled'] as int) == 1,
        reminderTime: map['reminder_time'] as String?,
        selectedVoice: map['selected_voice'] as String,
      );

  UserSettings copyWith({
    int? id,
    String? themeMode,
    bool? reminderEnabled,
    String? reminderTime,
    String? selectedVoice,
  }) =>
      UserSettings(
        id: id ?? this.id,
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        selectedVoice: selectedVoice ?? this.selectedVoice,
      );
}
