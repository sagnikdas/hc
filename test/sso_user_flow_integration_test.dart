// ignore_for_file: avoid_relative_lib_imports
//
// Integration tests that exercise the full SSO user-flow across screens:
//
//   Flow A: Skip onboarding → progress shows guest view → leaderboard shows gate
//   Flow B: Sign-in from onboarding → progress shows full journey
//   Flow C: Guest signs in via progress upsell → full journey unlocked
//   Flow D: Guest signs in via leaderboard gate → leaderboard auto-loads
//   Flow E: Signed-in user signs out → all screens revert to guest state
//   Flow F: Rapid mount/unmount of screens with various auth states
//
// All async I/O is bypassed via the repository / Supabase test-seam pattern.
// MainShell is used as the root widget so tab navigation can be exercised.
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
import 'package:hanuman_chalisa/core/main_shell.dart';
import 'package:hanuman_chalisa/core/supabase_service.dart';
import 'package:hanuman_chalisa/core/theme.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/models/play_session.dart';
import 'package:hanuman_chalisa/data/models/user_settings.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/features/leaderboard/leaderboard_screen.dart';
import 'package:hanuman_chalisa/features/onboarding/onboarding_screen.dart';
import 'package:hanuman_chalisa/features/progress/progress_screen.dart';
import 'package:hanuman_chalisa/main.dart' show audioHandlerNotifier, isPlayScreenOpen;

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {
  @override
  String get id => 'integration-test-user';
}

final _signedInUser = _MockUser();

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

void _freshDb() {
  final path = p.join(Directory.systemTemp.path, 'hc_sso_int_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
}

/// Applies the minimal overrides required for all four MainShell child screens
/// to settle without network/DB access.
void _stubAllScreens({bool signedIn = false}) {
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(
    isSignedIn: () => signedIn,
    syncCompletion: (_) async {},
  );
  repo.todayCountForTest = 0;
  repo.overrideProgressForTest();
  repo.overrideSettingsForTest(const UserSettings());
  repo.overrideReferralCodeForTest('TEST');
  SupabaseService.fetchLeaderboardForTest =
      ({required bool weekly}) async => [];
  SupabaseService.fetchProfileForTest = () async => null;
  audioHandlerNotifier.value = null;
  isPlayScreenOpen.value = false;
  fontScaleNotifier.value = 1.0;
}

// ── Widget wrappers ────────────────────────────────────────────────────────────

Widget _shell() => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );

Widget _onboarding() => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const OnboardingScreen(),
    );

// ── View helper ────────────────────────────────────────────────────────────────

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Overflow suppression ───────────────────────────────────────────────────────

void Function(FlutterErrorDetails)? _origErr;

void _suppressOverflow() {
  _origErr = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('overflowed') || s.contains('RenderFlex')) return;
    _origErr?.call(d);
  };
}

void _restoreOverflow() => FlutterError.onError = _origErr;

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
    _suppressOverflow();
  });

  tearDownAll(_restoreOverflow);

  setUp(() {
    _freshDb();
    authCtrl = StreamController<AuthState>.broadcast();
    SupabaseService.authChangesForTest = authCtrl.stream;
    SupabaseService.currentUserForTest = () => null;
    SupabaseService.signInForTest = null;
    _stubAllScreens(signedIn: false);
  });

  tearDown(() {
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
    AppRepository.instance.clearStatsOverrideForTest();
  });

  // ── Flow A: Skip onboarding → guest state in all screens ──────────────────

  group('Flow A: skip onboarding → guest state persists across screens', () {
    testWidgets('after skip, progress screen shows upsell card (guest view)',
        (tester) async {
      _portraitView(tester);
      // Progress screen in isolation, guest user
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('after skip, leaderboard screen shows sign-in gate',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const LeaderboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('MainShell starts on tab 0 (Home), no crash for guest',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── Flow B: Sign-in from MainShell → full journey in progress screen ───────

  group('Flow B: auth stream sign-in → progress unlocks full view', () {
    testWidgets('progress upsell disappears after signedIn auth event',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      // Navigate to Progress tab (tab index 1)
      await tester.tap(find.byIcon(Icons.auto_graph_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey', skipOffstage: false),
          findsOneWidget);

      // Sign in
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey', skipOffstage: false),
          findsNothing);
      expect(find.byType(GridView, skipOffstage: false), findsOneWidget);
    });

    testWidgets(
        'leaderboard gate disappears and tabs appear after signedIn event',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      // Navigate to Leaderboard tab
      await tester.tap(find.byIcon(Icons.emoji_events_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community', skipOffstage: false),
          findsOneWidget);

      // Sign in
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(
          find.text('Join the Community', skipOffstage: false), findsNothing);
      expect(find.byType(TabBar, skipOffstage: false), findsOneWidget);
    });
  });

  // ── Flow C: Guest signs in via progress upsell → full view unlocked ────────

  group('Flow C: sign-in via progress upsell CTA', () {
    testWidgets(
        'tapping Sign in with Google in upsell pushes to SignInScreen',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = () async {};
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey'), findsOneWidget);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // SignInScreen is now in the stack
      expect(find.text('Sign in to track your paath'), findsOneWidget);
    });

    testWidgets('after signing in from SignInScreen, progress becomes full view',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      // Simulate the auth state change that happens when Google SSO completes
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });
  });

  // ── Flow D: Guest signs in via leaderboard gate → leaderboard auto-loads ───

  group('Flow D: sign-in via leaderboard gate', () {
    testWidgets(
        'auth stream signedIn event causes gate to disappear and data to load',
        (tester) async {
      _portraitView(tester);
      int fetchCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        fetchCount++;
        return [
          {
            'rank': 1,
            'user_id': 'integration-test-user',
            'display_name': 'Devotee',
            'total_count': 7
          },
        ];
      };

      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const LeaderboardScreen(),
      ));
      await tester.pumpAndSettle();

      // Gate shown, fetch not called yet
      expect(find.text('Join the Community'), findsOneWidget);
      expect(fetchCount, 0);

      // Sign in via auth stream
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      // Gate gone, leaderboard loaded
      expect(find.text('Join the Community'), findsNothing);
      expect(fetchCount, greaterThanOrEqualTo(1));
      expect(find.text('Devotee'), findsOneWidget);
    });
  });

  // ── Flow E: Signed-in user signs out → all screens revert to guest state ───

  group('Flow E: sign-out reverts all screens to guest state', () {
    setUp(() {
      // Start signed-in
      SupabaseService.currentUserForTest = () => _signedInUser;
      _stubAllScreens(signedIn: true);
    });

    testWidgets('progress reverts to upsell card after signedOut event',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Unlock Your Full Journey'), findsNothing);

      // Sign out
      SupabaseService.currentUserForTest = () => null;
      authCtrl.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsNothing);
      expect(find.text('Unlock Your Full Journey'), findsOneWidget);
    });

    testWidgets('leaderboard reverts to gate after signedOut event',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const LeaderboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Join the Community'), findsNothing);

      // Sign out
      SupabaseService.currentUserForTest = () => null;
      authCtrl.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Join the Community'), findsOneWidget);
    });
  });

  // ── Flow F: 30-min filter is enforced across auth state changes ────────────

  group('Flow F: 30-min filter correctness across auth changes', () {
    testWidgets('guest only sees recent sessions after sign-out', (tester) async {
      _portraitView(tester);
      final now = DateTime.now();
      final recentSession = PlaySession(
        date: AppRepository.dateStr(now),
        count: 1,
        completedAt: now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      );
      final oldSession = PlaySession(
        date: AppRepository.dateStr(now),
        count: 1,
        completedAt: now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      );

      // Start signed-in, both sessions visible
      SupabaseService.currentUserForTest = () => _signedInUser;
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [recentSession, oldSession]);

      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(2));

      // Sign out — only 10-min session should remain
      SupabaseService.currentUserForTest = () => null;
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [recentSession, oldSession]);
      authCtrl.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();

      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('all sessions visible again after signing back in',
        (tester) async {
      _portraitView(tester);
      final now = DateTime.now();
      final recentSession = PlaySession(
        date: AppRepository.dateStr(now),
        count: 1,
        completedAt: now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      final oldSession = PlaySession(
        date: AppRepository.dateStr(now),
        count: 1,
        completedAt: now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      );

      // Start as guest (only recent session visible)
      SupabaseService.currentUserForTest = () => null;
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [recentSession, oldSession]);

      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: const ProgressScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(1));

      // Sign in — both sessions now visible
      SupabaseService.currentUserForTest = () => _signedInUser;
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [recentSession, oldSession]);
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(2));
    });
  });

  // ── Flow G: Onboarding CTA buttons behavior in full context ───────────────

  group('Flow G: onboarding behaviour with MainShell as destination', () {
    testWidgets('Skip for now takes user to MainShell without sign-in',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = null; // no sign-in stub needed for skip

      await tester.pumpWidget(_onboarding());
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // Onboarding is gone
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Skip for now'), findsNothing);
    });

    testWidgets(
        'Cancelled Google picker (no user) keeps user on OnboardingScreen',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = () async {}; // returns normally
      SupabaseService.currentUserForTest = () => null; // picker cancelled

      await tester.pumpWidget(_onboarding());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Still on onboarding
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);

      // onboarding NOT permanently marked
      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isFalse);
    });

    testWidgets(
        'Successful Google sign-in navigates to MainShell and marks onboarding',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = () async {};
      SupabaseService.currentUserForTest = () => _signedInUser;

      await tester.pumpWidget(_onboarding());
      await tester.pump();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Onboarding is gone
      expect(find.text('Continue with Google'), findsNothing);
      // Onboarding is marked as shown
      final shown = await AppRepository.instance.isOnboardingShown();
      expect(shown, isTrue);
    });
  });
}
