class UserSettings {
  final int targetCount;
  final bool hapticEnabled;
  final bool continuousPlay;
  final String? referralCode;
  final bool onboardingShown;

  const UserSettings({
    this.targetCount = 11,
    this.hapticEnabled = true,
    this.continuousPlay = false,
    this.referralCode,
    this.onboardingShown = false,
  });

  Map<String, dynamic> toMap() => {
        'id': 1,
        'target_count': targetCount,
        'haptic_enabled': hapticEnabled ? 1 : 0,
        'continuous_play': continuousPlay ? 1 : 0,
        'referral_code': referralCode,
        'onboarding_shown': onboardingShown ? 1 : 0,
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        targetCount: m['target_count'] as int? ?? 11,
        hapticEnabled: (m['haptic_enabled'] as int? ?? 1) == 1,
        continuousPlay: (m['continuous_play'] as int? ?? 0) == 1,
        referralCode: m['referral_code'] as String?,
        onboardingShown: (m['onboarding_shown'] as int? ?? 0) == 1,
      );

  UserSettings copyWith({
    int? targetCount,
    bool? hapticEnabled,
    bool? continuousPlay,
    String? referralCode,
    bool? onboardingShown,
  }) =>
      UserSettings(
        targetCount: targetCount ?? this.targetCount,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        continuousPlay: continuousPlay ?? this.continuousPlay,
        referralCode: referralCode ?? this.referralCode,
        onboardingShown: onboardingShown ?? this.onboardingShown,
      );
}
