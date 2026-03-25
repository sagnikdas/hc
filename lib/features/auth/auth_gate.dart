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

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final shown = await AppRepository.instance.isOnboardingShown();
    if (mounted) setState(() => _onboardingShown = shown);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingShown == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF131313),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_onboardingShown!) {
      return const OnboardingScreen();
    }
    return const MainShell();
  }
}
