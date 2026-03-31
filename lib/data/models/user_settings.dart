class UserSettings {
  /// Playback speed limits (chant listening; cap avoids chipmunk rates).
  static const double minPlaybackSpeed = 0.5;
  static const double maxPlaybackSpeed = 1.5;

  /// Default morning reminder — 7:00 (minutes from midnight).
  static const int defaultReminderMorningMinutes = 7 * 60;

  /// Default evening reminder — 20:00.
  static const int defaultReminderEveningMinutes = 20 * 60;

  static double clampPlaybackSpeed(double s) =>
      s.clamp(minPlaybackSpeed, maxPlaybackSpeed).toDouble();

  /// Valid range for [reminderMorningMinutes] / [reminderEveningMinutes].
  static int clampReminderMinutes(int m) =>
      m.clamp(0, 24 * 60 - 1).toInt();

  final int targetCount;
  final bool hapticEnabled;
  final bool continuousPlay;
  final String? referralCode;
  final bool onboardingShown;
  final double playbackSpeed;
  final double fontScale;

  /// ID of the user's preferred audio track (null = first-time, show selection screen).
  final String? preferredTrack;

  /// Morning + evening local notifications for chanting (Sankalpa reminders).
  final bool reminderNotificationsEnabled;

  /// Minutes from midnight for the morning reminder (0–1439).
  final int reminderMorningMinutes;

  /// Minutes from midnight for the evening reminder (0–1439).
  final int reminderEveningMinutes;

  /// Higher-priority Tue/Sat titles and channel when enabled.
  final bool sacredDayNotificationsEnabled;

  /// Theme mode: 0 = system, 1 = light, 2 = dark. Default 2 (dark).
  final int themeMode;

  const UserSettings({
    this.targetCount = 11,
    this.hapticEnabled = true,
    this.continuousPlay = false,
    this.referralCode,
    this.onboardingShown = false,
    this.playbackSpeed = 1.0,
    this.fontScale = 1.0,
    this.preferredTrack,
    this.reminderNotificationsEnabled = true,
    this.reminderMorningMinutes = defaultReminderMorningMinutes,
    this.reminderEveningMinutes = defaultReminderEveningMinutes,
    this.sacredDayNotificationsEnabled = true,
    this.themeMode = 2,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'target_count': targetCount,
        'haptic_enabled': hapticEnabled ? 1 : 0,
        'continuous_play': continuousPlay ? 1 : 0,
        'referral_code': referralCode,
        'onboarding_shown': onboardingShown ? 1 : 0,
        'playback_speed': playbackSpeed,
        'font_scale': fontScale,
        'preferred_track': preferredTrack,
        'reminder_notifications_enabled': reminderNotificationsEnabled ? 1 : 0,
        'reminder_morning_minutes': reminderMorningMinutes,
        'reminder_evening_minutes': reminderEveningMinutes,
        'sacred_day_notifications_enabled':
            sacredDayNotificationsEnabled ? 1 : 0,
        'theme_mode': themeMode,
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        targetCount: m['target_count'] as int? ?? 11,
        hapticEnabled: (m['haptic_enabled'] as int? ?? 1) == 1,
        continuousPlay: (m['continuous_play'] as int? ?? 0) == 1,
        referralCode: m['referral_code'] as String?,
        onboardingShown: (m['onboarding_shown'] as int? ?? 0) == 1,
        playbackSpeed: clampPlaybackSpeed(
            (m['playback_speed'] as num?)?.toDouble() ?? 1.0),
        fontScale: (m['font_scale'] as num?)?.toDouble() ?? 1.0,
        preferredTrack: m['preferred_track'] as String?,
        reminderNotificationsEnabled:
            (m['reminder_notifications_enabled'] as int? ?? 1) == 1,
        reminderMorningMinutes: clampReminderMinutes(
            (m['reminder_morning_minutes'] as num?)?.toInt() ??
                defaultReminderMorningMinutes),
        reminderEveningMinutes: clampReminderMinutes(
            (m['reminder_evening_minutes'] as num?)?.toInt() ??
                defaultReminderEveningMinutes),
        sacredDayNotificationsEnabled:
            (m['sacred_day_notifications_enabled'] as int? ?? 1) == 1,
        themeMode: (m['theme_mode'] as int? ?? 2).clamp(0, 2),
      );

  UserSettings copyWith({
    int? targetCount,
    bool? hapticEnabled,
    bool? continuousPlay,
    String? referralCode,
    bool? onboardingShown,
    double? playbackSpeed,
    double? fontScale,
    String? preferredTrack,
    bool clearPreferredTrack = false,
    bool? reminderNotificationsEnabled,
    int? reminderMorningMinutes,
    int? reminderEveningMinutes,
    bool? sacredDayNotificationsEnabled,
    int? themeMode,
  }) =>
      UserSettings(
        targetCount: targetCount ?? this.targetCount,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        continuousPlay: continuousPlay ?? this.continuousPlay,
        referralCode: referralCode ?? this.referralCode,
        onboardingShown: onboardingShown ?? this.onboardingShown,
        playbackSpeed: playbackSpeed != null
            ? clampPlaybackSpeed(playbackSpeed)
            : clampPlaybackSpeed(this.playbackSpeed),
        fontScale: fontScale ?? this.fontScale,
        preferredTrack:
            clearPreferredTrack ? null : (preferredTrack ?? this.preferredTrack),
        reminderNotificationsEnabled: reminderNotificationsEnabled ??
            this.reminderNotificationsEnabled,
        reminderMorningMinutes: reminderMorningMinutes != null
            ? clampReminderMinutes(reminderMorningMinutes)
            : this.reminderMorningMinutes,
        reminderEveningMinutes: reminderEveningMinutes != null
            ? clampReminderMinutes(reminderEveningMinutes)
            : this.reminderEveningMinutes,
        sacredDayNotificationsEnabled: sacredDayNotificationsEnabled ??
            this.sacredDayNotificationsEnabled,
        themeMode: themeMode?.clamp(0, 2) ?? this.themeMode,
      );
}
