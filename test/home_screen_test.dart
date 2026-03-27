// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hanuman_chalisa/core/supabase_service.dart';
import 'package:hanuman_chalisa/core/theme.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/features/home/home_screen.dart';
import 'package:hanuman_chalisa/main.dart' show isPlayScreenOpen;

// ── Fakes / Mocks ─────────────────────────────────────────────────────────────

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

AppRepository _freshRepo() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_home_${_dbUid++}.db');
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

// ── Widget wrapper ────────────────────────────────────────────────────────────

Widget _wrap({
  int refreshSignal = 0,
  VoidCallback? onSwitchToSettings,
  List<NavigatorObserver> observers = const [],
}) =>
    MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorObservers: observers,
      home: HomeScreen(
        refreshSignal: refreshSignal,
        onSwitchToSettings: onSwitchToSettings,
      ),
    );

// ── View size helper ──────────────────────────────────────────────────────────
//
// Default test view (800 × 600, landscape) causes sp() to scale at 1.28×,
// making the hero card 461 px tall. Sacred Melodies and stat cards are pushed
// off-screen and never built by the lazy SliverChildListDelegate.
// All tests use a portrait phone viewport (390 × 844) so every section fits.

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Stat value finder ─────────────────────────────────────────────────────────
//
// _StatCard renders its value inside a RichText TextSpan. find.text() only
// matches Text/EditableText by default; find.textContaining + findRichText
// is version-sensitive. Using byWidgetPredicate with toPlainText() is the
// most portable, version-agnostic approach.

Finder _statContaining(String substring) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(substring),
  skipOffstage: false,
);

// (DB seed helpers removed — stat tests use AppRepository.overrideStatsForTest()
//  which bypasses sqflite so pumpAndSettle() can settle without hitting the FFI worker.)

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late StreamController<AuthState> authCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Required so mocktail can capture Route<dynamic> arguments for NavigatorObserver.
    registerFallbackValue(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    // Silence platform-channel calls (haptics, SystemUI).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  setUp(() {
    authCtrl = StreamController<AuthState>.broadcast();
    _freshRepo();
    isPlayScreenOpen.value = false;

    // Default stat overrides: 0/0 so pumpAndSettle() can drain immediately
    // without hitting the sqflite FFI worker thread.
    AppRepository.instance.overrideStatsForTest(todayCount: 0, bestStreak: 0);

    // Wire all Supabase seams — SDK is never touched during tests.
    SupabaseService.authChangesForTest = authCtrl.stream;
    SupabaseService.currentUserForTest = () => null; // logged-out default
    SupabaseService.fetchProfileForTest = () async => null;
    SupabaseService.signInForTest = null; // overridden per-test when needed
  });

  tearDown(() {
    if (!authCtrl.isClosed) authCtrl.close();
    SupabaseService.resetAuthForTest();
    AppRepository.instance.clearStatsOverrideForTest();
  });

  // ── 1. Initial render ──────────────────────────────────────────────────────

  group('initial render', () {
    testWidgets('header shows app title', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      // Title appears at least once (also in melody tile).
      expect(find.text('Hanuman Chalisa'), findsWidgets);
    });

    testWidgets('stat card labels TODAY and BEST STREAK are present',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('BEST STREAK'), findsOneWidget);
    });

    testWidgets('hero card sankalpa label and CTA are visible', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text("TODAY'S SANKALPA"), findsOneWidget);
      expect(find.text('START NOW'), findsOneWidget);
    });

    testWidgets('hero card descriptive text is visible', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('Begin your sacred'), findsOneWidget);
      expect(find.textContaining('Focus your mind'), findsOneWidget);
    });

    testWidgets('Sacred Melodies section title is visible', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sacred Melodies'), findsOneWidget);
    });

    testWidgets('both Sacred Melody tile subtitles are visible', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Traditional Devotional'), findsOneWidget);
      expect(find.text('Voice Recitation'), findsOneWidget);
      expect(find.text('Sacred Chant'), findsOneWidget);
    });

    testWidgets('Sacred Melody tile icons are rendered', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.surround_sound_rounded), findsOneWidget);
      expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
    });

    testWidgets('menu icon is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('stat value widgets are present (RichText)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // _StatCard uses RichText for the value + unit.  After load, at least
      // two RichText nodes must exist (one per stat card).
      expect(find.byType(RichText), findsWidgets);
    });
  });

  // ── 2. Loaded stats ────────────────────────────────────────────────────────

  group('loaded stats', () {
    // _StatCard renders the count inside a RichText TextSpan.
    // AppRepository.overrideStatsForTest() bypasses sqflite entirely so
    // pumpAndSettle() can settle without touching the FFI worker thread.

    testWidgets('shows 0 for both stats when no completions exist', (tester) async {
      _portraitView(tester);
      // Default override is already 0/0 from setUp.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining('0 times'), findsOneWidget);
      expect(_statContaining('0 days'), findsOneWidget);
    });

    testWidgets('shows correct todayCount', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 5, bestStreak: 0);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining('5 times'), findsOneWidget);
    });

    testWidgets('shows correct bestStreak', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 0, bestStreak: 4);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining('4 days'), findsOneWidget);
    });

    testWidgets('todayCount and bestStreak are independent', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 3, bestStreak: 7);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining('3 times'), findsOneWidget);
      expect(_statContaining('7 days'), findsOneWidget);
    });

    testWidgets('large count (99) renders without layout overflow', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 99, bestStreak: 0);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining('99 times'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unit labels (times / days) are present in RichText spans',
        (tester) async {
      _portraitView(tester);
      // default 0/0 override — units are always shown regardless of value
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(_statContaining(' times'), findsOneWidget);
      expect(_statContaining(' days'), findsOneWidget);
    });

    testWidgets('stats update when refreshSignal increments', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 0, bestStreak: 0);
      await tester.pumpWidget(_wrap(refreshSignal: 0));
      await tester.pumpAndSettle();

      AppRepository.instance.overrideStatsForTest(todayCount: 4, bestStreak: 0);
      await tester.pumpWidget(_wrap(refreshSignal: 1));
      await tester.pumpAndSettle();
      expect(_statContaining('4 times'), findsOneWidget);
    });
  });

  // ── 3. Hero card navigation ────────────────────────────────────────────────

  group('hero card navigation', () {
    testWidgets("tapping TODAY'S SANKALPA area pushes a route", (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pump();
      await tester.tap(find.text("TODAY'S SANKALPA"));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping START NOW button pushes a route', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pump();
      await tester.tap(find.text('START NOW'));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping hero card descriptive copy pushes a route',
        (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pump();
      await tester.tap(find.textContaining('Focus your mind'));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });
  });

  // ── 4. Sacred Melodies navigation ─────────────────────────────────────────

  group('sacred melodies navigation', () {
    testWidgets('tapping Hanuman Chalisa tile pushes a route', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traditional Devotional'));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping Voice Recitation tile pushes a route', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sacred Chant'));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping the surround_sound icon navigates', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.surround_sound_rounded));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('tapping the record_voice icon navigates', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(_wrap(observers: [observer]));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.record_voice_over_rounded));
      await tester.pump();
      verify(() => observer.didPush(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });
  });

  // ── 5. Drawer ──────────────────────────────────────────────────────────────

  group('drawer', () {
    Future<void> openDrawer(WidgetTester tester,
        {VoidCallback? onSettings}) async {
      _portraitView(tester);
      await tester.pumpWidget(
          _wrap(onSwitchToSettings: onSettings ?? () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('menu icon tap opens the Drawer', (tester) async {
      await openDrawer(tester);
      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets("shows 'Devotee' name when no user is signed in", (tester) async {
      await openDrawer(tester);
      expect(find.text('Devotee'), findsOneWidget);
    });

    testWidgets('shows OM symbol in avatar when no user is signed in',
        (tester) async {
      await openDrawer(tester);
      // CircleAvatar fallback shows 'ॐ' (OM) when currentUser is null.
      final drawerFinder = find.byType(Drawer);
      expect(
        find.descendant(of: drawerFinder, matching: find.text('ॐ')),
        findsOneWidget,
      );
    });

    testWidgets("shows 'Sync Your Path' CTA when not signed in", (tester) async {
      await openDrawer(tester);
      expect(find.text('Sync Your Path'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    });

    testWidgets('tapping Sync Your Path calls signInWithGoogle', (tester) async {
      bool called = false;
      SupabaseService.signInForTest = () async => called = true;
      await openDrawer(tester);
      await tester.tap(find.text('Sync Your Path'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets(
        'authLoading: button becomes spinner and text changes to Signing in…',
        (tester) async {
      final completer = Completer<void>();
      SupabaseService.signInForTest = () => completer.future;
      await openDrawer(tester);

      await tester.tap(find.text('Sync Your Path'));
      await tester.pump(); // setState(_authLoading = true)

      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sync Your Path'), findsNothing);

      completer.complete(); // prevent leaked async operation
      await tester.pumpAndSettle();
    });

    testWidgets('authLoading: onTap is null — second tap is a no-op', (tester) async {
      int callCount = 0;
      final completer = Completer<void>();
      SupabaseService.signInForTest = () {
        callCount++;
        return completer.future;
      };
      await openDrawer(tester);

      await tester.tap(find.text('Sync Your Path')); // first tap
      await tester.pump(); // authLoading = true → onTap = null

      // Attempt a second tap on the same area while loading.
      await tester.tap(find.text('Signing in…'), warnIfMissed: false);
      await tester.pump();

      expect(callCount, 1); // only one call, second tap was swallowed

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('sign-in error resets authLoading without crashing', (tester) async {
      SupabaseService.signInForTest =
          () async => throw Exception('network error');
      await openDrawer(tester);

      await tester.tap(find.text('Sync Your Path'));
      await tester.pumpAndSettle();

      // Widget recovers — button restored to normal state.
      expect(find.text('Sync Your Path'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'shows Sankalp Settings item when onSwitchToSettings is provided',
        (tester) async {
      await openDrawer(tester);
      expect(find.text('Sankalp Settings'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('no settings item when onSwitchToSettings is null', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap()); // no callback
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sankalp Settings'), findsNothing);
    });

    testWidgets('tapping Sankalp Settings fires callback and closes drawer',
        (tester) async {
      bool called = false;
      await openDrawer(tester, onSettings: () => called = true);
      await tester.tap(find.text('Sankalp Settings'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets("drawer shows TODAY'S RECITATIONS label", (tester) async {
      await openDrawer(tester);
      expect(find.text("TODAY'S RECITATIONS"), findsOneWidget);
    });

    testWidgets('drawer todayCount reflects stat override value', (tester) async {
      AppRepository.instance.overrideStatsForTest(todayCount: 7, bestStreak: 0);
      await openDrawer(tester);
      // '7' appears in drawer recitation count (NotoSerif Text widget).
      expect(find.text('7'), findsWidgets);
    });

    testWidgets('drawer todayCount is 0 when no sessions today', (tester) async {
      await openDrawer(tester);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('branding footer is present at bottom of drawer', (tester) async {
      await openDrawer(tester);
      final drawerFinder = find.byType(Drawer);
      expect(
        find.descendant(
            of: drawerFinder, matching: find.text('Hanuman Chalisa')),
        findsOneWidget,
      );
    });

    testWidgets('profile name from fetchProfile is shown in drawer', (tester) async {
      SupabaseService.fetchProfileForTest =
          () async => <String, dynamic>{'name': 'Ramesh'};
      _portraitView(tester);
      await tester.pumpWidget(_wrap(onSwitchToSettings: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Ramesh'), findsOneWidget);
    });
  });

  // ── 6. Pull-to-refresh ─────────────────────────────────────────────────────

  group('pull-to-refresh', () {
    testWidgets('RefreshIndicator is present in the tree', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('fling down triggers _loadStats (RefreshIndicator is wired)', (tester) async {
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 0, bestStreak: 0);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Change the override to simulate new data arriving after a refresh.
      AppRepository.instance.overrideStatsForTest(todayCount: 3, bestStreak: 0);

      await tester.fling(
          find.byType(CustomScrollView), const Offset(0, 500), 800);
      await tester.pumpAndSettle();

      // After refresh, the updated todayCount is displayed.
      expect(_statContaining('3 times'), findsOneWidget);
    });
  });

  // ── 7. refreshSignal ───────────────────────────────────────────────────────

  group('refreshSignal', () {
    testWidgets('incrementing refreshSignal triggers stat reload', (tester) async {
      // Covered by the loaded stats group's 'stats update when refreshSignal increments' test.
      // This test ensures the didUpdateWidget guard fires on signal change.
      _portraitView(tester);
      AppRepository.instance.overrideStatsForTest(todayCount: 0, bestStreak: 0);
      await tester.pumpWidget(_wrap(refreshSignal: 0));
      await tester.pumpAndSettle();

      AppRepository.instance.overrideStatsForTest(todayCount: 6, bestStreak: 0);
      await tester.pumpWidget(_wrap(refreshSignal: 1));
      await tester.pumpAndSettle();
      expect(_statContaining('6 times'), findsOneWidget);
    });

    testWidgets('same refreshSignal does NOT re-trigger reload', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap(refreshSignal: 1));
      await tester.pumpAndSettle();
      // Rebuild with same signal — widget is stable, no exception.
      await tester.pumpWidget(_wrap(refreshSignal: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── 8. Auth subscription ───────────────────────────────────────────────────

  group('auth subscription', () {
    testWidgets('auth state change triggers _loadProfile', (tester) async {
      _portraitView(tester);
      int fetchCount = 0;
      SupabaseService.fetchProfileForTest = () async {
        fetchCount++;
        return null;
      };

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final countAfterInit = fetchCount;

      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThan(countAfterInit));
    });

    testWidgets('multiple auth events each trigger a profile reload', (tester) async {
      _portraitView(tester);
      int fetchCount = 0;
      SupabaseService.fetchProfileForTest = () async {
        fetchCount++;
        return null;
      };

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      final base = fetchCount;

      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      authCtrl.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
      await tester.pumpAndSettle();

      expect(fetchCount - base, 2);
    });

    testWidgets('no crash when auth stream emits after widget is disposed',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Dispose HomeScreen by navigating away.
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      // Emission after dispose must be silently swallowed (subscription cancelled).
      expect(
        () => authCtrl.add(AuthState(AuthChangeEvent.signedOut, null)),
        returnsNormally,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── 9. Responsiveness ─────────────────────────────────────────────────────

  group('responsiveness — no overflow on common screen sizes', () {
    for (final size in const [
      Size(320, 568), // small (iPhone SE 1st gen)
      Size(375, 667), // baseline (iPhone SE 3rd gen / 8)
      Size(390, 844), // iPhone 14
      Size(412, 915), // Pixel 6
      Size(430, 932), // iPhone 14 Pro Max
    ]) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()} — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Core sections must be present on every screen size.
        expect(find.text("TODAY'S SANKALPA"), findsOneWidget);
        expect(find.text('Sacred Melodies'), findsOneWidget);
        expect(find.text('Voice Recitation'), findsOneWidget);
      });
    }
  });

  // ── 10. Primary-colour accent ──────────────────────────────────────────────

  group('primary-colour accent on icons', () {
    const primary = Color(0xFFFFB59A);

    testWidgets('TODAY stat icon uses primary colour', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => i.icon == Icons.auto_awesome_rounded)
          .toList();

      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, primary,
            reason: 'auto_awesome_rounded icon should use primary colour');
      }
    });

    testWidgets('BEST STREAK bolt icon uses primary colour', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => i.icon == Icons.bolt_rounded)
          .toList();

      expect(icons, isNotEmpty);
      for (final icon in icons) {
        expect(icon.color, primary,
            reason: 'bolt_rounded icon should use primary colour');
      }
    });
  });

  // ── 11. Edge cases ─────────────────────────────────────────────────────────

  group('edge cases', () {
    testWidgets('rapid mount/unmount does not crash (mounted guard)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      // Unmount before async ops complete.
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fetchProfile returning null does not crash', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchProfileForTest = () async => null;
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fetchProfile throwing does not crash (catchError guard)',
        (tester) async {
      _portraitView(tester);
      SupabaseService.fetchProfileForTest =
          () async => throw Exception('network failure');
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // catchError in _loadProfile swallows the exception.
      expect(tester.takeException(), isNull);
      expect(find.text("TODAY'S SANKALPA"), findsOneWidget);
    });

    testWidgets('empty DB shows 0 for both stats, not dashes', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // After load completes, dashes are gone and 0 values are shown (default override is 0/0).
      expect(_statContaining('0 times'), findsOneWidget);
      expect(_statContaining('0 days'), findsOneWidget);
    });

    testWidgets('hero card image error fallback keeps UI intact', (tester) async {
      // Assets cannot load in unit tests → errorBuilder is triggered.
      // The overlay text must still be present.
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text("TODAY'S SANKALPA"), findsOneWidget);
      expect(find.text('START NOW'), findsOneWidget);
    });

    testWidgets('session hero background asset is stable across rebuilds',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap(refreshSignal: 0));
      await tester.pumpAndSettle();

      final assets0 = tester
          .widgetList<Image>(find.byType(Image))
          .map((img) => (img.image as AssetImage?)?.assetName)
          .toList();

      // Rebuild with a different signal — hero image must not re-randomise.
      await tester.pumpWidget(_wrap(refreshSignal: 1));
      await tester.pumpAndSettle();

      final assets1 = tester
          .widgetList<Image>(find.byType(Image))
          .map((img) => (img.image as AssetImage?)?.assetName)
          .toList();

      expect(assets1, equals(assets0));
    });

    testWidgets('rapid successive refreshSignal changes do not throw', (tester) async {
      _portraitView(tester);
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(_wrap(refreshSignal: i));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
