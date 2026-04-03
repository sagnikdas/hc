import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../auth/profile_form_screen.dart';
import '../../core/font_scale_notifier.dart';
import '../../core/theme_notifier.dart';
import '../../core/notification_service.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/app_repository.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Settings
  bool _hapticEnabled = true;
  bool _continuousPlay = false;
  double _fontScale = 1.0;
  bool _reminderEnabled = true;
  bool _sacredDayEnabled = true;
  int _morningMinutes = UserSettings.defaultReminderMorningMinutes;
  int _eveningMinutes = UserSettings.defaultReminderEveningMinutes;
  ThemeMode _themeMode = ThemeMode.dark;

  // Auth
  Map<String, dynamic>? _supabaseProfile;
  bool _authLoading = false;

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
      _hapticEnabled = settings.hapticEnabled;
      _continuousPlay = settings.continuousPlay;
      _fontScale = settings.fontScale.clamp(0.8, 1.4);
      _reminderEnabled = settings.reminderNotificationsEnabled;
      _sacredDayEnabled = settings.sacredDayNotificationsEnabled;
      _morningMinutes = settings.reminderMorningMinutes;
      _eveningMinutes = settings.reminderEveningMinutes;
      _themeMode = ThemeMode.values[settings.themeMode.clamp(0, 2)];
    });
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile().catchError((_) => null);
    if (!mounted) return;
    setState(() => _supabaseProfile = profile);
  }

  /// Persists all settings to the DB and applies non-reminder side effects
  /// (font scale, theme mode). Pass [updateReminders] when a reminder-related
  /// setting changed so the notification schedule is also refreshed.
  Future<void> _saveSettings({bool updateReminders = false}) async {
    final current = await AppRepository.instance.getSettings();
    final updated = current.copyWith(
      hapticEnabled: _hapticEnabled,
      continuousPlay: _continuousPlay,
      fontScale: _fontScale.clamp(0.8, 1.4),
      reminderNotificationsEnabled: _reminderEnabled,
      reminderMorningMinutes: _morningMinutes,
      reminderEveningMinutes: _eveningMinutes,
      sacredDayNotificationsEnabled: _sacredDayEnabled,
      themeMode: _themeMode.index,
    );
    await AppRepository.instance.saveSettings(updated);
    fontScaleNotifier.value = _fontScale.clamp(0.8, 1.4);
    themeModeNotifier.value = _themeMode;

    if (!updateReminders) return;

    if (updated.reminderNotificationsEnabled) {
      final granted = await NotificationService.requestPermissions();
      if (!mounted) return;
      if (!granted) {
        // Revert: save disabled state so DB stays in sync with what the OS allows.
        setState(() => _reminderEnabled = false);
        await AppRepository.instance.saveSettings(
          updated.copyWith(reminderNotificationsEnabled: false),
        );
        await NotificationService.cancelReminders();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notifications are disabled. Enable them in system settings to receive reminders.',
              style: GoogleFonts.manrope(),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
    }
    await NotificationService.applyReminderSchedule(updated);
  }

  Future<void> _onReminderEnabledChanged(bool v) async {
    setState(() => _reminderEnabled = v);
    // Track reminder toggle event
    try {
      await analytics.logEvent(
        name: 'reminders_toggled',
        parameters: {
          'enabled': v,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
    await _saveSettings(updateReminders: true);
  }

  String _formatReminderTimeLabel(BuildContext context, int minutes) {
    final t = TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
    return t.format(context);
  }

  Future<void> _pickMorningReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _morningMinutes ~/ 60,
        minute: _morningMinutes % 60,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _morningMinutes = UserSettings.clampReminderMinutes(
        picked.hour * 60 + picked.minute,
      );
    });
    await _saveSettings(updateReminders: true);
  }

  Future<void> _pickEveningReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _eveningMinutes ~/ 60,
        minute: _eveningMinutes % 60,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _eveningMinutes = UserSettings.clampReminderMinutes(
        picked.hour * 60 + picked.minute,
      );
    });
    await _saveSettings(updateReminders: true);
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
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join me in the daily Hanuman Chalisa recitation! 🙏\n\n'
            'Download the Hanuman Chalisa app and build your devotional streak.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: context.sp(-60),
            right: context.sp(-60),
            child: Container(
              width: context.sp(280),
              height: context.sp(280),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: context.sp(-40),
            left: context.sp(-60),
            child: Container(
              width: context.sp(240),
              height: context.sp(240),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(context, cs),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(context.sp(24), context.sp(4), context.sp(24), context.sp(24)),
                  child: Column(
                    children: [
                      _buildAuthSection(context, cs),
                      SizedBox(height: context.sp(24)),
                      _buildPlaybackSettings(context, cs),
                      SizedBox(height: context.sp(20)),
                      _buildThemeSection(context, cs),
                      SizedBox(height: context.sp(20)),
                      _buildReminderSection(context, cs),
                      SizedBox(height: context.sp(20)),
                      _buildInviteSection(context, cs),
                      SizedBox(height: context.sp(24)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          context.sp(24), MediaQuery.of(context).padding.top + context.sp(12), context.sp(24), context.sp(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLow, cs.surface.withValues(alpha: 0)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.tune_rounded,
              color: cs.primary.withValues(alpha: 0.6), size: context.sp(24)),
          Flexible(
            child: Text(
              'Sankalp Settings',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerif(
                  fontSize: context.sp(20), color: cs.primary, letterSpacing: -0.3),
            ),
          ),
          SizedBox(width: context.sp(24)),
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
        padding: EdgeInsets.all(context.sp(16)),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.sp(16)),
          border: Border.all(
              color: cs.primary.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: context.sp(26),
              backgroundColor: cs.primaryContainer,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: GoogleFonts.notoSerif(
                          fontSize: context.sp(20), color: cs.onPrimaryContainer),
                    )
                  : null,
            ),
            SizedBox(width: context.sp(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  if (email.isNotEmpty)
                    Text(email,
                        style: GoogleFonts.manrope(
                            fontSize: context.sp(11), color: cs.onSurfaceVariant)),
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
                  color: cs.primary.withValues(alpha: 0.7), size: context.sp(18)),
            ),
            SizedBox(width: context.sp(12)),
            // Sign out
            GestureDetector(
              onTap: _signOut,
              child: Icon(Icons.logout_rounded,
                  color: cs.onSurfaceVariant, size: context.sp(18)),
            ),
          ],
        ),
      );
    }

    // Signed-out card
    return Container(
      padding: EdgeInsets.all(context.sp(16)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(16)),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: context.sp(52),
            height: context.sp(52),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.3),
            ),
            child: Icon(Icons.person_rounded,
                color: cs.primary, size: context.sp(28)),
          ),
          SizedBox(width: context.sp(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in to sync your paath',
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
                Text('Leaderboard & cloud backup',
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(11), color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(width: context.sp(10)),
          _authLoading
              ? SizedBox(
                  width: context.sp(20),
                  height: context.sp(20),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                )
              : GestureDetector(
                  onTap: _signIn,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.sp(14), vertical: context.sp(8)),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(context.sp(10)),
                    ),
                    child: Text('Sign in',
                        style: GoogleFonts.manrope(
                            fontSize: context.sp(12),
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary)),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Invite section ────────────────────────────────────────────────────────

  Widget _buildInviteSection(BuildContext context, ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(context.sp(16)),
      child: InkWell(
        onTap: _shareInvite,
        borderRadius: BorderRadius.circular(context.sp(16)),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: context.sp(16), vertical: context.sp(14)),
          child: Row(
            children: [
              Container(
                width: context.sp(38),
                height: context.sp(38),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHigh,
                ),
                child: Icon(Icons.people_rounded,
                    color: cs.primary, size: context.sp(18)),
              ),
              SizedBox(width: context.sp(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite Devotees',
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(13),
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface),
                    ),
                    Text(
                      'Share the app with friends',
                      style: GoogleFonts.manrope(
                          fontSize: context.sp(10), color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.share_rounded,
                  color: cs.primary, size: context.sp(20)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildThemeSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.all(context.sp(16)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: cs.primary, size: context.sp(18)),
              SizedBox(width: context.sp(10)),
              Text(
                'Appearance',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(14)),
          _buildFontSizeSlider(context, cs),
          SizedBox(height: context.sp(14)),
          Row(
            children: [
              _ThemeTile(
                icon: Icons.brightness_auto_rounded,
                label: 'Auto',
                selected: _themeMode == ThemeMode.system,
                onTap: () { setState(() => _themeMode = ThemeMode.system); _saveSettings(); },
                cs: cs,
              ),
              SizedBox(width: context.sp(8)),
              _ThemeTile(
                icon: Icons.light_mode_rounded,
                label: 'Light',
                selected: _themeMode == ThemeMode.light,
                onTap: () { setState(() => _themeMode = ThemeMode.light); _saveSettings(); },
                cs: cs,
              ),
              SizedBox(width: context.sp(8)),
              _ThemeTile(
                icon: Icons.dark_mode_rounded,
                label: 'Dark',
                selected: _themeMode == ThemeMode.dark,
                onTap: () { setState(() => _themeMode = ThemeMode.dark); _saveSettings(); },
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.all(context.sp(16)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: cs.primary, size: context.sp(18)),
              SizedBox(width: context.sp(10)),
              Text(
                'Paath reminders',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(12)),
          _ToggleRow(
            icon: Icons.notifications_rounded,
            title: 'Daily reminders',
            subtitle: 'Nudge to chant morning & evening',
            value: _reminderEnabled,
            onChanged: _onReminderEnabledChanged,
            cs: cs,
          ),
          if (_reminderEnabled) ...[
            SizedBox(height: context.sp(10)),
            _ReminderTimeRow(
              label: 'Morning',
              timeLabel: _formatReminderTimeLabel(context, _morningMinutes),
              onTap: _pickMorningReminderTime,
              cs: cs,
            ),
            SizedBox(height: context.sp(8)),
            _ReminderTimeRow(
              label: 'Evening',
              timeLabel: _formatReminderTimeLabel(context, _eveningMinutes),
              onTap: _pickEveningReminderTime,
              cs: cs,
            ),
            SizedBox(height: context.sp(10)),
            _ToggleRow(
              icon: Icons.auto_awesome_rounded,
              title: 'Sacred day alerts',
              subtitle: 'Special notification on Tue & Sat',
              value: _sacredDayEnabled,
              onChanged: (v) {
                setState(() => _sacredDayEnabled = v);
                _saveSettings(updateReminders: true);
              },
              cs: cs,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaybackSettings(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.all(context.sp(16)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.sp(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: cs.primary, size: context.sp(18)),
              SizedBox(width: context.sp(10)),
              Text(
                'Playback',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(14)),
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
          SizedBox(height: context.sp(10)),
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
      ),
    );
  }

  Widget _buildFontSizeSlider(BuildContext context, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.sp(14), vertical: context.sp(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.sp(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_increase_rounded, color: cs.primary, size: context.sp(18)),
              SizedBox(width: context.sp(10)),
              Text(
                'Font Size',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${_fontScale.toStringAsFixed(1)}×',
                style: GoogleFonts.manrope(
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(10)),
          Slider(
            value: _fontScale,
            min: 0.8,
            max: 1.4,
            onChanged: (v) {
              setState(() => _fontScale = v);
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          SizedBox(height: context.sp(2)),
          Text(
            'Helpful for elderly devotees.',
            style: GoogleFonts.manrope(
              fontSize: context.sp(11),
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ThemeTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: context.sp(12)),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(context.sp(12)),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: context.sp(20),
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              SizedBox(height: context.sp(4)),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: context.sp(11),
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTimeRow extends StatelessWidget {
  final String label;
  final String timeLabel;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ReminderTimeRow({
    required this.label,
    required this.timeLabel,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(context.sp(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.sp(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(14),
            vertical: context.sp(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                timeLabel,
                style: GoogleFonts.manrope(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(width: context.sp(4)),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: context.sp(20)),
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
      padding: EdgeInsets.symmetric(horizontal: context.sp(14), vertical: context.sp(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.sp(16)),
      ),
      child: Row(
        children: [
          Container(
            width: context.sp(38),
            height: context.sp(38),
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: cs.surfaceContainerHigh),
            child: Icon(icon, color: cs.primary, size: context.sp(18)),
          ),
          SizedBox(width: context.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        fontSize: context.sp(10), color: cs.onSurfaceVariant)),
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
