import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_secrets.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  static final _googleSignIn = GoogleSignIn(
    serverClientId: kGoogleWebClientId,
  );

  // ── Auth ─────────────────────────────────────────────────────────────────

  static User? get currentUser => supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;

  static Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Google id_token is null');

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await supabase.auth.signOut();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchProfile() async {
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
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;

    final age = _calcAge(dateOfBirth);
    await supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'age': age,
    });
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
}
