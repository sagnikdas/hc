enum PlanType { free, monthly, yearly, lifetime }

class Entitlement {
  final int? id;
  final PlanType planType;
  final bool isPremium;
  final DateTime? trialEndsAt;
  final DateTime? expiresAt; // null = never expires (lifetime or active trial)

  const Entitlement({
    this.id,
    required this.planType,
    required this.isPremium,
    this.trialEndsAt,
    this.expiresAt,
  });

  /// The default state — no purchase, no trial.
  static const free = Entitlement(planType: PlanType.free, isPremium: false);

  /// True when the entitlement grants premium access right now.
  bool get isActive {
    if (!isPremium) return false;
    if (expiresAt == null) return true; // lifetime or open trial
    return expiresAt!.isAfter(DateTime.now());
  }

  bool get isOnTrial =>
      trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plan_type': planType.name,
        'is_premium': isPremium ? 1 : 0,
        'trial_ends_at': trialEndsAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      };

  factory Entitlement.fromMap(Map<String, dynamic> map) => Entitlement(
        id: map['id'] as int?,
        planType: PlanType.values.byName(map['plan_type'] as String),
        isPremium: (map['is_premium'] as int) == 1,
        trialEndsAt: map['trial_ends_at'] != null
            ? DateTime.parse(map['trial_ends_at'] as String)
            : null,
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'] as String)
            : null,
      );

  Entitlement copyWith({
    int? id,
    PlanType? planType,
    bool? isPremium,
    DateTime? trialEndsAt,
    DateTime? expiresAt,
  }) =>
      Entitlement(
        id: id ?? this.id,
        planType: planType ?? this.planType,
        isPremium: isPremium ?? this.isPremium,
        trialEndsAt: trialEndsAt ?? this.trialEndsAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}
