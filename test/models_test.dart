import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/data/models/play_session.dart';
import 'package:hanuman_chalisa/data/models/daily_stat.dart';
import 'package:hanuman_chalisa/data/models/user_settings.dart';
import 'package:hanuman_chalisa/data/models/recording.dart';
import 'package:hanuman_chalisa/data/models/entitlement.dart';

void main() {
  group('PlaySession', () {
    test('toMap / fromMap roundtrip', () {
      final session = PlaySession(
        id: 1,
        startedAt: DateTime(2024, 1, 15, 8, 0),
        completedAt: DateTime(2024, 1, 15, 8, 15),
        durationSeconds: 900,
        completed: true,
      );
      final restored = PlaySession.fromMap(session.toMap());
      expect(restored.id, session.id);
      expect(restored.durationSeconds, session.durationSeconds);
      expect(restored.completed, session.completed);
    });

    test('completed false when < 95% played', () {
      final session = PlaySession(
        startedAt: DateTime.now(),
        durationSeconds: 500,
        completed: false,
      );
      expect(session.completed, isFalse);
    });
  });

  group('DailyStat', () {
    test('toMap / fromMap roundtrip', () {
      final stat = DailyStat(
        id: 1,
        date: '2024-01-15',
        completionCount: 3,
        totalPlaySeconds: 2700,
      );
      final restored = DailyStat.fromMap(stat.toMap());
      expect(restored.date, stat.date);
      expect(restored.completionCount, stat.completionCount);
    });
  });

  group('UserSettings', () {
    test('defaults are correct', () {
      const settings = UserSettings();
      expect(settings.themeMode, 'system');
      expect(settings.reminderEnabled, isFalse);
      expect(settings.selectedVoice, 'default');
    });

    test('toMap / fromMap roundtrip', () {
      const settings = UserSettings(
        id: 1,
        themeMode: 'dark',
        reminderEnabled: true,
        reminderTime: '06:00',
        selectedVoice: 'premium_1',
      );
      final restored = UserSettings.fromMap(settings.toMap());
      expect(restored.themeMode, 'dark');
      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderTime, '06:00');
    });
  });

  group('Recording', () {
    test('toMap / fromMap roundtrip', () {
      final rec = Recording(
        id: 1,
        filePath: '/data/recordings/rec1.m4a',
        recordedAt: DateTime(2024, 1, 15),
        durationSeconds: 300,
        label: 'Morning',
      );
      final restored = Recording.fromMap(rec.toMap());
      expect(restored.filePath, rec.filePath);
      expect(restored.label, rec.label);
    });
  });

  group('Entitlement', () {
    test('free constant is not premium and not active', () {
      expect(Entitlement.free.isPremium, isFalse);
      expect(Entitlement.free.isActive, isFalse);
      expect(Entitlement.free.planType, PlanType.free);
    });

    test('lifetime entitlement is active with no expiry', () {
      const e = Entitlement(planType: PlanType.lifetime, isPremium: true);
      expect(e.isActive, isTrue);
      expect(e.expiresAt, isNull);
    });

    test('expired subscription is not active', () {
      final e = Entitlement(
        planType: PlanType.monthly,
        isPremium: true,
        expiresAt: DateTime(2020, 1, 1), // past
      );
      expect(e.isActive, isFalse);
    });

    test('active subscription is active', () {
      final e = Entitlement(
        planType: PlanType.yearly,
        isPremium: true,
        expiresAt: DateTime(2099, 12, 31),
      );
      expect(e.isActive, isTrue);
    });

    test('isOnTrial true when trialEndsAt is in the future', () {
      final e = Entitlement(
        planType: PlanType.monthly,
        isPremium: true,
        trialEndsAt: DateTime(2099, 12, 31),
      );
      expect(e.isOnTrial, isTrue);
    });

    test('toMap / fromMap roundtrip', () {
      final e = Entitlement(
        id: 1,
        planType: PlanType.yearly,
        isPremium: true,
        trialEndsAt: DateTime(2099, 6, 1),
        expiresAt: DateTime(2099, 12, 31),
      );
      final restored = Entitlement.fromMap(e.toMap());
      expect(restored.planType, PlanType.yearly);
      expect(restored.isPremium, isTrue);
      expect(restored.trialEndsAt, e.trialEndsAt);
      expect(restored.expiresAt, e.expiresAt);
    });
  });
}
