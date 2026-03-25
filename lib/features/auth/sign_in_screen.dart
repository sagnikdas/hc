import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.signInWithGoogle();
    } catch (e, st) {
      debugPrint('Google sign-in error: $e\n$st');
      if (mounted) {
        setState(() => _error = kDebugMode
            ? '$e'
            : (e is StateError)
                ? '$e'
                : 'Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer.withValues(alpha: 0.4),
                ),
                child: Icon(Icons.self_improvement, size: 48, color: colors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Hanuman Chalisa',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to track your paath',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const Spacer(flex: 2),
              // Google button
              _loading
                  ? CircularProgressIndicator(color: colors.primary)
                  : OutlinedButton.icon(
                      onPressed: _signIn,
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 20),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: colors.onSurface,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: colors.error, fontSize: 13)),
              ],
              const Spacer(flex: 3),
              Text(
                'By continuing you agree to our terms of service',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
