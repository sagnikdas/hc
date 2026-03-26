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

import 'package:hanuman_chalisa/core/audio_handler.dart';
import 'package:hanuman_chalisa/core/theme.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/features/play/play_screen.dart';
import 'package:hanuman_chalisa/main.dart' show audioHandlerNotifier, isPlayScreenOpen;

class MockHanumanAudioHandler extends Mock implements HanumanAudioHandler {}

int _dbUid = 0;
void _freshRepo() {
  final path = p.join(Directory.systemTemp.path, 'hc_play_controls_overlay_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
}

Widget _wrap() => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const PlayScreen(),
    );

void main() {
  late MockHanumanAudioHandler handler;
  late StreamController<PlayerState> playerStateCtrl;
  late StreamController<Duration> positionCtrl;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Duration.zero);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  setUp(() {
    _freshRepo();
    handler = MockHanumanAudioHandler();
    playerStateCtrl = StreamController<PlayerState>.broadcast();
    positionCtrl = StreamController<Duration>.broadcast();
    when(() => handler.playerStateStream).thenAnswer((_) => playerStateCtrl.stream);
    when(() => handler.positionStream).thenAnswer((_) => positionCtrl.stream);
    when(() => handler.duration).thenReturn(const Duration(minutes: 10));
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump();
  }

  group('volume overlay', () {
    testWidgets('toggles open/close and auto-hides', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
      await tester.pump();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
      await tester.pump();
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    });
  });

  group('speed overlay', () {
    testWidgets('opens, closes and updates speed label', (tester) async {
      await pump(tester);
      await tester.tap(find.text('1×'));
      await tester.pump();
      expect(find.text('5×'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider).last);
      slider.onChanged?.call(2.0);
      await tester.pump();
      expect(find.text('2×'), findsOneWidget);
      await tester.tap(find.text('2×'));
      await tester.pump();
      expect(find.text('5×'), findsNothing);
    });
  });

  group('play/pause controls', () {
    testWidgets('play button calls play()', (tester) async {
      await pump(tester);
      clearInteractions(handler);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      verify(() => handler.play()).called(1);
    });

    testWidgets('pause button calls pause()', (tester) async {
      await pump(tester);
      playerStateCtrl.add(PlayerState(true, ProcessingState.ready));
      await tester.pump();
      await tester.pump();
      clearInteractions(handler);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      verify(() => handler.pause()).called(1);
    });
  });
}
