import 'dart:math';

class ReferralInfo {
  final int? id;
  final String referralCode;
  final int inviteSentCount;

  /// Confirmed installs via this referral code.
  /// Incremented locally for now; server-validated in Phase 3.
  final int confirmedInviteCount;

  /// When the referral-unlocked premium voice reward expires.
  /// Null = no active reward.
  final DateTime? rewardEndsAt;

  const ReferralInfo({
    this.id,
    required this.referralCode,
    this.inviteSentCount = 0,
    this.confirmedInviteCount = 0,
    this.rewardEndsAt,
  });

  /// Number of confirmed invites required to earn the reward.
  static const int kRewardThreshold = 3;

  /// How long the referral reward lasts.
  static const Duration kRewardDuration = Duration(days: 14);

  bool get hasActiveReward =>
      rewardEndsAt != null && rewardEndsAt!.isAfter(DateTime.now());

  bool get eligibleForReward =>
      confirmedInviteCount >= kRewardThreshold && !hasActiveReward;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'referral_code': referralCode,
        'invite_sent_count': inviteSentCount,
        'confirmed_invite_count': confirmedInviteCount,
        'reward_ends_at': rewardEndsAt?.toIso8601String(),
      };

  factory ReferralInfo.fromMap(Map<String, dynamic> map) => ReferralInfo(
        id: map['id'] as int?,
        referralCode: map['referral_code'] as String,
        inviteSentCount: map['invite_sent_count'] as int,
        confirmedInviteCount: map['confirmed_invite_count'] as int,
        rewardEndsAt: map['reward_ends_at'] != null
            ? DateTime.parse(map['reward_ends_at'] as String)
            : null,
      );

  ReferralInfo copyWith({
    int? id,
    String? referralCode,
    int? inviteSentCount,
    int? confirmedInviteCount,
    DateTime? rewardEndsAt,
  }) =>
      ReferralInfo(
        id: id ?? this.id,
        referralCode: referralCode ?? this.referralCode,
        inviteSentCount: inviteSentCount ?? this.inviteSentCount,
        confirmedInviteCount: confirmedInviteCount ?? this.confirmedInviteCount,
        rewardEndsAt: rewardEndsAt ?? this.rewardEndsAt,
      );

  /// Generates a random 6-character uppercase alphanumeric referral code.
  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0, I/1 confusion
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
