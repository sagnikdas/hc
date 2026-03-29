import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/main_shell.dart';
import '../../core/notification_service.dart';
import '../../core/supabase_service.dart';
import '../../data/repositories/app_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _starting = false;
  bool _signingIn = false;
  String? _signInError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_starting) return;
    setState(() => _starting = true);
    await AppRepository.instance.markOnboardingShown();
    await NotificationService.requestPermissions();
    await NotificationService.scheduleDailyReminders();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _onSignInWithGoogle() async {
    if (_signingIn || _starting) return;
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
    } catch (e, st) {
      debugPrint('Onboarding Google sign-in error: $e\n$st');
      if (mounted) {
        setState(() {
          _signingIn = false;
          _signInError = kDebugMode
              ? '$e'
              : (e is StateError)
                  ? '$e'
                  : 'Sign-in failed. Please try again.';
        });
      }
      // Always exit — never fall through to _proceed() on error.
      return;
    }
    // If the user cancelled the picker, signInWithGoogle() returns normally
    // but no session is created. In that case, reset the loading state and
    // stay on the onboarding screen so they can try again or skip explicitly.
    if (SupabaseService.currentUser == null) {
      if (mounted) setState(() => _signingIn = false);
      return;
    }
    await _proceed();
  }

  Future<void> _onSkip() async {
    await _proceed();
  }

  void _onShare() {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Join me in the daily Hanuman Chalisa recitation! 🙏\n\n'
            'I use this beautiful app to track my paath every day.\n'
            'Download it and strengthen your devotion.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Sacred symbol
              Text(
                'ॐ',
                style: GoogleFonts.notoSerif(
                  fontSize: 72,
                  color: cs.primary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 28),
              // Title
              Text(
                'Hanuman Chalisa',
                style: GoogleFonts.notoSerif(
                  fontSize: 30,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your daily companion for devotion',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(flex: 1),
              // Feature cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _FeatureTile(
                      icon: Icons.track_changes_rounded,
                      title: 'Track Your Paath',
                      subtitle: 'Count completions, build streaks, see your progress.',
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.wifi_off_rounded,
                      title: 'Works Offline',
                      subtitle: 'Listen and chant anytime — no internet needed.',
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.people_rounded,
                      title: 'Community Leaderboard',
                      subtitle: 'Join thousands of devotees in daily recitation.',
                      cs: cs,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // WhatsApp / share CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GestureDetector(
                  onTap: _onShare,
                  child: Container(
                    width: size.width,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded, color: cs.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Invite devotees via WhatsApp',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Sign in with Google (primary CTA)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GestureDetector(
                  onTap: (_signingIn || _starting) ? null : _onSignInWithGoogle,
                  child: Container(
                    width: size.width,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: (_signingIn || _starting)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Continue with Google',
                                  style: GoogleFonts.notoSerif(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (_signInError != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _signInError!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // Skip for now (secondary)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  32, 4, 32, MediaQuery.of(context).padding.bottom + 20,
                ),
                child: GestureDetector(
                  onTap: (_signingIn || _starting) ? null : _onSkip,
                  child: SizedBox(
                    width: size.width,
                    height: 44,
                    child: Center(
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
