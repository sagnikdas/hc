import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

/// Manages Supabase authentication.
///
/// On first launch the app signs in anonymously so every install has a stable
/// user ID immediately — no registration friction. The user can later upgrade
/// to a named account (email OTP) to persist across devices.
class SupabaseAuthService {
  SupabaseAuthService._();

  static final SupabaseAuthService instance = SupabaseAuthService._();

  SupabaseClient? get _client =>
      AppConfig.isSupabaseConfigured ? Supabase.instance.client : null;

  /// The currently authenticated user, or null when offline / unconfigured.
  User? get currentUser => _client?.auth.currentUser;

  /// Stable user ID for this install. Null if Supabase is not configured or
  /// the sign-in hasn't completed yet.
  String? get userId => currentUser?.id;

  bool get isSignedIn => currentUser != null;

  /// Ensures an anonymous session exists. Call once during app init.
  /// Safe to call multiple times — no-ops if already signed in.
  Future<void> ensureSignedIn() async {
    final client = _client;
    if (client == null) return;

    if (isSignedIn) return;

    try {
      await client.auth.signInAnonymously();
      debugPrint('SupabaseAuthService: anonymous sign-in OK — uid=$userId');
    } catch (e) {
      // Non-fatal: the app works fully offline without a session.
      debugPrint('SupabaseAuthService: anonymous sign-in failed — $e');
    }
  }

  /// Links an email address to the current account.
  ///
  /// Ensures an anonymous session exists first (idempotent), then calls
  /// [updateUser] to upgrade in-place — the user ID is preserved and no data
  /// is lost. Supabase sends a 6-digit OTP via the "Email Change" template.
  /// Returns true if the request was accepted.
  Future<bool> requestEmailOtp(String email) async {
    final client = _client;
    if (client == null) return false;

    // Guarantee a session exists before calling updateUser.
    // ensureSignedIn is idempotent — no-op if already signed in.
    await ensureSignedIn();

    if (!isSignedIn) {
      debugPrint('SupabaseAuthService: no session after ensureSignedIn — cannot link email');
      return false;
    }

    try {
      await client.auth.updateUser(UserAttributes(email: email));
      return true;
    } catch (e) {
      debugPrint('SupabaseAuthService: email link request failed — $e');
      return false;
    }
  }

  /// Verifies the 6-digit OTP the user received after [requestEmailOtp].
  /// Returns true on success (email linked, same uid retained).
  Future<bool> verifyEmailOtp(String email, String token) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.emailChange,
      );
      return true;
    } catch (e) {
      debugPrint('SupabaseAuthService: OTP verify failed — $e');
      return false;
    }
  }

  /// Signs out. The next call to [ensureSignedIn] will create a new anonymous
  /// session (new uid — leaderboard progress lost unless account was upgraded).
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  /// Stream of auth state changes for widgets that need to react (e.g. profile
  /// screen showing whether the account is anonymous or named).
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();
}
