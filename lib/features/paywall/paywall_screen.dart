import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart'
    show Package, PackageType, PurchasesErrorCode;

import '../../core/analytics.dart';
import '../../core/purchase_service.dart';
import '../../data/models/entitlement.dart';
import '../../data/repositories/entitlement_repository.dart';
import '../../main.dart';

// ── Variant ───────────────────────────────────────────────────────────────────

/// Controls which copy/layout is shown. Assign deterministically per user
/// (e.g. userId.hashCode % 2) so the same user always sees the same variant.
enum PaywallVariant {
  /// Variant A — leads with a feature-benefit list.
  benefits,

  /// Variant B — leads with the user's milestone count (high-intent timing).
  milestone,
}

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows the paywall as a full-screen modal route.
/// Returns `true` if the user successfully subscribed/restored, `false`
/// otherwise (dismissed or error).
Future<bool> showPaywall(
  BuildContext context, {
  required PaywallVariant variant,
  int completionCount = 0,
  PurchaseService? purchaseService,
  EntitlementRepository? entitlementRepository,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(
        variant: variant,
        completionCount: completionCount,
        purchaseService: purchaseService ?? const NoOpPurchaseService(),
        entitlementRepository:
            entitlementRepository ?? SqliteEntitlementRepository(),
      ),
    ),
  );
  return result ?? false;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PaywallScreen extends StatefulWidget {
  final PaywallVariant variant;
  final int completionCount;
  final PurchaseService purchaseService;
  final EntitlementRepository entitlementRepository;

  const PaywallScreen({
    super.key,
    required this.variant,
    required this.completionCount,
    required this.purchaseService,
    required this.entitlementRepository,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _analytics = analyticsService;

  List<Package> _packages = [];
  bool _loadingOfferings = true;
  bool _purchasing = false;
  String? _errorMessage;

  // Which plan tile is selected (index into _packages, or static index).
  int _selectedIndex = 1; // default: middle option (yearly)

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(kEventPaywallViewed,
        params: {'variant': widget.variant.name});
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await widget.purchaseService.getOfferings();
      final pkgs = offerings?.current?.availablePackages ?? [];
      if (mounted) {
        setState(() {
          _packages = pkgs;
          _loadingOfferings = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOfferings = false);
    }
  }

  Future<void> _onPurchase() async {
    setState(() {
      _purchasing = true;
      _errorMessage = null;
    });
    try {
      Entitlement entitlement;
      if (_packages.isNotEmpty) {
        final pkg = _packages[_selectedIndex.clamp(0, _packages.length - 1)];
        entitlement = await widget.purchaseService.purchasePackage(pkg);
      } else {
        // No live offerings — no-op path (e.g. test/simulator).
        entitlement = Entitlement.free;
      }
      await widget.entitlementRepository.save(entitlement);
      if (entitlement.isActive) {
        _analytics.logEvent(kEventSubscriptionStarted,
            params: {'plan': entitlement.planType.name});
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          setState(() => _errorMessage = 'Purchase could not be completed.');
        }
      }
    } catch (e) {
      if (_isPurchaseCancelled(e)) return; // user tapped Cancel — silent
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _onRestore() async {
    setState(() {
      _purchasing = true;
      _errorMessage = null;
    });
    try {
      final entitlement = await widget.purchaseService.restorePurchases();
      await widget.entitlementRepository.save(entitlement);
      if (entitlement.isActive) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          setState(
              () => _errorMessage = 'No active subscription found to restore.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  // ── Error helpers ────────────────────────────────────────────────────────────

  bool _isPurchaseCancelled(Object e) {
    if (e is PlatformException) {
      final code = PurchasesErrorCode.values.firstWhere(
        (c) => c.index.toString() == e.code,
        orElse: () => PurchasesErrorCode.unknownError,
      );
      return code == PurchasesErrorCode.purchaseCancelledError;
    }
    return false;
  }

  String _friendlyError(Object e) {
    if (e is PlatformException) {
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _onClose() {
    _analytics.logEvent(kEventPaywallClosed,
        params: {'variant': widget.variant.name});
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, colors),
                  const SizedBox(height: 32),
                  _buildPlanSelector(context, colors),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildCta(context, colors),
                  const SizedBox(height: 16),
                  _buildRestoreLink(context),
                  const SizedBox(height: 8),
                  _buildLegalNote(context),
                ],
              ),
            ),
            // Close button — always reachable
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _onClose,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header (variant-specific) ────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ColorScheme colors) {
    return widget.variant == PaywallVariant.benefits
        ? _BenefitsHeader(colors: colors)
        : _MilestoneHeader(
            colors: colors,
            completionCount: widget.completionCount,
          );
  }

  // ── Plan selector ────────────────────────────────────────────────────────────

  Widget _buildPlanSelector(BuildContext context, ColorScheme colors) {
    if (_loadingOfferings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_packages.isNotEmpty) {
      return Column(
        children: List.generate(_packages.length, (i) {
          final pkg = _packages[i];
          return _PlanTile(
            title: _packageTitle(pkg),
            subtitle: pkg.storeProduct.priceString,
            badge: _packageBadge(pkg),
            selected: _selectedIndex == i,
            onTap: () => setState(() => _selectedIndex = i),
            colors: colors,
          );
        }),
      );
    }
    // Static fallback when RevenueCat is unavailable.
    return Column(
      children: [
        _PlanTile(
          title: 'Monthly',
          subtitle: '₹99 / month',
          selected: _selectedIndex == 0,
          onTap: () => setState(() => _selectedIndex = 0),
          colors: colors,
        ),
        _PlanTile(
          title: 'Yearly',
          subtitle: '₹599 / year',
          badge: 'Save 50%',
          selected: _selectedIndex == 1,
          onTap: () => setState(() => _selectedIndex = 1),
          colors: colors,
        ),
        _PlanTile(
          title: 'Lifetime',
          subtitle: '₹1499 one-time',
          selected: _selectedIndex == 2,
          onTap: () => setState(() => _selectedIndex = 2),
          colors: colors,
        ),
      ],
    );
  }

  // ── CTA ──────────────────────────────────────────────────────────────────────

  Widget _buildCta(BuildContext context, ColorScheme colors) {
    final label = widget.variant == PaywallVariant.milestone
        ? 'Continue Your Journey'
        : 'Start Free Trial';
    return FilledButton(
      onPressed: _purchasing ? null : _onPurchase,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      child: _purchasing
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  Widget _buildRestoreLink(BuildContext context) {
    return TextButton(
      onPressed: _purchasing ? null : _onRestore,
      child: const Text('Restore purchases'),
    );
  }

  Widget _buildLegalNote(BuildContext context) {
    return Text(
      'Subscriptions auto-renew unless cancelled 24 hours before renewal. '
      'Cancel anytime in your app store settings.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _packageTitle(Package pkg) {
    return switch (pkg.packageType) {
      PackageType.monthly => 'Monthly',
      PackageType.annual => 'Yearly',
      PackageType.lifetime => 'Lifetime',
      _ => pkg.identifier,
    };
  }

  String? _packageBadge(Package pkg) {
    if (pkg.packageType == PackageType.annual) return 'Best Value';
    if (pkg.packageType == PackageType.lifetime) return 'One-Time';
    return null;
  }
}

// ── Variant A header ──────────────────────────────────────────────────────────

class _BenefitsHeader extends StatelessWidget {
  final ColorScheme colors;
  const _BenefitsHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.workspace_premium, size: 64, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          'Unlock Premium',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Deepen your daily devotion',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._kBenefits.map(
          (b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(b,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _kBenefits = [
  'Multiple premium voices',
  'Advanced progress insights & history',
  'Exclusive ambience & theme packs',
  'Sankalp programs and milestone packs',
  'Cross-device cloud sync (coming soon)',
];

// ── Variant B header ──────────────────────────────────────────────────────────

class _MilestoneHeader extends StatelessWidget {
  final ColorScheme colors;
  final int completionCount;
  const _MilestoneHeader(
      {required this.colors, required this.completionCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primaryContainer,
          ),
          child: Center(
            child: Text(
              '$completionCount',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You\'ve completed $completionCount recitations!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Join devotees who go deeper with Premium.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Plan tile ─────────────────────────────────────────────────────────────────

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.3)
              : colors.surface,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colors.primary : colors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          )),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
