class UserSettings {
  final int targetCount;
  final bool hapticEnabled;
  final bool continuousPlay;
  final String? referralCode;
  final bool onboardingShown;
  final double playbackSpeed;
  final double fontScale;

  const UserSettings({
    this.targetCount = 11,
    this.hapticEnabled = true,
    this.continuousPlay = false,
    this.referralCode,
    this.onboardingShown = false,
    this.playbackSpeed = 1.0,
    this.fontScale = 1.0,
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
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        targetCount: m['target_count'] as int? ?? 11,
        hapticEnabled: (m['haptic_enabled'] as int? ?? 1) == 1,
        continuousPlay: (m['continuous_play'] as int? ?? 0) == 1,
        referralCode: m['referral_code'] as String?,
        onboardingShown: (m['onboarding_shown'] as int? ?? 0) == 1,
        playbackSpeed: (m['playback_speed'] as num?)?.toDouble() ?? 1.0,
        fontScale: (m['font_scale'] as num?)?.toDouble() ?? 1.0,
      );

  UserSettings copyWith({
    int? targetCount,
    bool? hapticEnabled,
    bool? continuousPlay,
    String? referralCode,
    bool? onboardingShown,
    double? playbackSpeed,
    double? fontScale,
  }) =>
      UserSettings(
        targetCount: targetCount ?? this.targetCount,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        continuousPlay: continuousPlay ?? this.continuousPlay,
        referralCode: referralCode ?? this.referralCode,
        onboardingShown: onboardingShown ?? this.onboardingShown,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        fontScale: fontScale ?? this.fontScale,
      );
}
