import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/features/paywall/paywall_screen.dart';
import 'package:hanuman_chalisa/core/purchase_service.dart';
import 'package:hanuman_chalisa/data/models/entitlement.dart';
import 'package:hanuman_chalisa/data/repositories/entitlement_repository.dart';

// ── Stubs ──────────────────────────────────────────────────────────────────────

class _StubEntitlementRepository implements EntitlementRepository {
  Entitlement _stored = Entitlement.free;

  @override
  Future<Entitlement> get() async => _stored;

  @override
  Future<void> save(Entitlement entitlement) async => _stored = entitlement;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: child);

PaywallScreen _screen({
  PaywallVariant variant = PaywallVariant.benefits,
  int completionCount = 0,
}) =>
    PaywallScreen(
      variant: variant,
      completionCount: completionCount,
      purchaseService: const NoOpPurchaseService(),
      entitlementRepository: _StubEntitlementRepository(),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('PaywallScreen — benefits variant', () {
    testWidgets('shows Unlock Premium headline', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump(); // settle async offerings load
      expect(find.text('Unlock Premium'), findsOneWidget);
    });

    testWidgets('shows static plan tiles when no offerings', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump();
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
    });

    testWidgets('close button is present', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('CTA button label is Start Free Trial', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump();
      expect(find.text('Start Free Trial'), findsOneWidget);
    });

    testWidgets('restore purchases link is present', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump();
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    testWidgets('tapping a plan tile selects it', (tester) async {
      await tester.pumpWidget(_wrap(_screen()));
      await tester.pump();
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      // No crash — selection toggling works.
    });
  });

  group('PaywallScreen — milestone variant', () {
    testWidgets('shows completion count in header', (tester) async {
      await tester.pumpWidget(_wrap(_screen(
        variant: PaywallVariant.milestone,
        completionCount: 21,
      )));
      await tester.pump();
      expect(find.text('21'), findsOneWidget);
      expect(find.textContaining('21 recitations'), findsOneWidget);
    });

    testWidgets('CTA label is Continue Your Journey', (tester) async {
      await tester.pumpWidget(
          _wrap(_screen(variant: PaywallVariant.milestone)));
      await tester.pump();
      expect(find.text('Continue Your Journey'), findsOneWidget);
    });
  });
}
