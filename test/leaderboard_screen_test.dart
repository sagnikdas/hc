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
import 'package:hanuman_chalisa/features/leaderboard/leaderboard_screen.dart';
import 'package:hanuman_chalisa/main.dart' show isPlayScreenOpen;

// ── DB helpers ────────────────────────────────────────────────────────────────

int _dbUid = 0;

AppRepository _freshRepo() {
  final path =
      p.join(Directory.systemTemp.path, 'hc_leaderboard_${_dbUid++}.db');
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

Widget _wrap() => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const LeaderboardScreen(),
    );

// ── View size helper ──────────────────────────────────────────────────────────

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Sample entries ─────────────────────────────────────────────────────────────

final _sampleEntries = [
  {'rank': 1, 'user_id': 'u1', 'display_name': 'Arjuna', 'total_count': 50},
  {'rank': 2, 'user_id': 'u2', 'display_name': 'Bhima', 'total_count': 30},
  {'rank': 3, 'user_id': 'u3', 'display_name': 'Nakula', 'total_count': 20},
  {'rank': 4, 'user_id': 'u4', 'display_name': 'Sahadeva', 'total_count': 10},
];

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late StreamController<AuthState> authCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  setUp(() {
    authCtrl = StreamController<AuthState>.broadcast();
    _freshRepo();
    isPlayScreenOpen.value = false;

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

  // ── Group 1: initial render ─────────────────────────────────────────────────

  group('initial render', () {
    testWidgets('header shows Leaderboard', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('Leaderboard'), findsOneWidget);
    });

    testWidgets('emoji_events_rounded icon is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets('This Week tab is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('This Week'), findsOneWidget);
    });

    testWidgets('All Time tab is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.text('All Time'), findsOneWidget);
    });

    testWidgets('TabBar is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('after load completes: empty state shows', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🙏'), findsOneWidget);
    });
  });

  // ── Group 2: loading state ──────────────────────────────────────────────────

  group('loading state', () {
    testWidgets('CircularProgressIndicator shown while loading', (tester) async {
      _portraitView(tester);
      final completer = Completer<List<Map<String, dynamic>>>();
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pump(); // let initState / didChangeDependencies fire

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('refresh icon NOT visible during loading (replaced by SizedBox)',
        (tester) async {
      _portraitView(tester);
      final completer = Completer<List<Map<String, dynamic>>>();
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'after completing load: CircularProgressIndicator gone, refresh icon visible',
        (tester) async {
      _portraitView(tester);
      final completer = Completer<List<Map<String, dynamic>>>();
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pump();

      completer.complete([]);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  // ── Group 3: empty state ────────────────────────────────────────────────────

  group('empty state', () {
    testWidgets('🙏 emoji text present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🙏'), findsOneWidget);
    });

    testWidgets('No completions yet this period. present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('No completions yet this period.'), findsOneWidget);
    });

    testWidgets('Be the first on the board! present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Be the first on the board!'), findsOneWidget);
    });

    testWidgets('RefreshIndicator is NOT present in empty state', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('CircularProgressIndicator is NOT present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ── Group 4: offline state ──────────────────────────────────────────────────

  group('offline state', () {
    Future<void> pumpWithError(WidgetTester tester, String errorMsg) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) async => throw Exception(errorMsg);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
    }

    testWidgets("error containing 'socket' → 'No internet connection' shown",
        (tester) async {
      await pumpWithError(tester, 'socket error');
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets("error containing 'network' → 'No internet connection' shown",
        (tester) async {
      await pumpWithError(tester, 'network failure');
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets("error containing 'connection' → 'No internet connection' shown",
        (tester) async {
      await pumpWithError(tester, 'connection refused');
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets("error containing 'failed host' → 'No internet connection' shown",
        (tester) async {
      await pumpWithError(tester, 'failed host lookup');
      expect(find.text('No internet connection'), findsOneWidget);
    });

    for (final errorMsg in ['socket error', 'network failure', 'connection refused', 'failed host lookup']) {
      testWidgets('offline error ($errorMsg) → wifi_off icon shown', (tester) async {
        await pumpWithError(tester, errorMsg);
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      });

      testWidgets("offline error ($errorMsg) → 'Connect to view the leaderboard.' shown",
          (tester) async {
        await pumpWithError(tester, errorMsg);
        expect(find.text('Connect to view the leaderboard.'), findsOneWidget);
      });
    }

    testWidgets('non-network error → empty state shown (NOT offline)', (tester) async {
      await pumpWithError(tester, 'server error 500');
      expect(find.text('🙏'), findsOneWidget);
    });

    testWidgets("non-network error → 'No internet connection' NOT shown",
        (tester) async {
      await pumpWithError(tester, 'server error 500');
      expect(find.text('No internet connection'), findsNothing);
    });
  });

  // ── Group 5: loaded with entries ────────────────────────────────────────────

  group('loaded with entries', () {
    setUp(() {
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) async => List<Map<String, dynamic>>.from(_sampleEntries);
    });

    testWidgets('Arjuna text present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Arjuna'), findsOneWidget);
    });

    testWidgets('Bhima text present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Bhima'), findsOneWidget);
    });

    testWidgets('Nakula text present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Nakula'), findsOneWidget);
    });

    testWidgets('Sahadeva text present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Sahadeva'), findsOneWidget);
    });

    testWidgets('50 count present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('30 count present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('paaths label present at least once', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('paaths'), findsWidgets);
    });

    testWidgets('🥇 medal emoji present (rank 1)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥇'), findsOneWidget);
    });

    testWidgets('🥈 medal emoji present (rank 2)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥈'), findsOneWidget);
    });

    testWidgets('🥉 medal emoji present (rank 3)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥉'), findsOneWidget);
    });

    testWidgets('#4 text present (rank 4 uses #N format)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('#4'), findsOneWidget);
    });

    testWidgets('RefreshIndicator present when entries loaded', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('isMe=false for all → NO "you" badge present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('you'), findsNothing);
    });
  });

  // ── Group 6: isMe / you badge ───────────────────────────────────────────────

  group('isMe / you badge', () {
    testWidgets('no you badge when currentUser is null', (tester) async {
      _portraitView(tester);
      SupabaseService.currentUserForTest = () => null;
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) async => List<Map<String, dynamic>>.from(_sampleEntries);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('you'), findsNothing);
    });

    testWidgets('no you container when all entries have non-matching user_ids',
        (tester) async {
      _portraitView(tester);
      SupabaseService.currentUserForTest = () => null;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': 1, 'user_id': 'other1', 'display_name': 'Rama', 'total_count': 5},
            {'rank': 2, 'user_id': 'other2', 'display_name': 'Lakshmana', 'total_count': 3},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('you'), findsNothing);
    });
  });

  // ── Group 7: tab switching ──────────────────────────────────────────────────

  group('tab switching', () {
    testWidgets('initial load uses weekly: true (This Week tab)', (tester) async {
      _portraitView(tester);
      bool? lastWeekly;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        lastWeekly = weekly;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(lastWeekly, isTrue);
    });

    testWidgets('after tapping All Time tab: weekly: false passed', (tester) async {
      _portraitView(tester);
      bool? lastWeekly;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        lastWeekly = weekly;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Time'));
      await tester.pumpAndSettle();

      expect(lastWeekly, isFalse);
    });

    testWidgets('after tapping This Week tab again: weekly: true passed',
        (tester) async {
      _portraitView(tester);
      bool? lastWeekly;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        lastWeekly = weekly;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Time'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('This Week'));
      await tester.pumpAndSettle();

      expect(lastWeekly, isTrue);
    });
  });

  // ── Group 8: refresh icon tap ───────────────────────────────────────────────

  group('refresh icon tap', () {
    testWidgets('refresh icon is tappable and triggers reload', (tester) async {
      _portraitView(tester);
      int callCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        callCount++;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final countAfterInit = callCount;
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(countAfterInit));
    });
  });

  // ── Group 9: pull-to-refresh ────────────────────────────────────────────────

  group('pull-to-refresh', () {
    testWidgets('fling down on ListView triggers reload', (tester) async {
      _portraitView(tester);
      int callCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        callCount++;
        return [
          {'rank': 1, 'user_id': 'u1', 'display_name': 'Rama', 'total_count': 5},
        ];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final countBeforeRefresh = callCount;
      await tester.fling(find.byType(ListView), const Offset(0, 500), 800);
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(countBeforeRefresh));
    });
  });

  // ── Group 10: auth state changes ────────────────────────────────────────────

  group('auth state changes', () {
    testWidgets('emitting a signedIn event causes a rebuild (no crash)',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      authCtrl.add(AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when auth stream emits after widget disposed',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      expect(
        () => authCtrl.add(AuthState(AuthChangeEvent.signedOut, null)),
        returnsNormally,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── Group 11: entry data edge cases ─────────────────────────────────────────

  group('entry data edge cases', () {
    testWidgets('entry with null display_name → shows Devotee fallback',
        (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': 1, 'user_id': 'u1', 'display_name': null, 'total_count': 5},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Devotee'), findsOneWidget);
    });

    testWidgets('entry with null rank → falls back to index+1', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': null, 'user_id': 'u1', 'display_name': 'Rama', 'total_count': 5},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // rank null → index+1 = 1, which is a medal
      expect(find.text('🥇'), findsOneWidget);
    });

    testWidgets('entry with null total_count → shows 0 count', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': 1, 'user_id': 'u1', 'display_name': 'Rama', 'total_count': null},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('entry with rank 1,2,3 → medal emojis NOT #N format',
        (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': 1, 'user_id': 'u1', 'display_name': 'A', 'total_count': 10},
            {'rank': 2, 'user_id': 'u2', 'display_name': 'B', 'total_count': 8},
            {'rank': 3, 'user_id': 'u3', 'display_name': 'C', 'total_count': 6},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('🥉'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
      expect(find.text('#2'), findsNothing);
      expect(find.text('#3'), findsNothing);
    });

    testWidgets('entry with rank 4 → #4 shown NOT medal emoji', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [
            {'rank': 4, 'user_id': 'u4', 'display_name': 'D', 'total_count': 4},
          ];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('🥇'), findsNothing);
    });
  });

  // ── Group 12: rank color / medal logic ──────────────────────────────────────

  group('rank color', () {
    testWidgets('rank 1 entry uses medal emoji 🥇 not #1', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [{'rank': 1, 'user_id': 'u1', 'display_name': 'A', 'total_count': 5}];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
    });

    testWidgets('rank 2 entry uses 🥈 not #2', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [{'rank': 2, 'user_id': 'u2', 'display_name': 'B', 'total_count': 4}];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('#2'), findsNothing);
    });

    testWidgets('rank 3 entry uses 🥉 not #3', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [{'rank': 3, 'user_id': 'u3', 'display_name': 'C', 'total_count': 3}];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('🥉'), findsOneWidget);
      expect(find.text('#3'), findsNothing);
    });

    testWidgets('rank 4+ entry uses #4 format not medal emoji', (tester) async {
      _portraitView(tester);
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async =>
          [{'rank': 4, 'user_id': 'u4', 'display_name': 'D', 'total_count': 2}];
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('🥇'), findsNothing);
    });
  });

  // ── Group 13: didChangeDependencies loads only once ─────────────────────────

  group('didChangeDependencies loads only once', () {
    testWidgets('rebuilding widget does NOT trigger a second load',
        (tester) async {
      _portraitView(tester);
      int callCount = 0;
      SupabaseService.fetchLeaderboardForTest = ({required bool weekly}) async {
        callCount++;
        return [];
      };
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Trigger didChangeDependencies by rebuilding
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(callCount, 1); // only one load, not two
    });
  });

  // ── Group 14: edge cases ─────────────────────────────────────────────────────

  group('edge cases', () {
    testWidgets('rapid mount/unmount: no crash', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      // Replace widget before settle
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounted guard: dispose before async completes → no crash',
        (tester) async {
      _portraitView(tester);
      final completer = Completer<List<Map<String, dynamic>>>();
      SupabaseService.fetchLeaderboardForTest =
          ({required bool weekly}) => completer.future;

      await tester.pumpWidget(_wrap());
      await tester.pump(); // loading started

      // Dispose before complete
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump();

      completer.complete([]); // complete after dispose
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when no entries (empty _entries, no _offline)',
        (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── Group 15: responsiveness — no overflow ──────────────────────────────────

  group('responsiveness — no overflow', () {
    for (final size in const [
      Size(320, 568),
      Size(375, 667),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
      Size(768, 1024),
    ]) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()} empty state — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.text('This Week'), findsOneWidget);
      });
    }

    for (final size in const [Size(320, 568), Size(390, 844)]) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()} with entries — no overflow',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SupabaseService.fetchLeaderboardForTest =
            ({required bool weekly}) async =>
                List<Map<String, dynamic>>.from(_sampleEntries);

        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Leaderboard'), findsOneWidget);
      });
    }
  });
}
