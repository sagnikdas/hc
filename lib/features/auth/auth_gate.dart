import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/main_shell.dart';
import '../../data/repositories/app_repository.dart';
import '../onboarding/onboarding_screen.dart';

/// Routing entry-point. Checks if onboarding has been shown:
/// - First launch → OnboardingScreen
/// - Returning user → MainShell
///
/// Auth (Google Sign-In) is NOT gated here — core prayer flow is always free.
/// Sign-in is optional and lives inside ProfileScreen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _onboardingShown; // null while loading
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    // Avoid a permanent black/loading screen if local DB access/migration
    // hangs for any reason.
    _fallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_onboardingShown == null) {
        debugPrint('AuthGate: onboarding load fallback -> proceed to MainShell');
        setState(() => _onboardingShown = true);
      }
    });
  }

  Future<void> _checkOnboarding() async {
    try {
      final shown = await AppRepository.instance.isOnboardingShown();
      if (mounted) {
        debugPrint('AuthGate: onboardingShown=$shown');
        setState(() => _onboardingShown = shown);
      }
    } catch (e, st) {
      // If local DB migration/query fails (e.g., after schema changes),
      // the user should still be able to reach the app.
      debugPrint('AuthGate: onboarding load failed: $e\n$st');
      if (mounted) setState(() => _onboardingShown = true);
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingShown == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingShown!) {
      return const OnboardingScreen();
    }
    return const MainShell();
  }
}
