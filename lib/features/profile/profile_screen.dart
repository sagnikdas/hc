import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../play/play_screen.dart';
import '../auth/profile_form_screen.dart';
import '../../core/transitions.dart';
import '../../core/supabase_service.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/models/user_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Settings
  int _selectedCount = 11;
  bool _hapticEnabled = true;
  bool _continuousPlay = false;

  // Auth & referral
  String? _referralCode;
  Map<String, dynamic>? _supabaseProfile;
  bool _authLoading = false;

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadReferralCode();
    _loadProfile();
    // React to sign-in / sign-out events.
    _authSub = SupabaseService.authStateChanges.listen((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await AppRepository.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _selectedCount = settings.targetCount;
      _hapticEnabled = settings.hapticEnabled;
      _continuousPlay = settings.continuousPlay;
    });
  }

  Future<void> _loadReferralCode() async {
    final code = await AppRepository.instance.getOrCreateReferralCode();
    if (!mounted) return;
    setState(() => _referralCode = code);
    // Sync referral code to Supabase if signed in.
    if (SupabaseService.currentUser != null) {
      unawaited(
        SupabaseService.upsertProfile(
          name: SupabaseService.currentUser!.userMetadata?['full_name'] as String? ?? '',
          email: SupabaseService.currentUser!.email ?? '',
          phone: '',
          dateOfBirth: DateTime(2000),
          referralCode: code,
        ).catchError((_) {}),
      );
    }
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile().catchError((_) => null);
    if (!mounted) return;
    setState(() => _supabaseProfile = profile);
  }

  Future<void> _saveSettings() async {
    await AppRepository.instance.saveSettings(UserSettings(
      targetCount: _selectedCount,
      hapticEnabled: _hapticEnabled,
      continuousPlay: _continuousPlay,
    ));
  }

  Future<void> _signIn() async {
    setState(() => _authLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileFormScreen()),
      );
      _loadProfile();
    } catch (e, st) {
      debugPrint('Google sign-in error: $e\n$st');
      if (mounted) {
        final msg = kDebugMode
            ? '$e'
            : (e is StateError)
                ? '$e'
                : 'Sign-in failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
        );
      }
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (mounted) setState(() => _supabaseProfile = null);
  }

  Future<void> _shareInvite() async {
    final code = _referralCode ??
        await AppRepository.instance.getOrCreateReferralCode();
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join me in the daily Hanuman Chalisa recitation! 🙏\n\n'
            'Use my referral code: $code\n\n'
            'Download the Hanuman Chalisa app and build your devotional streak.',
      ),
    );
  }

  static const _presets = [
    (count: 1, label: 'Once'),
    (count: 3, label: 'Trividha'),
    (count: 11, label: 'Ekadasha'),
    (count: 21, label: 'Vimsati'),
    (count: 51, label: 'Pancasat'),
    (count: 108, label: 'Mala'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(context, cs),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Column(
                    children: [
                      _buildAuthSection(context, cs),
                      const SizedBox(height: 20),
                      _buildInviteSection(context, cs),
                      const SizedBox(height: 20),
                      _buildIntro(context, cs),
                      const SizedBox(height: 28),
                      _buildRepetitionGrid(context, cs),
                      const SizedBox(height: 20),
                      _buildToggles(context, cs),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCTAButton(context, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 14, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 14),
              Text(
                'Sankalp Settings',
                style: GoogleFonts.notoSerif(
                    fontSize: 20,
                    color: cs.primary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
          Icon(Icons.auto_awesome_rounded, color: cs.secondary, size: 20),
        ],
      ),
    );
  }

  // ── Auth section ──────────────────────────────────────────────────────────

  Widget _buildAuthSection(BuildContext context, ColorScheme cs) {
    final user = SupabaseService.currentUser;

    if (user != null) {
      // Signed-in card
      final name = (_supabaseProfile?['name'] as String?)?.isNotEmpty == true
          ? _supabaseProfile!['name'] as String
          : user.userMetadata?['full_name'] as String? ?? 'Devotee';
      final email = user.email ?? '';
      final avatarUrl = user.userMetadata?['avatar_url'] as String?;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: cs.primary.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: GoogleFonts.notoSerif(
                          fontSize: 20, color: cs.onPrimaryContainer),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  if (email.isNotEmpty)
                    Text(email,
                        style: GoogleFonts.manrope(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            // Edit profile
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileFormScreen()),
                );
                _loadProfile();
              },
              child: Icon(Icons.edit_rounded,
                  color: cs.primary.withValues(alpha: 0.7), size: 18),
            ),
            const SizedBox(width: 12),
            // Sign out
            GestureDetector(
              onTap: _signOut,
              child: Icon(Icons.logout_rounded,
                  color: cs.onSurfaceVariant, size: 18),
            ),
          ],
        ),
      );
    }

    // Signed-out card
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(Icons.person_rounded,
                color: cs.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in to sync your paath',
                    style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
                Text('Leaderboard & cloud backup',
                    style: GoogleFonts.manrope(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _authLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                )
              : GestureDetector(
                  onTap: _signIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Sign in',
                        style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary)),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Invite / Referral section ─────────────────────────────────────────────

  Widget _buildInviteSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_rounded, color: cs.secondary, size: 18),
              const SizedBox(width: 10),
              Text(
                'Invite Devotees',
                style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_referralCode != null) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      _referralCode!,
                      style: GoogleFonts.notoSerif(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _shareInvite,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.share_rounded,
                        color: cs.onPrimary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with friends to invite them',
              style: GoogleFonts.manrope(
                  fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ] else
            const Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  // ── Devotional intent section ─────────────────────────────────────────────

  Widget _buildIntro(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        Text(
          'DEVOTIONAL INTENT',
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: cs.secondary,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Set Your Path',
          style: GoogleFonts.notoSerif(
              fontSize: 30,
              color: cs.onSurface,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Select the number of sacred recitations\nto complete your spiritual cycle today.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w300,
            height: 1.65,
          ),
        ),
      ],
    );
  }

  Widget _buildRepetitionGrid(BuildContext context, ColorScheme cs) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: _presets.map((p) {
        final isSelected = p.count == _selectedCount;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedCount = p.count);
            _saveSettings();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFF1C1B1B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.4)
                    : cs.outlineVariant.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: cs.primary.withValues(alpha: 0.08),
                          blurRadius: 15)
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${p.count}',
                        style: GoogleFonts.notoSerif(
                          fontSize: 26,
                          color:
                              isSelected ? cs.primary : cs.secondary,
                        ),
                      ),
                      Text(
                        p.label.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 8,
                          color: isSelected
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: cs.primary, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded,
                          size: 10, color: cs.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggles(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        _ToggleRow(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          subtitle: 'Tactile alert on completion',
          value: _hapticEnabled,
          onChanged: (v) {
            setState(() => _hapticEnabled = v);
            _saveSettings();
          },
          cs: cs,
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          icon: Icons.all_inclusive_rounded,
          title: 'Continuous Play',
          subtitle: 'No pauses between cycles',
          value: _continuousPlay,
          onChanged: (v) {
            setState(() => _continuousPlay = v);
            _saveSettings();
          },
          cs: cs,
        ),
      ],
    );
  }

  Widget _buildCTAButton(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).padding.bottom + 100,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [cs.surface, cs.surface.withValues(alpha: 0)],
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(slideUpRoute(
          PlayScreen(initialTarget: _selectedCount),
        )),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [cs.primary, cs.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primaryContainer.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Begin Recitation',
                style: GoogleFonts.notoSerif(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded,
                  color: cs.onPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF2A2A2A)),
            child: Icon(icon, color: cs.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cs.primary,
          ),
        ],
      ),
    );
  }
}
