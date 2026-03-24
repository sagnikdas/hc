import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/app_config.dart';
import '../../core/auth_service.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/user_settings_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../growth/community_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _settingsRepo = SqliteUserSettingsRepository();
  final _profileRepo = SupabaseProfileRepository();

  UserSettings? _settings;
  UserProfile? _profile;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh when auth state changes (e.g. after email OTP verify).
    _authSub = SupabaseAuthService.instance.authStateChanges.listen((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await _settingsRepo.get();
    if (mounted) setState(() => _settings = s);
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) return;
    final p = await _profileRepo.get(userId);
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _toggleReminder(bool enabled) async {
    if (_settings == null) return;
    final updated = _settings!.copyWith(reminderEnabled: enabled);
    await _settingsRepo.save(updated);
    if (enabled) {
      await reminderService.scheduleAll();
    } else {
      await reminderService.cancelAll();
    }
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _saveDisplayName(String name) async {
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still signing in — please wait a moment and try again.')),
        );
      }
      return;
    }
    final trimmed = name.trim();
    final updated = (_profile ?? UserProfile(id: userId))
        .copyWith(displayName: trimmed.isEmpty ? null : trimmed);
    try {
      await _profileRepo.save(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      debugPrint('saveDisplayName failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save display name. Try again.')),
        );
      }
    }
  }

  Future<void> _toggleLeaderboard(bool value) async {
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still signing in — please wait a moment and try again.')),
        );
      }
      return;
    }
    final updated = (_profile ?? UserProfile(id: userId))
        .copyWith(leaderboardOptIn: value);
    try {
      await _profileRepo.save(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      debugPrint('toggleLeaderboard failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update leaderboard setting.')),
        );
      }
    }
  }

  Future<void> _toggleFriendsOnlyVisibility(bool value) async {
    final userId = SupabaseAuthService.instance.userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still signing in — please wait a moment and try again.')),
        );
      }
      return;
    }
    final updated = (_profile ?? UserProfile(id: userId))
        .copyWith(friendsOnlyVisibility: value);
    try {
      await _profileRepo.save(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      debugPrint('toggleFriendsOnlyVisibility failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update visibility setting.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Premium status ───────────────────────────────────────────
                ValueListenableBuilder(
                  valueListenable: entitlementNotifier,
                  builder: (context, entitlement, _) {
                    if (!entitlement.isActive) return const SizedBox.shrink();
                    return _SectionBanner(
                      icon: Icons.workspace_premium,
                      label: 'Premium active — ${entitlement.planType.name}',
                      colors: colors,
                    );
                  },
                ),

                // ── Account ──────────────────────────────────────────────────
                if (AppConfig.isSupabaseConfigured) ...[
                  _SectionHeader('Account'),
                  _AccountTile(onLinked: _loadProfile),
                  const Divider(),
                ],

                // ── Leaderboard ──────────────────────────────────────────────
                if (AppConfig.isSupabaseConfigured) ...[
                  _SectionHeader('Leaderboard'),
                  _DisplayNameTile(
                    current: _profile?.displayName,
                    onSave: _saveDisplayName,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.leaderboard_outlined),
                    title: const Text('Show on leaderboard'),
                    subtitle: const Text('Your name appears in the global top 10'),
                    value: _profile?.leaderboardOptIn ?? true,
                    onChanged: _toggleLeaderboard,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.group_outlined),
                    title: const Text('Friends-only visibility'),
                    subtitle: const Text(
                        'Hide from global leaderboard until friends feed is enabled'),
                    value: _profile?.friendsOnlyVisibility ?? false,
                    onChanged: _toggleFriendsOnlyVisibility,
                  ),
                  const Divider(),
                ],

                // ── Reminders ────────────────────────────────────────────────
                _SectionHeader('Reminders'),
                SwitchListTile(
                  title: const Text('Daily reminders'),
                  subtitle: const Text('Morning & evening devotion windows'),
                  value: _settings!.reminderEnabled,
                  onChanged: _toggleReminder,
                  secondary: const Icon(Icons.notifications_outlined),
                ),

                const Divider(),

                // ── Community ────────────────────────────────────────────────
                _SectionHeader('Community'),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Invite friends'),
                  subtitle: const Text('Earn 14 days Premium for 3 invites'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CommunityScreen(referralService: referralService),
                  )),
                ),

                const Divider(),

                // ── About ────────────────────────────────────────────────────
                _SectionHeader('About'),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('App version'),
                  subtitle: Text('1.0.0'),
                ),
              ],
            ),
    );
  }
}

// ── Account tile ──────────────────────────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final VoidCallback onLinked;
  const _AccountTile({required this.onLinked});

  bool get _isAnonymous =>
      SupabaseAuthService.instance.currentUser?.isAnonymous ?? true;

  String? get _email =>
      SupabaseAuthService.instance.currentUser?.email;

  @override
  Widget build(BuildContext context) {
    if (_isAnonymous) {
      return ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Guest account'),
        subtitle: const Text('Link your email to sync across devices'),
        trailing: TextButton(
          onPressed: () => _showLinkDialog(context),
          child: const Text('Link email'),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('Linked account'),
      subtitle: Text(_email ?? ''),
    );
  }

  Future<void> _showLinkDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LinkEmailDialog(onLinked: onLinked),
    );
  }
}

// ── Link email dialog (two-step: email → OTP) ─────────────────────────────────

class _LinkEmailDialog extends StatefulWidget {
  final VoidCallback onLinked;
  const _LinkEmailDialog({required this.onLinked});

  @override
  State<_LinkEmailDialog> createState() => _LinkEmailDialogState();
}

class _LinkEmailDialogState extends State<_LinkEmailDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final ok = await SupabaseAuthService.instance.requestEmailOtp(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _otpSent = ok;
      if (!ok) _error = 'Could not send code. Check your connection and try again.';
    });
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final token = _otpController.text.trim();
    if (token.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final ok = await SupabaseAuthService.instance.verifyEmailOtp(email, token);
    if (!mounted) return;
    setState(() { _loading = false; });
    if (ok) {
      widget.onLinked();
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Invalid or expired code. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_otpSent) ...[
            const Text('Enter your email to receive a one-time code.'),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Text(
              'A 6-digit code was sent to ${_emailController.text.trim()}.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'One-time code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : (_otpSent ? _verifyOtp : _sendOtp),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_otpSent ? 'Verify' : 'Send code'),
        ),
      ],
    );
  }
}

// ── Display name tile ─────────────────────────────────────────────────────────

class _DisplayNameTile extends StatelessWidget {
  final String? current;
  final Future<void> Function(String) onSave;
  const _DisplayNameTile({required this.current, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Display name'),
      subtitle: Text(current?.isNotEmpty == true ? current! : 'Not set'),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => _showEditDialog(context),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: current ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'Your name on the leaderboard',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) await onSave(saved);
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
      );
}

class _SectionBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colors;
  const _SectionBanner(
      {required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
}
