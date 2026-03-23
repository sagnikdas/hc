import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/data/models/referral_info.dart';
import 'package:hanuman_chalisa/data/repositories/referral_repository.dart';
import 'package:hanuman_chalisa/core/referral_service.dart';

// ── In-memory stub repository ─────────────────────────────────────────────────

class _MemReferralRepository implements ReferralRepository {
  ReferralInfo? _stored;

  @override
  Future<ReferralInfo?> get() async => _stored;

  @override
  Future<void> save(ReferralInfo info) async => _stored = info;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ReferralInfo', () {
    test('generateCode produces 6-character uppercase alphanumeric string', () {
      final code = ReferralInfo.generateCode();
      expect(code.length, 6);
      expect(RegExp(r'^[A-Z2-9]{6}$').hasMatch(code), isTrue);
    });

    test('two generated codes are almost certainly unique', () {
      final a = ReferralInfo.generateCode();
      final b = ReferralInfo.generateCode();
      // Collision probability ≈ 1/32^6 ≈ negligible.
      expect(a, isNot(equals(b)));
    });

    test('hasActiveReward false when rewardEndsAt is null', () {
      const info = ReferralInfo(referralCode: 'ABC123');
      expect(info.hasActiveReward, isFalse);
    });

    test('hasActiveReward false when rewardEndsAt is in the past', () {
      final info = ReferralInfo(
        referralCode: 'ABC123',
        rewardEndsAt: DateTime(2020),
      );
      expect(info.hasActiveReward, isFalse);
    });

    test('hasActiveReward true when rewardEndsAt is in the future', () {
      final info = ReferralInfo(
        referralCode: 'ABC123',
        rewardEndsAt: DateTime(2099),
      );
      expect(info.hasActiveReward, isTrue);
    });

    test('eligibleForReward true at threshold with no active reward', () {
      final info = ReferralInfo(
        referralCode: 'ABC123',
        confirmedInviteCount: ReferralInfo.kRewardThreshold,
      );
      expect(info.eligibleForReward, isTrue);
    });

    test('eligibleForReward false when reward already active', () {
      final info = ReferralInfo(
        referralCode: 'ABC123',
        confirmedInviteCount: ReferralInfo.kRewardThreshold,
        rewardEndsAt: DateTime(2099),
      );
      expect(info.eligibleForReward, isFalse);
    });

    test('toMap / fromMap roundtrip', () {
      final info = ReferralInfo(
        id: 1,
        referralCode: 'XYZ789',
        inviteSentCount: 5,
        confirmedInviteCount: 2,
        rewardEndsAt: DateTime(2099, 6, 1),
      );
      final restored = ReferralInfo.fromMap(info.toMap());
      expect(restored.referralCode, 'XYZ789');
      expect(restored.inviteSentCount, 5);
      expect(restored.confirmedInviteCount, 2);
      expect(restored.rewardEndsAt, info.rewardEndsAt);
    });
  });

  group('ReferralService', () {
    late _MemReferralRepository repo;
    late ReferralService service;

    setUp(() {
      repo = _MemReferralRepository();
      service = ReferralService(repository: repo);
    });

    test('getOrCreate generates code on first call', () async {
      final info = await service.getOrCreate();
      expect(info.referralCode.length, 6);
    });

    test('getOrCreate returns same code on subsequent calls', () async {
      final a = await service.getOrCreate();
      final b = await service.getOrCreate();
      expect(a.referralCode, b.referralCode);
    });

    test('recordConfirmedInvite increments confirmedInviteCount', () async {
      await service.getOrCreate();
      final result = await service.recordConfirmedInvite();
      expect(result.confirmedInviteCount, 1);
    });

    test('reward applied after kRewardThreshold confirmed invites', () async {
      await service.getOrCreate();
      ReferralInfo? last;
      for (var i = 0; i < ReferralInfo.kRewardThreshold; i++) {
        last = await service.recordConfirmedInvite();
      }
      expect(last!.hasActiveReward, isTrue);
      expect(last.rewardEndsAt!.isAfter(DateTime.now()), isTrue);
    });

    test('reward duration is 14 days', () async {
      await service.getOrCreate();
      ReferralInfo? last;
      for (var i = 0; i < ReferralInfo.kRewardThreshold; i++) {
        last = await service.recordConfirmedInvite();
      }
      final daysLeft = last!.rewardEndsAt!.difference(DateTime.now()).inDays;
      expect(daysLeft, greaterThanOrEqualTo(13)); // allow 1 day tolerance
    });

    test('reward not applied below threshold', () async {
      await service.getOrCreate();
      final result = await service.recordConfirmedInvite();
      expect(result.hasActiveReward, isFalse);
    });
  });
}
