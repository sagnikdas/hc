// ignore_for_file: avoid_relative_lib_imports
//
// Tests for the guest-mode (signed-out) ProgressScreen behaviour introduced in
// the "Enforce Google SSO" feature:
//
//   • Only recitations completed in the last 30 minutes are shown for guests
//   • A "Showing recitations from the last 30 minutes" subtitle is displayed
//   • The "VIEW ALL" button is hidden for guests
//   • An upsell card ("Unlock Your Full Journey") replaces heatmap/streak/weekly
//   • The upsell card lists four bullet benefits and has a "Sign in with Google" CTA
//   • Tapping the CTA pushes SignInScreen onto the navigator
//   • When auth state changes to signed-in the full journey is shown
//   • When auth state changes to signed-out the upsell card returns
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
import 'package:hanuman_chalisa/data/models/play_session.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/features/auth/sign_in_screen.dart';
import 'package:hanuman_chalisa/features/progress/progress_screen.dart';

// ── Mock user ─────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {
  @override
  String get id => 'guest-view-test-user';
}

final _signedInUser = _MockUser();

// ── Overflow suppression ───────────────────────────────────────────────────────

void Function(FlutterErrorDetails)? _originalOnError;

void _suppressOverflowErrors() {
  _originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final s = details.exceptionAsString();
    if (s.contains('overflowed') || s.contains('RenderFlex')) return;
    _originalOnError?.call(details);
  };
}

void _restoreOverflowErrors() {
  FlutterError.onError = _originalOnError;
}

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

AppRepository _freshRepo() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_progress_guest_${_dbUid++}.db');
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

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a PlaySession completed `minutesAgo` minutes in the past.
PlaySession _sessionAgo(int minutesAgo) {
  final ts = DateTime.now()
      .subtract(Duration(minutes: minutesAgo))
      .millisecondsSinceEpoch;
  return PlaySession(
    date: AppRepository.dateStr(
        DateTime.fromMillisecondsSinceEpoch(ts)),
    count: 1,
    completedAt: ts,
  );
}

/// Creates a PlaySession completed exactly `ms` milliseconds in the past.
PlaySession _sessionMsAgo(int ms) {
  final ts = DateTime.now().millisecondsSinceEpoch - ms;
  return PlaySession(
    date: AppRepository.dateStr(DateTime.fromMillisecondsSinceEpoch(ts)),
    count: 1,
    completedAt: ts,
  );
}

// ── Widget wrappers ───────────────────────────────────────────────────────────

Widget _wrapGuest({int refreshSignal = 0}) => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: ProgressScreen(refreshSignal: refreshSignal),
    );

Widget _wrapSignedIn({int refreshSignal = 0}) => _wrapGuest(refreshSignal: refreshSignal);

// ── View size helpers ─────────────────────────────────────────────────────────

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
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
    _suppressOverflowErrors();
  });

  tearDownAll(_restoreOverflowErrors);

  setUp(() {
    _freshRepo();
    authCtrl = StreamController<AuthState>.broadcast();
    SupabaseService.authChangesForTest = authCtrl.stream;
    // Default: guest (not signed in)
    SupabaseService.currentUserForTest = () => null;
    // SignInScreen auto-starts SSO from upsell; avoid real GoogleSignIn in tests.
    SupabaseService.signInForTest = () async {};
    AppRepository.instance.overrideProgressForTest();
  });

  tearDown(() {
    AppRepository.instance.clearStatsOverrideForTest();
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
  });

  // ── 1. Guest initial render ────────────────────────────────────────────────

  group('guest initial render', () {
    testWidgets('header Your Devotional Journey is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Your Devotional Journey'), findsOneWidget);
    });

    testWidgets('Recent Sessions section is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recent Sessions'), findsOneWidget);
    });

    testWidgets('30-min subtitle is shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.text('Showing recitations from the last 30 minutes'),
        findsOneWidget,
      );
    });

    testWidgets('VIEW ALL button is NOT present for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('VIEW ALL'), findsNothing);
    });

    testWidgets('upsell card Unlock Your Full Journey is present',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Unlock Your Full Journey'), findsOneWidget);
    });

    testWidgets('heatmap GridView is NOT shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('Spiritual Consistency title NOT shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Spiritual Consistency'), findsNothing);
    });

    testWidgets('Sadhana Milestones NOT shown for guests', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Sadhana Milestones'), findsNothing);
    });

    testWidgets('CURRENT STREAK label NOT shown for guests', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('CURRENT STREAK'), findsNothing);
    });

    testWidgets('WEEKLY label NOT shown for guests', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY'), findsNothing);
    });
  });

  // ── 2. Upsell card content ─────────────────────────────────────────────────

  group('upsell card content', () {
    testWidgets('lock_open icon is present in upsell card', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('heatmap bullet is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('12-week heatmap', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('streaks bullet is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Weekly & all-time', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('leaderboard bullet is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('leaderboard', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('devices sync bullet is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('synced across your devices', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Sign in with Google CTA button is present in upsell card',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in with Google', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  // ── 3. Upsell CTA navigation ───────────────────────────────────────────────

  group('upsell card sign-in CTA navigation', () {
    testWidgets('tapping Sign in with Google pushes SignInScreen', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  // ── 4. 30-minute session filter (guest) ───────────────────────────────────

  group('30-minute session filter for guests', () {
    testWidgets('session 5 min ago → shown', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(5)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsOneWidget);
    });

    testWidgets('session 25 min ago → shown', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(25)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsOneWidget);
    });

    testWidgets('session exactly 30 min ago → shown (boundary inclusive)',
        (tester) async {
      _portraitView(tester);
      // age == 30 * 60 * 1000 exactly
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionMsAgo(30 * 60 * 1000)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsOneWidget);
    });

    testWidgets('session 30 min + 1 ms ago → hidden (boundary exclusive)',
        (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionMsAgo(30 * 60 * 1000 + 1)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
      expect(find.textContaining('No sessions yet'), findsOneWidget);
    });

    testWidgets('session 35 min ago → hidden', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(35)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
    });

    testWidgets('session 1 hour ago → hidden', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(60)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
    });

    testWidgets('session from yesterday → hidden', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(60 * 24)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
    });

    testWidgets('mixed: 1 inside + 1 outside window → only 1 shown',
        (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(10), _sessionAgo(45)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
          find.text('Recitation', skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('all outside window → empty state shown', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(60), _sessionAgo(120)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
      expect(find.textContaining('No sessions yet'), findsOneWidget);
    });

    testWidgets('all inside window → all shown (up to 5)', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(recentSessions: [
        _sessionAgo(1),
        _sessionAgo(5),
        _sessionAgo(10),
      ]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(
          find.text('Recitation', skipOffstage: false), findsNWidgets(3));
    });

    testWidgets('no sessions at all → empty state, no crash', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(recentSessions: []);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('No sessions yet'), findsOneWidget);
    });
  });

  // ── 5. Signed-in view shows all sections ──────────────────────────────────

  group('signed-in initial render', () {
    setUp(() {
      SupabaseService.currentUserForTest = () => _signedInUser;
    });

    testWidgets('heatmap GridView IS shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('Spiritual Consistency IS shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.text('Spiritual Consistency'), findsOneWidget);
    });

    testWidgets('Sadhana Milestones IS shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.text('Sadhana Milestones'), findsOneWidget);
    });

    testWidgets('VIEW ALL button IS shown when signed in', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(5)]);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.text('VIEW ALL', skipOffstage: false), findsOneWidget);
    });

    testWidgets('upsell card NOT shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.text('Unlock Your Full Journey'), findsNothing);
    });

    testWidgets('30-min subtitle NOT shown when signed in', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(
          find.text('Showing recitations from the last 30 minutes'),
          findsNothing);
    });

    testWidgets('session older than 30 min IS shown when signed in',
        (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(60)]);
      await tester.pumpWidget(_wrapSignedIn());
      await tester.pumpAndSettle();
      expect(find.text('Recitation', skipOffstage: false), findsOneWidget);
    });
  });

  // ── 6. Auth state transitions ─────────────────────────────────────────────

  group('auth state transitions', () {
    testWidgets('guest → signed-in: upsell disappears, heatmap appears',
        (tester) async {
      _portraitView(tester);
      // Start as guest
      SupabaseService.currentUserForTest = () => null;
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      // Sign in
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Your Full Journey'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('signed-in → signed-out: heatmap disappears, upsell appears',
        (tester) async {
      _portraitView(tester);
      // Start as signed-in
      SupabaseService.currentUserForTest = () => _signedInUser;
      await tester.pumpWidget(_wrapSignedIn());
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

    testWidgets('multiple auth transitions do not crash', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();

      // sign-in
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      // sign-out
      SupabaseService.currentUserForTest = () => null;
      authCtrl.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();

      // sign-in again
      SupabaseService.currentUserForTest = () => _signedInUser;
      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when auth event fires after widget disposed',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrapGuest());
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

  // ── 7. Refresh + auth interaction ─────────────────────────────────────────

  group('refresh with guest/signed-in states', () {
    testWidgets('pull-to-refresh in guest mode re-applies 30-min filter',
        (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(5)]);
      await tester.pumpWidget(_wrapGuest());
      await tester.pumpAndSettle();

      // 1 recent session shown
      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(1));

      // Update sessions to only have an old one
      AppRepository.instance.overrideProgressForTest(
          recentSessions: [_sessionAgo(90)]);

      await tester.fling(
          find.byType(CustomScrollView), const Offset(0, 500), 800);
      await tester.pumpAndSettle();

      // Old session filtered out
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
    });

    testWidgets('refreshSignal change reloads with current auth state',
        (tester) async {
      _portraitView(tester);
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [_sessionAgo(5)]);

      await tester.pumpWidget(_wrapGuest(refreshSignal: 0));
      await tester.pumpAndSettle();

      expect(find.text('Recitation', skipOffstage: false), findsNWidgets(1));

      // Change signal → reload triggers
      AppRepository.instance
          .overrideProgressForTest(recentSessions: [_sessionAgo(90)]);
      await tester.pumpWidget(_wrapGuest(refreshSignal: 1));
      await tester.pumpAndSettle();

      // Old session still filtered for guest
      expect(find.text('Recitation', skipOffstage: false), findsNothing);
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
          '${size.width.toInt()} × ${size.height.toInt()} guest — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrapGuest());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Unlock Your Full Journey'), findsOneWidget);
      });
    }
  });
}
