import 'package:flutter/material.dart';
import '../../main.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/user_settings_repository.dart';
import '../growth/community_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _settingsRepo = SqliteUserSettingsRepository();
  UserSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsRepo.get();
    if (mounted) setState(() => _settings = s);
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

                // ── Growth ───────────────────────────────────────────────────
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

                // ── App info ─────────────────────────────────────────────────
                _SectionHeader('About'),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App version'),
                  subtitle: const Text('1.0.0'),
                ),
              ],
            ),
    );
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
