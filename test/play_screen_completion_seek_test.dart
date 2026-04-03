// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hanuman_chalisa_app/core/audio_handler.dart';
import 'package:hanuman_chalisa_app/core/theme.dart';
import 'package:hanuman_chalisa_app/data/local/database_helper.dart';
import 'package:hanuman_chalisa_app/data/models/user_settings.dart';
import 'package:hanuman_chalisa_app/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa_app/features/play/play_screen.dart';
import 'package:hanuman_chalisa_app/main.dart' show audioHandlerNotifier, isPlayScreenOpen;

class MockHanumanAudioHandler extends Mock implements HanumanAudioHandler {}

int _dbUid = 0;
AppRepository _freshRepo() {
  final path = p.join(Directory.systemTemp.path, 'hc_play_completion_seek_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(isSignedIn: () => false, syncCompletion: (_) async {});
  return repo;
}

Widget _wrap({
  Set<int>? debugMilestones,
  Future<String> Function()? debugReferralCodeProvider,
  Future<void> Function()? debugSaveSessionOverride,
  bool debugChipsOpen = false,
}) =>
    MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: PlayScreen(
        debugMilestones: debugMilestones,
        debugReferralCodeProvider: debugReferralCodeProvider,
        debugSaveSessionOverride: debugSaveSessionOverride,
        debugChipsOpen: debugChipsOpen,
      ),
    );

void main() {
  late MockHanumanAudioHandler handler;
  late StreamController<PlayerState> playerStateCtrl;
  late StreamController<Duration> positionCtrl;
  late AppRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Duration.zero);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  setUp(() {
    handler = MockHanumanAudioHandler();
    playerStateCtrl = StreamController<PlayerState>.broadcast();
    positionCtrl = StreamController<Duration>.broadcast();
    repo = _freshRepo();
    when(() => handler.playerStateStream).thenAnswer((_) => playerStateCtrl.stream);
    when(() => handler.positionStream).thenAnswer((_) => positionCtrl.stream);
    when(() => handler.duration).thenReturn(Duration.zero);
    when(() => handler.position).thenReturn(Duration.zero);
    when(() => handler.playing).thenReturn(false);
    when(() => handler.volume).thenReturn(1.0);
    when(() => handler.speed).thenReturn(1.0);
    when(() => handler.play()).thenAnswer((_) async {});
    when(() => handler.pause()).thenAnswer((_) async {});
    when(() => handler.seek(any())).thenAnswer((_) async {});
    when(() => handler.setVolume(any())).thenAnswer((_) async {});
    when(() => handler.setSpeed(any())).thenAnswer((_) async {});
    when(() => handler.loadVoice(any())).thenAnswer((_) async {});
    isPlayScreenOpen.value = false;
    audioHandlerNotifier.value = handler;
  });

  tearDown(() {
    if (!playerStateCtrl.isClosed) playerStateCtrl.close();
    if (!positionCtrl.isClosed) positionCtrl.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<int>? debugMilestones,
    Future<String> Function()? debugReferralCodeProvider,
    Future<void> Function()? debugSaveSessionOverride,
    bool debugChipsOpen = false,
  }) async {
    await tester.pumpWidget(
      _wrap(
        debugMilestones: debugMilestones,
        debugReferralCodeProvider: debugReferralCodeProvider,
        debugSaveSessionOverride: debugSaveSessionOverride,
        debugChipsOpen: debugChipsOpen,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> fireCompletion(WidgetTester tester) async {
    playerStateCtrl.add(PlayerState(true, ProcessingState.completed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  group('completion handling', () {
    testWidgets('normal completion increments counter', (tester) async {
      await pump(tester);
      await fireCompletion(tester);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('normal completion writes a session', (tester) async {
      await pump(tester);
      await fireCompletion(tester);
      final c = await tester.runAsync(() => repo.getTodayCount());
      expect(c, 1);
    });

    testWidgets('milestone sheet shows with share CTA via test seam',
        (tester) async {
      await pump(
        tester,
        debugMilestones: {1},
        debugReferralCodeProvider: () async => 'ABC123',
        debugSaveSessionOverride: () async {},
      );
      await fireCompletion(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text('Milestone complete!'), findsOneWidget);
      expect(find.text('Share on WhatsApp'), findsOneWidget);
    });

  });

  group('forward-seek detection', () {
    testWidgets('seeking > 5s ahead skips next completion count', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      when(() => handler.position).thenReturn(Duration.zero);
      await pump(tester);
      await tester.drag(find.byType(Slider).first, const Offset(80, 0));
      await tester.pump();
      await fireCompletion(tester);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('seeking exactly +5s does not skip count', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      when(() => handler.position).thenReturn(const Duration(seconds: 5));
      await pump(tester);
      final s = tester.widget<Slider>(find.byType(Slider).first);
      s.onChanged?.call(1 / 60);
      await tester.pump();
      await fireCompletion(tester);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('restart and skip-next', () {
    testWidgets('restart seeks to zero and plays', (tester) async {
      await pump(tester);
      clearInteractions(handler);
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();
      verify(() => handler.seek(Duration.zero)).called(1);
      verify(() => handler.play()).called(1);
    });

    testWidgets('skip-next clamps near-end seek to zero for short tracks', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(milliseconds: 200));
      await pump(tester);
      clearInteractions(handler);
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();
      verify(() => handler.seek(Duration.zero)).called(1);
    });

    testWidgets('skip-next marks next completion uncounted', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      await pump(tester);
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();
      await fireCompletion(tester);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('target chip selection', () {
    testWidgets('continuousPlay false seeks to zero without play', (tester) async {
      await tester.runAsync(
          () => repo.saveSettings(const UserSettings(continuousPlay: false)));
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      await pump(tester);
      await tester.drag(find.byType(Slider).first, const Offset(80, 0));
      await tester.pump();
      clearInteractions(handler);
      await fireCompletion(tester);
      verify(() => handler.seek(Duration.zero)).called(1);
      verifyNever(() => handler.play());
    });
  });
}
