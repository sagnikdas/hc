import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/feature_gate.dart';
import 'package:hanuman_chalisa/data/models/entitlement.dart';

void main() {
  group('FeatureGate', () {
    test('basicPlaybackAllowed is always true regardless of plan', () {
      expect(const FeatureGate(Entitlement.free).basicPlaybackAllowed, isTrue);
      final premium = Entitlement(
        planType: PlanType.monthly,
        isPremium: true,
        expiresAt: DateTime(2099),
      );
      expect(FeatureGate(premium).basicPlaybackAllowed, isTrue);
    });

    test('free entitlement cannot access any premium feature', () {
      const gate = FeatureGate(Entitlement.free);
      for (final f in PremiumFeature.values) {
        expect(gate.isUnlocked(f), isFalse, reason: '$f should be locked');
      }
      expect(gate.hasPremiumAccess, isFalse);
    });

    test('active premium entitlement unlocks all features', () {
      final gate = FeatureGate(Entitlement(
        planType: PlanType.yearly,
        isPremium: true,
        expiresAt: DateTime(2099),
      ));
      for (final f in PremiumFeature.values) {
        expect(gate.isUnlocked(f), isTrue, reason: '$f should be unlocked');
      }
      expect(gate.hasPremiumAccess, isTrue);
    });

    test('expired subscription does not unlock features', () {
      final gate = FeatureGate(Entitlement(
        planType: PlanType.monthly,
        isPremium: true,
        expiresAt: DateTime(2020), // past
      ));
      for (final f in PremiumFeature.values) {
        expect(gate.isUnlocked(f), isFalse,
            reason: '$f should be locked after expiry');
      }
    });

    test('lifetime entitlement (no expiry) unlocks features', () {
      const gate = FeatureGate(
        Entitlement(planType: PlanType.lifetime, isPremium: true),
      );
      expect(gate.hasPremiumAccess, isTrue);
    });
  });
}
