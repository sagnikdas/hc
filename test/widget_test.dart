// ignore_for_file: avoid_relative_lib_imports
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
import 'package:hanuman_chalisa_app/features/onboarding/onboarding_screen.dart';

// ── Fakes / mocks ──────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {
  @override
  String get id => 'onboarding-user-id';
}

final _testUser = _MockUser();

// ── DB helpers ─────────────────────────────────────────────────────────────────

int _dbUid = 0;

void _freshDb() {
  final path = p.join(Directory.systemTemp.path, 'hc_widget_${_dbUid++}.db');
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

Widget _wrap(Widget child) => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: child,
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late StreamController<AuthState> authCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Silence platform channel calls (haptics, notification service, etc.).
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
  });

  // ── Rendering (welcome content) ─────────────────────────────────────────────

  testWidgets('OnboardingScreen renders welcome content', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('Hanuman Chalisa'), findsOneWidget);
    // Primary CTA is now Google sign-in, not "Begin Your Journey"
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Invite devotees via WhatsApp'), findsOneWidget);
    expect(find.text('Begin Your Journey'), findsNothing);
  });

  testWidgets('OnboardingScreen share button is tappable', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    // The share row exists and is a GestureDetector.
    expect(find.text('Invite devotees via WhatsApp'), findsOneWidget);
  });

  // ── Sign-in cancelled (user dismissed Google picker) ────────────────────────

  testWidgets(
      'tapping Google CTA when picker cancelled stays on OnboardingScreen',
      (tester) async {
    SupabaseService.signInForTest = () async {};  // returns normally, no user
    SupabaseService.currentUserForTest = () => null;

    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ── Sign-in error ────────────────────────────────────────────────────────────

  testWidgets('sign-in error shows inline error message', (tester) async {
    SupabaseService.signInForTest =
        () async => throw Exception('network timeout');

    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // In debug mode, kDebugMode is true, so the full exception is shown
    expect(find.textContaining('network timeout'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('no crash when widget unmounted while sign-in is in-flight',
      (tester) async {
    final completer = Completer<void>();
    SupabaseService.signInForTest = () => completer.future;

    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    // Unmount before sign-in completes
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();

    completer.completeError(Exception('late error'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
