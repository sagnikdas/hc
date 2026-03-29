// ignore_for_file: avoid_relative_lib_imports
//
// Comprehensive tests for the Google-SSO onboarding flow introduced in the
// "Enforce Google SSO" feature:
//   • "Continue with Google" is the primary CTA (replaces "Begin Your Journey")
//   • "Skip for now" is a secondary link
//   • Cancelled picker (signInWithGoogle returns normally, no user) → stays on screen
//   • Sign-in error → inline error message, stays on screen
//   • Sign-in success → navigates to MainShell (onboarding marked as shown)
//   • Unmounted while sign-in is in-flight → no crash
//   • Buttons disabled while sign-in is loading
//   • Responsive rendering across phone sizes
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hanuman_chalisa/core/supabase_service.dart';
import 'package:hanuman_chalisa/core/theme.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/data/models/user_settings.dart';
import 'package:hanuman_chalisa/features/onboarding/onboarding_screen.dart';
import 'package:hanuman_chalisa/main.dart' show audioHandlerNotifier, isPlayScreenOpen;
import 'package:hanuman_chalisa/core/font_scale_notifier.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {
  @override
  String get id => 'sso-test-user';
}

final _testUser = _MockUser();

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

void _freshDb() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_onboarding_sso_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  AppRepository.instance.overrideSyncForTest(
    isSignedIn: () => false,
    syncCompletion: (_) async {},
  );
}

/// Sets all stubs required for MainShell child screens to settle without
/// error when the onboarding navigates to it.
void _stubMainShellDeps() {
  AppRepository.instance.overrideProgressForTest();
  AppRepository.instance.todayCountForTest = 0;
  AppRepository.instance
      .overrideSettingsForTest(const UserSettings());
  AppRepository.instance.overrideReferralCodeForTest('TEST');
  SupabaseService.fetchLeaderboardForTest =
      ({required bool weekly}) async => [];
  SupabaseService.fetchProfileForTest = () async => null;
  audioHandlerNotifier.value = null;
  isPlayScreenOpen.value = false;
  fontScaleNotifier.value = 1.0;
}

// ── Widget wrapper ─────────────────────────────────────────────────────────────

Widget _wrap({List<NavigatorObserver> observers = const []}) =>
    MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorObservers: observers,
      home: const OnboardingScreen(),
    );

// ── View helpers ───────────────────────────────────────────────────────────────

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late StreamController<AuthState> authCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    const MethodChannel('dexterous.com/flutter/local_notifications')
        .setMockMethodCallHandler((_) async => null);
  });

  setUp(() {
    _freshDb();
    authCtrl = StreamController<AuthState>.broadcast();
    SupabaseService.authChangesForTest = authCtrl.stream;
    SupabaseService.currentUserForTest = () => null;
    SupabaseService.signInForTest = null;
    SupabaseService.fetchProfileForTest = () async => null;
    SupabaseService.fetchLeaderboardForTest =
        ({required bool weekly}) async => [];
  });

  tearDown(() {
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
    AppRepository.instance.clearStatsOverrideForTest();
  });

  // ── 1. Initial render ──────────────────────────────────────────────────────

  group('initial render', () {
    testWidgets('primary CTA text is Continue with Google', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('secondary link text is Skip for now', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('Begin Your Journey is NOT present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Begin Your Journey'), findsNothing);
    });

    testWidgets('title Hanuman Chalisa is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Hanuman Chalisa'), findsOneWidget);
    });

    testWidgets('tagline Your daily companion for devotion is present',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Your daily companion for devotion'), findsOneWidget);
    });

    testWidgets('all three feature tiles are rendered', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Track Your Paath'), findsOneWidget);
      expect(find.text('Works Offline'), findsOneWidget);
      expect(find.text('Community Leaderboard'), findsOneWidget);
    });

    testWidgets('share invite button is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Invite devotees via WhatsApp'), findsOneWidget);
    });

    testWidgets('no error text visible initially', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.textContaining('failed'), findsNothing);
      expect(find.textContaining('error'), findsNothing);
    });

    testWidgets('no loading spinner visible initially', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ── 2. Loading state (during sign-in) ─────────────────────────────────────

  group('loading state during sign-in', () {
    testWidgets('spinner shown while sign-in is in-flight', (tester) async {
      _portraitView(tester);
      final completer = Completer<void>();
      SupabaseService.signInForTest = () => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump(); // one frame — async started

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing); // hidden by spinner

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Continue with Google text hidden while loading', (tester) async {
      _portraitView(tester);
      final completer = Completer<void>();
      SupabaseService.signInForTest = () => completer.future;
      SupabaseService.currentUserForTest = () => null;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('Continue with Google'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('double-tap does not fire two sign-in calls', (tester) async {
      _portraitView(tester);
      int callCount = 0;
      final completer = Completer<void>();
      SupabaseService.signInForTest = () async {
        callCount++;
        await completer.future;
      };
      SupabaseService.currentUserForTest = () => null;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      // Attempt second tap while loading
      await tester.tap(find.text('Skip for now'),
          warnIfMissed: false); // skip is also disabled
      await tester.pump();

      completer.complete();
      await tester.pumpAndSettle();

      expect(callCount, 1); // only one sign-in call
    });
  });

  // ── 3. Cancelled picker (returns normally, no user) ───────────────────────

  group('Google picker cancelled', () {
    setUp(() {
      SupabaseService.signInForTest = () async {}; // returns normally
      SupabaseService.currentUserForTest = () => null; // no user
    });

    testWidgets('remains on OnboardingScreen', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('spinner is gone after cancellation', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no error message shown after cancellation', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('failed'), findsNothing);
    });

    testWidgets('can retry sign-in after cancellation', (tester) async {
      _portraitView(tester);
      int callCount = 0;
      SupabaseService.signInForTest = () async {
        callCount++;
      };

      await tester.pumpWidget(_wrap());
      await tester.pump();

      // First attempt (cancelled)
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Second attempt
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(callCount, 2);
    });
  });

  // ── 4. Sign-in error ──────────────────────────────────────────────────────

  group('sign-in error handling', () {
    testWidgets('generic error shows Sign-in failed message', (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('auth/network-error');

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sign-in failed'), findsOneWidget);
    });

    testWidgets('StateError message is shown verbatim (config errors)',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw StateError('kGoogleWebClientId not configured');

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('kGoogleWebClientId not configured'),
          findsOneWidget);
    });

    testWidgets('still on OnboardingScreen after error', (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('server error');

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('no spinner after error (loading state reset)', (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('error');

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error from catch block never falls through to _proceed',
        (tester) async {
      // This tests the Bug-1 fix: return is now outside if(mounted).
      // If _proceed() was called after an error, onboarding would be marked shown
      // and we would navigate away. Verify we stay on-screen.
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('forced error');

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Still on onboarding
      expect(find.text('Continue with Google'), findsOneWidget);
      // onboarding NOT marked shown → can verify by checking AppRepository
      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isFalse);
    });

    testWidgets('no crash when unmounted before error fires (Bug-1 regression)',
        (tester) async {
      final completer = Completer<void>();
      SupabaseService.signInForTest = () async {
        await completer.future;
        throw Exception('late error');
      };

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // Unmount
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      // Fire error after unmount
      completer.completeError(Exception('late error'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ── 5. Successful sign-in ─────────────────────────────────────────────────

  group('successful Google sign-in', () {
    setUp(() {
      SupabaseService.signInForTest = () async {};
      SupabaseService.currentUserForTest = () => _testUser;
      _stubMainShellDeps();
    });

    testWidgets('navigates away from OnboardingScreen', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // OnboardingScreen is no longer in the tree
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Skip for now'), findsNothing);
    });

    testWidgets('onboarding is marked as shown after successful sign-in',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isTrue);
    });
  });

  // ── 6. Skip for now ───────────────────────────────────────────────────────

  group('Skip for now', () {
    setUp(() {
      _stubMainShellDeps();
    });

    testWidgets('tapping skip navigates away from OnboardingScreen',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Skip for now'), findsNothing);
    });

    testWidgets('skip marks onboarding as shown', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isTrue);
    });

    testWidgets('skip does NOT call signInWithGoogle', (tester) async {
      _portraitView(tester);
      bool signInCalled = false;
      SupabaseService.signInForTest = () async {
        signInCalled = true;
      };

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(signInCalled, isFalse);
    });

    testWidgets('double-tap skip does not cause double navigation',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      // Second tap: button should be disabled (_starting = true)
      await tester.tap(find.text('Skip for now'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ── 7. Sign-in success vs cancelled (Bug-2 boundary) ─────────────────────

  group('Bug-2 regression: cancelled picker vs successful sign-in', () {
    testWidgets('currentUser==null after sign-in → stays on screen, NOT proceeds',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = () async {};
      SupabaseService.currentUserForTest = () => null; // picker cancelled

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Onboarding NOT marked shown (we did not proceed)
      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isFalse);
    });

    testWidgets('currentUser!=null after sign-in → proceeds to MainShell',
        (tester) async {
      _portraitView(tester);
      _stubMainShellDeps();
      SupabaseService.signInForTest = () async {};
      SupabaseService.currentUserForTest = () => _testUser;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Onboarding IS marked shown (we proceeded)
      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isTrue);
    });
  });

  // ── 8. Responsiveness ─────────────────────────────────────────────────────

  group('responsiveness — no overflow', () {
    for (final size in const [
      Size(320, 568),
      Size(375, 667),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ]) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()} — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap());
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
      });
    }
  });
}
