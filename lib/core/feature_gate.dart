import '../data/models/entitlement.dart';

/// Features that require an active premium entitlement.
/// Basic Chalisa playback is intentionally absent — it is never gated.
enum PremiumFeature {
  extraVoices,
  advancedAnalytics,
  premiumThemes,

  /// Placeholder for Phase 3 — gating logic ready, backend not yet wired.
  cloudSync,
}

/// Answers "can the current user access this feature?".
///
/// Construct with the current [Entitlement] (re-read from the repository
/// whenever entitlement state may have changed).
class FeatureGate {
  final Entitlement entitlement;

  const FeatureGate(this.entitlement);

  /// Basic Chalisa playback is ALWAYS allowed, regardless of plan.
  // ignore: avoid_final_parameters
  bool get basicPlaybackAllowed => true;

  /// Returns true when the user may access [feature].
  bool isUnlocked(PremiumFeature feature) => entitlement.isActive;

  /// Convenience: true when ANY premium feature is accessible.
  bool get hasPremiumAccess => entitlement.isActive;
}
