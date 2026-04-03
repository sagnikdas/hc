// ignore_for_file: avoid_relative_lib_imports
//
// Tests for the leaderboard sign-in gate introduced in the
// "Enforce Google SSO" feature:
//
//   • Guest (not signed-in) sees a full-screen sign-in gate, not the data view
//   • Gate shows "Join the Community" title, description, and Google sign-in button
//   • The tab bar is NOT shown for guests
//   • fetchLeaderboard is NOT called until the user signs in
//   • Tapping "Sign in with Google" in the gate calls signInWithGoogle()
//   • After sign-in via the gate, the leaderboard auto-loads
//   • Sign-in error in gate shows inline error and stays on gate
//   • An auth stream event (signedIn) transitions the gate to the leaderboard
//   • An auth stream event (signedOut) transitions the leaderboard to the gate
//   • Signed-in user never sees the gate
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hanuman_chalisa_app/core/supabase_service.dart';
import 'package:hanuman_chalisa_app/core/theme.dart';
import 'package:hanuman_chalisa_app/data/local/database_helper.dart';
import 'package:hanuman_chalisa_app/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa_app/features/leaderboard/leaderboard_screen.dart';
import 'package:hanuman_chalisa_app/main.dart' show isPlayScreenOpen;

// ── Mock user ──────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {
  @override
  String get id => 'gate-test-user';
}

final _testUser = _MockUser();

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

void _freshDb() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_lb_gate_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  AppRepository.instance.overrideSyncForTest(
    isSignedIn: () => false,
    syncCompletion: (_) async {},
  );
}

// ── Widget wrapper ─────────────────────────────────────────────────────────────

Widget _wrap() => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const LeaderboardScreen(),
    );

// ── View size helper ───────────────────────────────────────────────────────────

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
  });

  setUp(() {
    _freshDb();
    authCtrl = StreamController<AuthState>.broadcast();
    isPlayScreenOpen.value = false;
    // Default: guest (gate is shown)
    SupabaseService.authChangesForTest = authCtrl.stream;
    SupabaseService.currentUserForTest = () => null;
    SupabaseService.fetchProfileForTest = () async => null;
    SupabaseService.signInForTest = null;
    SupabaseService.fetchLeaderboardForTest =
        ({required bool weekly}) async => [];
  });

  tearDown(() {
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
    AppRepository.instance.clearStatsOverrideForTest();
  });

  // ── 1. Gate initial render ─────────────────────────────────────────────────

  group('gate initial render (guest)', () {
    testWidgets('header Leaderboard title is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Leaderboard'), findsOneWidget);
    });

    testWidgets('Join the Community title is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Join the Community'), findsOneWidget);
    });

    testWidgets('description text about global ranking is present',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sign in with Google to unlock your place on the leaderboard'),
        findsOneWidget,
      );
    });

    testWidgets('sync description text is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sync and appear on the global board'),
        findsOneWidget,
      );
    });

    testWidgets('Sign in with Google button is present in gate', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('trophy emoji_events icon is present in gate', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
    });
  });

  // ── 2. Leaderboard tabs/data NOT shown for guests ─────────────────────────

  group('leaderboard data hidden for guests', () {
    testWidgets('TabBar is NOT shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('This Week tab text is NOT present for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('This Week'), findsNothing);
    });

    testWidgets('All Time tab text is NOT present for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('All Time'), findsNothing);
    });

    testWidgets('fetchLeaderboard is NOT called for guests', (tester) async {
      _portraitView(tester);
      bool called = false;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        called = true;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('refresh icon NOT visible for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('no loading spinner shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ── 3. Gate sign-in button — loading state ────────────────────────────────

  group('gate sign-in button loading', () {
    testWidgets('spinner shown while sign-in is in-flight', (tester) async {
      _portraitView(tester);
      final completer = Completer<void>();
      SupabaseService.signInForTest = () => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });

  // ── 4. Gate sign-in — error handling ─────────────────────────────────────

  group('gate sign-in error handling', () {
    testWidgets('generic error shows Sign-in failed message', (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('auth error');

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // In debug mode, kDebugMode is true, so the full exception is shown
      expect(find.textContaining('auth error'), findsOneWidget);
    });

    testWidgets('StateError message shown verbatim', (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw StateError('kGoogleWebClientId not set');

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('kGoogleWebClientId not set'), findsOneWidget);
    });

    testWidgets('gate still shown after error (no false navigation)',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest =
          () async => throw Exception('error');

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('no crash when widget unmounted during sign-in', (tester) async {
      _portraitView(tester);
      final completer = Completer<void>();
      SupabaseService.signInForTest = () async {
        await completer.future;
        throw Exception('late error');
      };

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      completer.completeError(Exception('late error'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ── 5. Gate sign-in success → leaderboard loads ───────────────────────────

  group('gate sign-in success', () {
    testWidgets(
        'sign-in completes + auth stream fires → gate disappears, tabs appear',
        (tester) async {
      _portraitView(tester);
      SupabaseService.signInForTest = () async {};
      int loadCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        loadCount++;
        return [];
      };

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);

      // Simulate successful sign-in: emit auth event + set user
      SupabaseService.currentUserForTest = () => _testUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
      expect(loadCount, greaterThanOrEqualTo(1));
    });
  });

  // ── 6. Auth stream transitions ────────────────────────────────────────────

  group('auth stream transitions', () {
    testWidgets('signedIn event → gate disappears, leaderboard shown',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);

      SupabaseService.currentUserForTest = () => _testUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Join the Community'), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('signedOut event → leaderboard hidden, gate shown',
        (tester) async {
      _portraitView(tester);
      // Start signed-in
      SupabaseService.currentUserForTest = () => _testUser;
      await tester.pumpWidget(_wrap());
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

    testWidgets('sign-in then sign-out then sign-in again → correct transitions',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Join the Community'), findsOneWidget);

      // Sign in
      SupabaseService.currentUserForTest = () => _testUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);

      // Sign out
      SupabaseService.currentUserForTest = () => null;
      authCtrl.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();
      expect(find.text('Join the Community'), findsOneWidget);

      // Sign in again
      SupabaseService.currentUserForTest = () => _testUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when auth event fires after widget disposed',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      expect(
        () => authCtrl.add(AuthState(AuthChangeEvent.signedIn, null)),
        returnsNormally,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── 7. Signed-in user never sees the gate ─────────────────────────────────

  group('signed-in user sees leaderboard, not gate', () {
    setUp(() {
      SupabaseService.currentUserForTest = () => _testUser;
    });

    testWidgets('gate Join the Community NOT shown when signed in',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Join the Community'), findsNothing);
    });

    testWidgets('TabBar IS shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('This Week tab IS shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('This Week'), findsOneWidget);
    });

    testWidgets('fetchLeaderboard IS called when signed in', (tester) async {
      _portraitView(tester);
      bool called = false;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        called = true;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(called, isTrue);
    });

    testWidgets('leaderboard auto-loads only once (not on each rebuild)',
        (tester) async {
      _portraitView(tester);
      int callCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        callCount++;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Rebuild same widget
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(callCount, 1); // only one load triggered
    });
  });

  // ── 8. Responsiveness ─────────────────────────────────────────────────────

  group('responsiveness — no overflow', () {
    for (final size in const [
      Size(320, 568),
      Size(375, 667),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()} gate — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.text('Join the Community'), findsOneWidget);
      });
    }
  });
}
