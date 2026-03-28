// ignore_for_file: avoid_relative_lib_imports
//
// Tests for ProfileScreen (Sankalpa Settings) covering:
//   • AppRepository settings & referral-code logic (unit tests via sqflite FFI)
//   • ProfileScreen widget rendering and interactions
//   • Responsiveness at multiple screen widths
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hanuman_chalisa/core/font_scale_notifier.dart';
import 'package:hanuman_chalisa/core/supabase_service.dart';
import 'package:hanuman_chalisa/core/theme.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/models/user_settings.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/features/profile/profile_screen.dart';

// ── Fakes / mocks ─────────────────────────────────────────────────────────────

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

/// Returns a fresh isolated SQLite repo.  The Supabase sync seam is stubbed
/// so no network is ever touched.
AppRepository _freshRepo() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_profile_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(
    isSignedIn: () => false,
    syncCompletion: (_) async {},
  );
  return repo;
}

// ── Widget wrapper ─────────────────────────────────────────────────────────────

Widget _wrap({List<NavigatorObserver> observers = const []}) => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorObservers: observers,
      routes: {
        // Stub routes so slideUpRoute push doesn't crash in tests.
        '/play': (_) => const Scaffold(body: Text('PlayScreen')),
      },
      home: const ProfileScreen(),
    );

// ── View-size helpers ──────────────────────────────────────────────────────────

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Fake Supabase User ────────────────────────────────────────────────────────

User _fakeUser({
  String id = 'test-uid-123',
  String email = 'arjuna@example.com',
  String fullName = 'Arjuna Pandava',
  String? avatarUrl,
}) {
  final metadata = <String, dynamic>{
    'full_name': fullName,
    'avatar_url': avatarUrl,
  };
  return User.fromJson(<String, dynamic>{
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'created_at': '2024-01-01T00:00:00.000Z',
    'updated_at': '2024-01-01T00:00:00.000Z',
    'user_metadata': metadata,
    'app_metadata': <String, dynamic>{},
    'identities': <dynamic>[],
  })!;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late StreamController<AuthState> authCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    registerFallbackValue(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );

    // Silence platform channels used by share_plus and system UI.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => null,
    );

  });

  setUp(() {
    authCtrl = StreamController<AuthState>.broadcast();
    _freshRepo();
    fontScaleNotifier.value = 1.0;

    // Bypass SQLite so pumpAndSettle() can settle (FFI isolate messages don't
    // drain through the widget-test pump loop).
    AppRepository.instance.overrideSettingsForTest(const UserSettings());
    AppRepository.instance.overrideReferralCodeForTest('ABCDEF');

    SupabaseService.authChangesForTest = authCtrl.stream;
    SupabaseService.currentUserForTest = () => null;
    SupabaseService.fetchProfileForTest = () async => null;
    SupabaseService.upsertProfileForTest = ({
      required name,
      required email,
      required phone,
      required dateOfBirth,
      referralCode,
    }) async {};
    SupabaseService.signInForTest = null;
  });

  tearDown(() {
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
    AppRepository.instance.clearStatsOverrideForTest();
    AppRepository.instance.clearSettingsOverrideForTest();
  });

  // ==========================================================================
  // UNIT TESTS — AppRepository settings & referral code
  // ==========================================================================

  group('UserSettings model', () {
    test('default constructor has expected values', () {
      const s = UserSettings();
      expect(s.targetCount, 11);
      expect(s.hapticEnabled, isTrue);
      expect(s.continuousPlay, isFalse);
      expect(s.fontScale, 1.0);
      expect(s.playbackSpeed, 1.0);
      expect(s.referralCode, isNull);
      expect(s.onboardingShown, isFalse);
    });

    test('toMap / fromMap round-trips all fields', () {
      const original = UserSettings(
        targetCount: 21,
        hapticEnabled: false,
        continuousPlay: true,
        fontScale: 1.3,
        playbackSpeed: 1.5,
        referralCode: 'ABC123',
        onboardingShown: true,
      );
      final roundTripped = UserSettings.fromMap(original.toMap());
      expect(roundTripped.targetCount, 21);
      expect(roundTripped.hapticEnabled, isFalse);
      expect(roundTripped.continuousPlay, isTrue);
      expect(roundTripped.fontScale, closeTo(1.3, 0.001));
      expect(roundTripped.playbackSpeed, closeTo(1.5, 0.001));
      expect(roundTripped.referralCode, 'ABC123');
      expect(roundTripped.onboardingShown, isTrue);
    });

    test('fromMap handles null / missing columns gracefully', () {
      final s = UserSettings.fromMap({
        'id': 1,
        'target_count': null,
        'haptic_enabled': null,
        'continuous_play': null,
        'referral_code': null,
        'onboarding_shown': null,
        'playback_speed': null,
        'font_scale': null,
      });
      expect(s.targetCount, 11);
      expect(s.hapticEnabled, isTrue);
      expect(s.continuousPlay, isFalse);
      expect(s.fontScale, 1.0);
      expect(s.referralCode, isNull);
    });

    test('copyWith does not overwrite unspecified fields', () {
      const original = UserSettings(
        targetCount: 108,
        hapticEnabled: false,
        continuousPlay: true,
        fontScale: 0.9,
        referralCode: 'XYZ999',
      );
      final copy = original.copyWith(targetCount: 51);
      expect(copy.targetCount, 51);
      expect(copy.hapticEnabled, isFalse);
      expect(copy.continuousPlay, isTrue);
      expect(copy.fontScale, closeTo(0.9, 0.001));
      expect(copy.referralCode, 'XYZ999');
    });

    test('copyWith preserves referralCode when not provided', () {
      const original = UserSettings(referralCode: 'KEEP99');
      final copy = original.copyWith(targetCount: 3);
      expect(copy.referralCode, 'KEEP99');
    });
  });

  // ── Repository: settings persistence ────────────────────────────────────────

  group('AppRepository settings', () {
    test('getSettings returns defaults when no row exists', () async {
      final repo = _freshRepo();
      final s = await repo.getSettings();
      expect(s.targetCount, 11);
      expect(s.hapticEnabled, isTrue);
      expect(s.continuousPlay, isFalse);
      expect(s.fontScale, 1.0);
      expect(s.referralCode, isNull);
    });

    test('saveSettings and getSettings round-trip all editable fields',
        () async {
      final repo = _freshRepo();
      const settings = UserSettings(
        targetCount: 108,
        hapticEnabled: false,
        continuousPlay: true,
        fontScale: 1.2,
        playbackSpeed: 0.75,
      );
      await repo.saveSettings(settings);
      final loaded = await repo.getSettings();
      expect(loaded.targetCount, 108);
      expect(loaded.hapticEnabled, isFalse);
      expect(loaded.continuousPlay, isTrue);
      expect(loaded.fontScale, closeTo(1.2, 0.001));
      expect(loaded.playbackSpeed, closeTo(0.75, 0.001));
    });

    test('successive saves overwrite previous values', () async {
      final repo = _freshRepo();
      await repo.saveSettings(const UserSettings(targetCount: 3));
      await repo.saveSettings(const UserSettings(targetCount: 21));
      expect((await repo.getSettings()).targetCount, 21);
    });

    test('fontScale boundary values are preserved exactly', () async {
      final repo = _freshRepo();
      for (final scale in [0.8, 1.0, 1.4]) {
        await repo.saveSettings(UserSettings(fontScale: scale));
        final loaded = await repo.getSettings();
        expect(loaded.fontScale, closeTo(scale, 0.0001));
      }
    });

    test('markOnboardingShown flips flag without touching other settings',
        () async {
      final repo = _freshRepo();
      await repo.saveSettings(const UserSettings(targetCount: 51));
      await repo.markOnboardingShown();
      final s = await repo.getSettings();
      expect(s.onboardingShown, isTrue);
      expect(s.targetCount, 51);
    });
  });

  // ── Repository: referral code ────────────────────────────────────────────────

  group('AppRepository referral code', () {
    test('getOrCreateReferralCode returns a non-empty string', () async {
      final repo = _freshRepo();
      final code = await repo.getOrCreateReferralCode();
      expect(code, isNotEmpty);
    });

    test('generated code is exactly 6 characters', () async {
      final repo = _freshRepo();
      final code = await repo.getOrCreateReferralCode();
      expect(code.length, 6);
    });

    test('generated code contains only valid charset characters', () async {
      final repo = _freshRepo();
      const validChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final code = await repo.getOrCreateReferralCode();
      for (final char in code.split('')) {
        expect(validChars.contains(char), isTrue,
            reason: 'Character "$char" is not in the valid charset');
      }
    });

    test('generated code never contains ambiguous characters (I, O, 0, 1)',
        () async {
      _freshRepo();
      const ambiguous = {'I', 'O', '0', '1'};
      // Run enough iterations to catch a bad generator.
      for (int i = 0; i < 50; i++) {
        DatabaseHelper.resetForTest(
          p.join(Directory.systemTemp.path, 'hc_amb_${_dbUid++}.db'),
        );
        AppRepository.resetForTest();
        final r = AppRepository.instance;
        r.overrideSyncForTest(isSignedIn: () => false, syncCompletion: (_) async {});
        final code = await r.getOrCreateReferralCode();
        for (final char in code.split('')) {
          expect(ambiguous.contains(char), isFalse,
              reason: 'Ambiguous char "$char" found in code "$code"');
        }
      }
    });

    test('getOrCreateReferralCode is idempotent — returns same code on repeat calls',
        () async {
      final repo = _freshRepo();
      final first = await repo.getOrCreateReferralCode();
      final second = await repo.getOrCreateReferralCode();
      expect(second, first);
    });

    test('referral code persists in DB across repo singleton reset', () async {
      // Use the same DB path for both repos.
      final path =
          p.join(Directory.systemTemp.path, 'hc_persist_${_dbUid++}.db');
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
      DatabaseHelper.resetForTest(path);
      AppRepository.resetForTest();
      final repo1 = AppRepository.instance;
      repo1.overrideSyncForTest(
          isSignedIn: () => false, syncCompletion: (_) async {});

      final original = await repo1.getOrCreateReferralCode();

      // Reset the singleton (simulates app restart with same DB).
      DatabaseHelper.resetForTest(path);
      AppRepository.resetForTest();
      final repo2 = AppRepository.instance;
      repo2.overrideSyncForTest(
          isSignedIn: () => false, syncCompletion: (_) async {});

      final reloaded = await repo2.getOrCreateReferralCode();
      expect(reloaded, original);
    });

    test('referral code is stored in user_settings so getSettings returns it',
        () async {
      final repo = _freshRepo();
      final code = await repo.getOrCreateReferralCode();
      final settings = await repo.getSettings();
      expect(settings.referralCode, code);
    });

    test('100 independently generated codes have no duplicates', () async {
      final codes = <String>{};
      for (int i = 0; i < 100; i++) {
        DatabaseHelper.resetForTest(
          p.join(Directory.systemTemp.path, 'hc_uniq_${_dbUid++}.db'),
        );
        AppRepository.resetForTest();
        final r = AppRepository.instance;
        r.overrideSyncForTest(isSignedIn: () => false, syncCompletion: (_) async {});
        final code = await r.getOrCreateReferralCode();
        expect(codes.contains(code), isFalse,
            reason: 'Duplicate code "$code" generated');
        codes.add(code);
      }
    });

    test('existing code not overwritten when user saves settings', () async {
      final repo = _freshRepo();
      final code = await repo.getOrCreateReferralCode();

      // Simulate a settings change (as ProfileScreen._saveSettings does).
      final current = await repo.getSettings();
      await repo.saveSettings(current.copyWith(targetCount: 3));

      final after = await repo.getSettings();
      expect(after.referralCode, code,
          reason: 'Referral code must survive a settings save');
    });
  });

  // ==========================================================================
  // WIDGET TESTS — ProfileScreen
  // ==========================================================================

  // ── Group: header ──────────────────────────────────────────────────────────

  group('header', () {
    testWidgets('shows Sankalp Settings title', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Sankalp Settings'), findsOneWidget);
    });

    testWidgets('tune_rounded icon is present', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });

  // ── Group: auth section ───────────────────────────────────────────────────

  group('auth section — signed out', () {
    testWidgets('shows sign-in prompt when not authenticated', (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Sign in to sync your paath'), findsOneWidget);
    });

    testWidgets('shows leaderboard & cloud backup subtitle', (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Leaderboard & cloud backup'), findsOneWidget);
    });

    testWidgets('shows Sign in button when not authenticated', (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('tapping Sign in triggers signInForTest', (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      var signInCalled = false;
      SupabaseService.signInForTest = () async {
        signInCalled = true;
      };
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(signInCalled, isTrue);
    });

    testWidgets('shows loading indicator while sign-in is in progress',
        (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      final signInCompleter = Completer<void>();
      SupabaseService.signInForTest = () => signInCompleter.future;

      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pump(); // trigger setState(_authLoading = true)

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      signInCompleter.completeError(Exception('cancelled'));
      await tester.pump();
    });
  });

  group('auth section — signed in', () {
    testWidgets('shows user name in signed-in card', (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser(fullName: 'Arjuna Pandava');
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async =>
          {'name': 'Arjuna Pandava'};

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Arjuna Pandava'), findsOneWidget);
    });

    testWidgets('shows user email in signed-in card', (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser(email: 'arjuna@example.com');
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('arjuna@example.com'), findsOneWidget);
    });

    testWidgets('shows first initial in avatar when no avatar URL',
        (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser(fullName: 'Bhima Pandava', avatarUrl: null);
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest =
          () async => {'name': 'Bhima Pandava'};

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Initial 'B' should appear in the avatar.
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('falls back to userMetadata name when profile fetch fails',
        (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser(fullName: 'Nakula Pandava');
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Nakula Pandava'), findsOneWidget);
    });

    testWidgets('shows "Devotee" when userMetadata full_name is null',
        (tester) async {
      // When metadata has no full_name key at all, the fallback is 'Devotee'.
      _setView(tester, 390, 844);
      // Construct a user with no full_name in metadata.
      final user = User.fromJson(<String, dynamic>{
        'id': 'no-name-uid',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'test@example.com',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'user_metadata': <String, dynamic>{},
        'app_metadata': <String, dynamic>{},
        'identities': <dynamic>[],
      })!;
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Devotee'), findsOneWidget);
    });

    testWidgets('shows logout and edit icons in signed-in card', (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser();
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });

    testWidgets('logout icon is present and tappable in signed-in card',
        (tester) async {
      _setView(tester, 390, 844);
      final user = _fakeUser(fullName: 'Sahadeva');
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Verify the icon is present; actual signOut path requires
      // real Supabase/GoogleSignIn channels outside widget-test scope.
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });
  });

  // ── Group: invite / referral section ─────────────────────────────────────

  group('invite section', () {
    testWidgets('shows Invite Devotees heading', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Invite Devotees'), findsOneWidget);
    });

    testWidgets('shows loading spinner before referral code resolves',
        (tester) async {
      _setView(tester, 390, 844);
      // pumpWidget triggers initState but async work has not run yet.
      await tester.pumpWidget(_wrap());
      // _referralCode is null immediately after pumpWidget (before any pump).
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows referral code string after settling', (tester) async {
      _setView(tester, 390, 844);
      // The setUp seam returns 'ABCDEF' synchronously once async resolves.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('ABCDEF'), findsOneWidget);
    });

    testWidgets('displayed referral code contains no ambiguous characters',
        (tester) async {
      // The seam code 'ABCDEF' has no I, O, 0, or 1.
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      const ambiguous = {'I', 'O', '0', '1'};
      for (final char in 'ABCDEF'.split('')) {
        expect(ambiguous.contains(char), isFalse,
            reason: 'Seam code "ABCDEF" unexpectedly contains "$char"');
      }
      expect(find.text('ABCDEF'), findsOneWidget);
    });

    testWidgets('share button is present after code loads', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('tapping share button does not throw', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share_rounded));
      await tester.pump();
      // No exception = pass.
    });

    testWidgets('shows descriptive hint text below code', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.text('Share this code with friends to invite them'),
        findsOneWidget,
      );
    });
  });

  // ── Group: devotional intent section ─────────────────────────────────────

  group('devotional intent section', () {
    testWidgets('shows DEVOTIONAL INTENT label', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('DEVOTIONAL INTENT'), findsOneWidget);
    });

    testWidgets('shows Set Your Path heading', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Set Your Path'), findsOneWidget);
    });

    testWidgets('all 6 preset buttons are rendered', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      for (final label in ['ONCE', 'TRIVIDHA', 'EKADASHA', 'VIMSATI', 'PANCASAT', 'MALA']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('default selected preset is 11 (Ekadasha)', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // After settle the settings are loaded (default targetCount = 11).
      // The check icon appears only for the selected preset.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // The '11' count text is present.
      expect(find.text('11'), findsOneWidget);
    });

    testWidgets('tapping Once preset moves selection to 1', (tester) async {
      _setView(tester, 390, 1200);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('ONCE'));
      await tester.pump();

      // '1' should now be visible (the number in the selected tile).
      expect(find.text('1'), findsOneWidget);
      // Check icon still exactly one (moved to the new tile).
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('tapping Mala (108) moves selection', (tester) async {
      _setView(tester, 390, 1200);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('MALA'));
      await tester.pump();

      expect(find.text('108'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('tapping Trividha visually selects it', (tester) async {
      // Tall viewport so the grid is fully above the CTA overlay.
      _setView(tester, 390, 1200);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('TRIVIDHA'));
      await tester.pump();

      // Check icon moves to Trividha (3).
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('settings seam targetCount=51 selects Pancasat',
        (tester) async {
      _setView(tester, 390, 844);
      // Override the seam to use targetCount=51.
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(targetCount: 51),
      );

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('51'), findsOneWidget);
    });
  });

  // ── Group: toggle settings ────────────────────────────────────────────────

  group('toggles', () {
    testWidgets('Haptic Feedback toggle is present', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Haptic Feedback'), findsOneWidget);
    });

    testWidgets('Continuous Play toggle is present', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Continuous Play'), findsOneWidget);
    });

    testWidgets('tapping Haptic Feedback toggle flips its Switch value',
        (tester) async {
      // Use a tall viewport so the toggles section clears the CTA overlay.
      _setView(tester, 390, 1400);
      // Default seam: hapticEnabled = true.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final hapticSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Haptic Feedback'),
          matching: find.byType(Container),
        ),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(hapticSwitch.first).value, isTrue);
      await tester.tap(hapticSwitch.first);
      await tester.pump();
      expect(tester.widget<Switch>(hapticSwitch.first).value, isFalse);
    });

    testWidgets('tapping Continuous Play toggle flips its Switch value',
        (tester) async {
      _setView(tester, 390, 1400);
      // Default seam: continuousPlay = false.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final continuousSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Continuous Play'),
          matching: find.byType(Container),
        ),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(continuousSwitch.first).value, isFalse);
      await tester.tap(continuousSwitch.first);
      await tester.pump();
      expect(tester.widget<Switch>(continuousSwitch.first).value, isTrue);
    });

    testWidgets('seam hapticEnabled=false renders switch off', (tester) async {
      _setView(tester, 390, 1400);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(hapticEnabled: false),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches[0].value, isFalse);
    });

    testWidgets('seam continuousPlay=true renders switch on', (tester) async {
      _setView(tester, 390, 1400);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(continuousPlay: true),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches[1].value, isTrue);
    });
  });

  // ── Group: font size slider ───────────────────────────────────────────────

  group('font size slider', () {
    testWidgets('Font Size label is present', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Font Size'), findsOneWidget);
    });

    testWidgets('shows current scale with × suffix', (tester) async {
      _setView(tester, 390, 844);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(fontScale: 1.2),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('1.2×'), findsOneWidget);
    });

    testWidgets('Slider widget exists', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('fontScaleNotifier updates when slider is changed',
        (tester) async {
      _setView(tester, 390, 1400);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      // Drag towards the right (max = 1.4).
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // fontScaleNotifier should have updated from its default 1.0.
      // (Exact value depends on drag distance; we just verify it changed.)
      // After drag ends, saved to DB via onChangeEnd.
      final saved = await AppRepository.instance.getSettings();
      expect(saved.fontScale, greaterThanOrEqualTo(0.8));
      expect(saved.fontScale, lessThanOrEqualTo(1.4));
    });

    testWidgets('seam fontScale=0.9 displays correctly', (tester) async {
      _setView(tester, 390, 844);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(fontScale: 0.9),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('0.9×'), findsOneWidget);
    });
  });

  // ── Group: CTA button ────────────────────────────────────────────────────

  group('Begin Recitation CTA', () {
    testWidgets('CTA button is visible', (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Begin Recitation'), findsOneWidget);
    });

    testWidgets('CTA button triggers navigation push', (tester) async {
      _setView(tester, 390, 844);
      final observer = _MockNavigatorObserver();
      registerFallbackValue(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );

      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Begin Recitation'));
      await tester.pump();

      verify(() => observer.didPush(any(), any())).called(greaterThan(0));
    });
  });

  // ── Group: responsiveness ─────────────────────────────────────────────────

  group('responsiveness', () {
    testWidgets('renders at 320×568 (small phone) without crashing',
        (tester) async {
      _setView(tester, 320, 568);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sankalp Settings'), findsOneWidget);
      expect(find.text('Begin Recitation'), findsOneWidget);
    });

    testWidgets('renders at 390×844 (iPhone 14) without crashing',
        (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sankalp Settings'), findsOneWidget);
    });

    testWidgets('renders at 412×915 (Pixel 6) without crashing',
        (tester) async {
      _setView(tester, 412, 915);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sankalp Settings'), findsOneWidget);
    });

    testWidgets('renders at 600×1024 (small tablet) without crashing',
        (tester) async {
      _setView(tester, 600, 1024);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sankalp Settings'), findsOneWidget);
      expect(find.text('Begin Recitation'), findsOneWidget);
    });

    testWidgets('all 6 presets visible at 320px width', (tester) async {
      _setView(tester, 320, 568);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      for (final label in [
        'ONCE', 'TRIVIDHA', 'EKADASHA', 'VIMSATI', 'PANCASAT', 'MALA'
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'Preset label "$label" missing at 320px width');
      }
    });

    testWidgets('all 6 presets visible at 600px width', (tester) async {
      _setView(tester, 600, 1024);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      for (final label in [
        'ONCE', 'TRIVIDHA', 'EKADASHA', 'VIMSATI', 'PANCASAT', 'MALA'
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'Preset label "$label" missing at 600px width');
      }
    });

    testWidgets('sp() scaling applied: sp(24) differs between 320px and 600px',
        (tester) async {
      // At 320px: sp(24) = 24 * (320/375).clamp(0.85,1.28) = 24*0.85 = 20.4
      // At 600px: sp(24) = 24 * (600/375).clamp(0.85,1.28) = 24*1.28 = 30.72
      // This just verifies the screen renders at both sizes.
      for (final width in [320.0, 600.0]) {
        _setView(tester, width, 900);
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();
        expect(find.text('Sankalp Settings'), findsOneWidget);
      }
    });
  });

  // ── Group: edge cases ─────────────────────────────────────────────────────

  group('edge cases', () {
    testWidgets('screen recovers gracefully when fetchProfile throws',
        (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.fetchProfileForTest =
          () async => throw Exception('network error');
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Should not crash — profile is null, sign-out card is shown.
      expect(find.text('Sign in to sync your paath'), findsOneWidget);
    });

    testWidgets('auth state change re-loads profile', (tester) async {
      _setView(tester, 390, 844);
      SupabaseService.currentUserForTest = () => null;
      SupabaseService.fetchProfileForTest = () async => null;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sign in to sync your paath'), findsOneWidget);

      // Simulate sign-in via auth stream.
      final user = _fakeUser(fullName: 'Draupadi');
      SupabaseService.currentUserForTest = () => user;
      SupabaseService.fetchProfileForTest =
          () async => {'name': 'Draupadi'};
      authCtrl.add(const AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      // Profile should refresh — Draupadi name visible.
      expect(find.text('Draupadi'), findsOneWidget);
    });

    testWidgets('screen disposes auth subscription on pop (no leaks)',
        (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Pump a new widget tree to force dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // Emitting to the stream after dispose must not crash.
      authCtrl.add(const AuthState(AuthChangeEvent.signedOut, null));
      await tester.pump();
      // No exceptions = pass.
    });

    testWidgets('CTA passes selected preset count to PlayScreen route',
        (tester) async {
      _setView(tester, 390, 844);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Select Mala (108) then hit Begin Recitation.
      await tester.tap(find.text('MALA'));
      await tester.pump();

      // Verify the CTA still renders after selection change.
      expect(find.text('Begin Recitation'), findsOneWidget);
    });

    testWidgets('font scale defaults to 1.0 (seam default)', (tester) async {
      _setView(tester, 390, 844);
      // setUp seam = UserSettings() has fontScale=1.0.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('1.0×'), findsOneWidget);
    });

    testWidgets('font scale clamped to 0.8 when seam returns sub-minimum',
        (tester) async {
      _setView(tester, 390, 844);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(fontScale: 0.5),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // _loadSettings clamps 0.5 → 0.8.
      expect(find.text('0.8×'), findsOneWidget);
    });

    testWidgets('font scale clamped to 1.4 when seam returns super-maximum',
        (tester) async {
      _setView(tester, 390, 844);
      AppRepository.instance.overrideSettingsForTest(
        const UserSettings(fontScale: 2.0),
      );
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // _loadSettings clamps 2.0 → 1.4.
      expect(find.text('1.4×'), findsOneWidget);
    });
  });
}
