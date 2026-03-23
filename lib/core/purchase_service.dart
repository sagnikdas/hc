import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/models/entitlement.dart';

/// RevenueCat entitlement identifier configured in the RC dashboard.
const kEntitlementPremium = 'premium';

/// RevenueCat API keys — replace with real values before shipping.
const kRevenueCatApiKeyAndroid = 'REVENUECAT_ANDROID_KEY';
const kRevenueCatApiKeyIos = 'REVENUECAT_IOS_KEY';

abstract interface class PurchaseService {
  /// Configures the underlying SDK. Call once at app start, before any other
  /// method. Safe to call multiple times (idempotent for the no-op impl).
  Future<void> init(String apiKey);

  /// Returns the current entitlement state from the SDK.
  Future<Entitlement> fetchEntitlement();

  /// Restores previous purchases and returns the updated entitlement.
  Future<Entitlement> restorePurchases();

  /// Purchases the given package and returns the updated entitlement.
  /// [package] is a [Package] obtained from [getOfferings].
  Future<Entitlement> purchasePackage(Package package);

  /// Returns available offerings. Returns null when the SDK is unavailable.
  Future<Offerings?> getOfferings();
}

/// No-op implementation — used in tests and on platforms where IAP is
/// unavailable (e.g. macOS debug builds).
class NoOpPurchaseService implements PurchaseService {
  const NoOpPurchaseService();

  @override
  Future<void> init(String apiKey) async {}

  @override
  Future<Entitlement> fetchEntitlement() async => Entitlement.free;

  @override
  Future<Entitlement> restorePurchases() async => Entitlement.free;

  @override
  Future<Entitlement> purchasePackage(Package package) async =>
      Entitlement.free;

  @override
  Future<Offerings?> getOfferings() async => null;
}

/// Live RevenueCat implementation.
class RevenueCatPurchaseService implements PurchaseService {
  @override
  Future<void> init(String apiKey) async {
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  @override
  Future<Entitlement> fetchEntitlement() async {
    final info = await Purchases.getCustomerInfo();
    return _mapCustomerInfo(info);
  }

  @override
  Future<Entitlement> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    return _mapCustomerInfo(info);
  }

  @override
  Future<Entitlement> purchasePackage(Package package) async {
    final result =
        await Purchases.purchase(PurchaseParams.package(package));
    return _mapCustomerInfo(result.customerInfo);
  }

  @override
  Future<Offerings?> getOfferings() async {
    return Purchases.getOfferings();
  }

  /// Maps RevenueCat [CustomerInfo] to our [Entitlement].
  Entitlement _mapCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active[kEntitlementPremium];

    if (active == null) return Entitlement.free;

    final planType = _planTypeFromProductId(active.productIdentifier);
    final expires = active.expirationDate != null
        ? DateTime.tryParse(active.expirationDate!)
        : null;
    final isTrialPeriod = active.periodType == PeriodType.trial;
    final trialEnds = isTrialPeriod ? expires : null;

    return Entitlement(
      planType: planType,
      isPremium: true,
      trialEndsAt: trialEnds,
      expiresAt: expires,
    );
  }

  PlanType _planTypeFromProductId(String productId) {
    final id = productId.toLowerCase();
    if (id.contains('lifetime')) return PlanType.lifetime;
    if (id.contains('year') || id.contains('annual')) return PlanType.yearly;
    return PlanType.monthly;
  }
}
