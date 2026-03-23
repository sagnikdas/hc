import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/core/purchase_service.dart';
import 'package:hanuman_chalisa/data/models/entitlement.dart';

void main() {
  group('NoOpPurchaseService', () {
    const service = NoOpPurchaseService();

    test('init completes without error', () async {
      await expectLater(service.init('any_key'), completes);
    });

    test('fetchEntitlement returns free', () async {
      final e = await service.fetchEntitlement();
      expect(e.isPremium, isFalse);
      expect(e.planType, PlanType.free);
    });

    test('restorePurchases returns free', () async {
      final e = await service.restorePurchases();
      expect(e.isPremium, isFalse);
    });

    test('getOfferings returns null', () async {
      expect(await service.getOfferings(), isNull);
    });
  });
}
