import 'package:flutter/material.dart';

import '../../core/referral_service.dart';
import '../../data/models/referral_info.dart';

/// Community onboarding screen — shows the user's referral code, progress
/// toward the 3-invite reward, and a WhatsApp-friendly share CTA.
class CommunityScreen extends StatefulWidget {
  final ReferralService referralService;

  const CommunityScreen({super.key, required this.referralService});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  ReferralInfo? _info;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await widget.referralService.currentInfo();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _onShare() async {
    setState(() => _sharing = true);
    try {
      await widget.referralService.shareInvite();
      await _load(); // refresh sent count
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: _info == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, colors, _info!),
    );
  }

  Widget _buildBody(
      BuildContext context, ColorScheme colors, ReferralInfo info) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroSection(context, colors),
          const SizedBox(height: 32),
          _buildReferralCodeCard(context, colors, info),
          const SizedBox(height: 24),
          _buildRewardProgress(context, colors, info),
          const SizedBox(height: 32),
          _buildShareButton(context, colors),
          const SizedBox(height: 16),
          _buildShareHint(context, colors),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ColorScheme colors) {
    return Column(
      children: [
        Icon(Icons.people, size: 64, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          'Invite Your Loved Ones',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Invite 3 friends and unlock\nPremium Voice for 14 days.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReferralCodeCard(
      BuildContext context, ColorScheme colors, ReferralInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Your Code',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            info.referralCode,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
          ),
          if (info.inviteSentCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Shared ${info.inviteSentCount} time${info.inviteSentCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardProgress(
      BuildContext context, ColorScheme colors, ReferralInfo info) {
    final confirmed = info.confirmedInviteCount;
    final threshold = ReferralInfo.kRewardThreshold;
    final progress = (confirmed / threshold).clamp(0.0, 1.0);

    if (info.hasActiveReward) {
      final days = info.rewardEndsAt!.difference(DateTime.now()).inDays + 1;
      return _RewardBanner(
        message: '🎉 Premium Voice unlocked! $days day${days == 1 ? '' : 's'} remaining.',
        colors: colors,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Successful Invites',
                style: Theme.of(context).textTheme.labelLarge),
            Text('$confirmed / $threshold',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          confirmed < threshold
              ? 'Invite ${threshold - confirmed} more friend${threshold - confirmed == 1 ? '' : 's'} to unlock your reward!'
              : 'Reward on its way!',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildShareButton(BuildContext context, ColorScheme colors) {
    return FilledButton.icon(
      onPressed: _sharing ? null : _onShare,
      icon: _sharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share),
      label: const Text('Share via WhatsApp'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildShareHint(BuildContext context, ColorScheme colors) {
    return Text(
      'Sharing sends a ready-made message with your referral code.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Reward banner ─────────────────────────────────────────────────────────────

class _RewardBanner extends StatelessWidget {
  final String message;
  final ColorScheme colors;
  const _RewardBanner({required this.message, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: colors.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
