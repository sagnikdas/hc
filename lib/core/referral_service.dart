import 'package:share_plus/share_plus.dart';

import '../data/models/referral_info.dart';
import '../data/repositories/referral_repository.dart';

/// Deep-link base used in invite messages.
/// Replace with the real app store / branch.io URL before launch.
const kInviteBaseUrl = 'https://hanumanapp.page.link/invite';

class ReferralService {
  final ReferralRepository _repo;

  ReferralService({ReferralRepository? repository})
      : _repo = repository ?? SqliteReferralRepository();

  /// Returns the existing referral info, creating one if this is the
  /// first time the method is called on this device.
  Future<ReferralInfo> getOrCreate() async {
    final existing = await _repo.get();
    if (existing != null) return existing;

    final fresh = ReferralInfo(referralCode: ReferralInfo.generateCode());
    await _repo.save(fresh);
    return fresh;
  }

  /// Shares the invite message via the platform share sheet and increments
  /// [ReferralInfo.inviteSentCount].
  Future<void> shareInvite() async {
    final info = await getOrCreate();
    final link = '$kInviteBaseUrl?ref=${info.referralCode}';
    final message =
        'Recite the Hanuman Chalisa every day — a beautiful app that tracks your devotion. 🙏\n'
        'Join with my code: ${info.referralCode}\n$link';

    await SharePlus.instance.share(ShareParams(text: message));

    final updated = info.copyWith(inviteSentCount: info.inviteSentCount + 1);
    await _repo.save(updated);
  }

  /// Shares a milestone card message (text-based; image card is Phase 3).
  Future<void> shareStreakMilestone(int streakDays) async {
    final info = await getOrCreate();
    final link = '$kInviteBaseUrl?ref=${info.referralCode}';
    final message =
        '🔥 $streakDays day streak! I recite the Hanuman Chalisa every day. 🙏\n'
        'Start yours: $link';

    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// Records a confirmed invite (called when a referred user completes their
  /// first play). Applies the 14-day reward if the threshold is reached.
  ///
  /// In Phase 3 this will be server-validated; here it runs locally.
  Future<ReferralInfo> recordConfirmedInvite() async {
    final info = await getOrCreate();
    final updated = info.copyWith(
      confirmedInviteCount: info.confirmedInviteCount + 1,
    );
    final withReward =
        updated.eligibleForReward ? _applyReward(updated) : updated;
    await _repo.save(withReward);
    return withReward;
  }

  /// Returns current referral info without side-effects.
  Future<ReferralInfo> currentInfo() => getOrCreate();

  // ── Private ──────────────────────────────────────────────────────────────────

  ReferralInfo _applyReward(ReferralInfo info) => info.copyWith(
        rewardEndsAt: DateTime.now().add(ReferralInfo.kRewardDuration),
      );
}
