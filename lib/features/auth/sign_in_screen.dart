import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';

class SignInScreen extends StatefulWidget {
  /// When true (e.g. opened from Progress upsell), starts the Google account
  /// picker as soon as this route is shown so the user is not asked to tap twice.
  final bool launchGoogleSignInImmediately;

  const SignInScreen({
    super.key,
    this.launchGoogleSignInImmediately = false,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.launchGoogleSignInImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
      if (!mounted) return;
      if (SupabaseService.currentUser != null) {
        Navigator.of(context).pop();
        return;
      }
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
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.sp(32)),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Icon
              Container(
                width: context.sp(88),
                height: context.sp(88),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer.withValues(alpha: 0.4),
                ),
                child: Icon(Icons.self_improvement, size: context.sp(48), color: colors.primary),
              ),
              SizedBox(height: context.sp(24)),
              Text(
                'Hanuman Chalisa',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              SizedBox(height: context.sp(8)),
              Text(
                widget.launchGoogleSignInImmediately && _loading
                    ? 'Opening Google sign-in…'
                    : 'Sign in to track your paath',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // Google button
              _loading
                  ? CircularProgressIndicator(color: colors.primary)
                  : OutlinedButton.icon(
                      onPressed: _signIn,
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: context.sp(20),
                        height: context.sp(20),
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.login, size: context.sp(20)),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: context.sp(24), vertical: context.sp(14)),
                        side: BorderSide(color: colors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.sp(12)),
                        ),
                        foregroundColor: colors.onSurface,
                        textStyle: TextStyle(fontSize: context.sp(15), fontWeight: FontWeight.w500),
                      ),
                    ),
              if (_error != null) ...[
                SizedBox(height: context.sp(16)),
                Text(_error!, style: TextStyle(color: colors.error, fontSize: context.sp(13))),
              ],
              const Spacer(flex: 3),
              Text(
                'By continuing you agree to our terms of service',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.sp(16)),
            ],
          ),
        ),
      ),
    );
  }
}
