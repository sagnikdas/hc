import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_secrets.dart';
import '../data/models/play_session.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  static bool _googleInitialized = false;

  static Future<void> _initGoogleSignIn() async {
    if (_googleInitialized) return;
    _googleInitialized = true;
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleWebClientId);
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  // ── Test seams ───────────────────────────────────────────────────────────
  // Set these in unit tests to avoid touching the Supabase SDK.

  @visibleForTesting
  static User? Function()? currentUserForTest;
  @visibleForTesting
  static Stream<AuthState>? authChangesForTest;
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function()? fetchProfileForTest;
  @visibleForTesting
  static Future<void> Function()? signInForTest;
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function({required bool weekly})?
      fetchLeaderboardForTest;
  @visibleForTesting
  static Future<void> Function({
    required String name,
    required String email,
    required String phone,
    required DateTime dateOfBirth,
    String? referralCode,
  })? upsertProfileForTest;

  @visibleForTesting
  static void resetAuthForTest() {
    currentUserForTest = null;
    authChangesForTest = null;
    fetchProfileForTest = null;
    signInForTest = null;
    fetchLeaderboardForTest = null;
    upsertProfileForTest = null;
    _googleInitialized = false;
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  static User? get currentUser =>
      currentUserForTest != null ? currentUserForTest!() : supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      authChangesForTest ?? supabase.auth.onAuthStateChange;

  static Future<void> signInWithGoogle() async {
    if (signInForTest != null) return signInForTest!();
    if (!_isGoogleWebClientIdConfigured) {
      throw StateError(
        'Google Sign-In: set kGoogleWebClientId in lib/core/app_secrets.dart to '
        'your OAuth "Web application" client ID (the same Client ID as in '
        'Supabase → Authentication → Providers → Google). '
        'See docs/SUPABASE_AND_GOOGLE_SSO_SETUP.md section 5.1.',
      );
    }

    await _initGoogleSignIn();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return; // user cancelled
      rethrow;
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return an id_token. Use the Web application OAuth '
        'client ID (not Android/iOS) for kGoogleWebClientId, and ensure that '
        'Android SHA-1 / iOS URL scheme match Google Cloud Console.',
      );
    }

    try {
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on AuthException catch (e) {
      debugPrint('Supabase signInWithIdToken: ${e.message}');
      rethrow;
    }
  }

  /// True when [kGoogleWebClientId] looks like a real Web client ID, not the template.
  static bool get _isGoogleWebClientIdConfigured {
    final id = kGoogleWebClientId.trim();
    if (id.contains('YOUR_WEB')) return false;
    return RegExp(
      r'^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$',
    ).hasMatch(id);
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await supabase.auth.signOut();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchProfile() async {
    if (fetchProfileForTest != null) return fetchProfileForTest!();
    final uid = currentUser?.id;
    if (uid == null) return null;
    final res = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    return res;
  }

  static Future<void> upsertProfile({
    required String name,
    required String email,
    required String phone,
    required DateTime dateOfBirth,
    String? referralCode,
  }) async {
    if (upsertProfileForTest != null) {
      return upsertProfileForTest!(
        name: name,
        email: email,
        phone: phone,
        dateOfBirth: dateOfBirth,
        referralCode: referralCode,
      );
    }
    final uid = currentUser?.id;
    if (uid == null) return;

    final age = _calcAge(dateOfBirth);
    final data = <String, dynamic>{
      'id': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'age': age,
    };
    if (referralCode != null) data['referral_code'] = referralCode;

    await supabase.from('profiles').upsert(data);
  }

  static int _calcAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  // ── Completions sync ──────────────────────────────────────────────────────
  //
  // Required Supabase schema (run in Supabase SQL editor):
  //
  //   CREATE TABLE IF NOT EXISTS completions (
  //     id          BIGSERIAL PRIMARY KEY,
  //     user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  //     completed_at TIMESTAMPTZ NOT NULL,
  //     session_date DATE NOT NULL,
  //     count       INTEGER NOT NULL DEFAULT 1,
  //     created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  //   );
  //   CREATE INDEX idx_completions_user_id ON completions(user_id);
  //   CREATE INDEX idx_completions_completed_at ON completions(completed_at);
  //   ALTER TABLE completions ENABLE ROW LEVEL SECURITY;
  //   CREATE POLICY "Users insert own completions"
  //     ON completions FOR INSERT WITH CHECK (auth.uid() = user_id);
  //   CREATE POLICY "Anyone can read completions"
  //     ON completions FOR SELECT USING (true);

  /// Syncs a local session to Supabase. No-op if user is not signed in.
  /// Designed to be called fire-and-forget via unawaited().
  static Future<void> syncCompletion(PlaySession session) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await supabase.from('completions').insert({
      'user_id': uid,
      'completed_at': DateTime.fromMillisecondsSinceEpoch(session.completedAt)
          .toUtc()
          .toIso8601String(),
      'session_date': session.date,
      'count': session.count,
    });
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────
  //
  // Required Supabase RPC (run in SQL editor):
  //
  //   CREATE OR REPLACE FUNCTION get_leaderboard(p_weekly BOOLEAN)
  //   RETURNS TABLE (
  //     rank         BIGINT,
  //     user_id      UUID,
  //     display_name TEXT,
  //     total_count  BIGINT
  //   ) LANGUAGE SQL STABLE AS $$
  //     SELECT
  //       RANK() OVER (ORDER BY SUM(c.count) DESC) AS rank,
  //       c.user_id,
  //       COALESCE(p.name, 'Devotee') AS display_name,
  //       SUM(c.count) AS total_count
  //     FROM completions c
  //     LEFT JOIN profiles p ON p.id = c.user_id
  //     WHERE CASE WHEN p_weekly
  //       THEN c.completed_at >= NOW() - INTERVAL '7 days'
  //       ELSE true END
  //     GROUP BY c.user_id, p.name
  //     ORDER BY total_count DESC
  //     LIMIT 10;
  //   $$;
  //   GRANT EXECUTE ON FUNCTION get_leaderboard TO anon, authenticated;

  /// Returns top-10 leaderboard entries.
  /// Each entry: {rank, user_id, display_name, total_count}
  static Future<List<Map<String, dynamic>>> fetchLeaderboard({
    required bool weekly,
  }) async {
    if (fetchLeaderboardForTest != null) {
      return fetchLeaderboardForTest!(weekly: weekly);
    }
    final data = await supabase
        .rpc('get_leaderboard', params: {'p_weekly': weekly}) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }
}
