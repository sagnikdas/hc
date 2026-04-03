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
import 'package:hanuman_chalisa_app/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa_app/features/play/play_screen.dart';
import 'package:hanuman_chalisa_app/main.dart' show audioHandlerNotifier, isPlayScreenOpen;

class MockHanumanAudioHandler extends Mock implements HanumanAudioHandler {}

int _dbUid = 0;

AppRepository _freshRepo() {
  final path = p.join(Directory.systemTemp.path, 'hc_play_render_audio_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
  AppRepository.resetForTest();
  final repo = AppRepository.instance;
  repo.overrideSyncForTest(isSignedIn: () => false, syncCompletion: (_) async {});
  return repo;
}

Widget _wrap({String? initialVoice}) => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: PlayScreen(initialVoice: initialVoice),
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
    handler = MockHanumanAudioHandler();
    playerStateCtrl = StreamController<PlayerState>.broadcast();
    positionCtrl = StreamController<Duration>.broadcast();
    _freshRepo();
    when(() => handler.playerStateStream).thenAnswer((_) => playerStateCtrl.stream);
    when(() => handler.positionStream).thenAnswer((_) => positionCtrl.stream);
    when(() => handler.duration).thenReturn(Duration.zero);
    when(() => handler.position).thenReturn(Duration.zero);
    when(() => handler.playing).thenReturn(false);
    when(() => handler.volume).thenReturn(1.0);
    when(() => handler.speed).thenReturn(1.0);
    when(() => handler.currentAssetPath).thenReturn('assets/audio/hc_male_final.mp3');
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

  Future<void> pump(WidgetTester tester, {String? initialVoice}) async {
    await tester.pumpWidget(_wrap(initialVoice: initialVoice));
    await tester.pump();
    await tester.pump();
  }

  group('rendering', () {
    testWidgets('shows spinner when handler is null', (tester) async {
      audioHandlerNotifier.value = null;
      await tester.pumpWidget(_wrap());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('shows player once handler is available', (tester) async {
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('audio initialisation', () {
    testWidgets('loadVoice + play called when duration is zero (fresh load)', (tester) async {
      await pump(tester);
      verify(() => handler.loadVoice(any())).called(1);
      verify(() => handler.play()).called(1);
    });

    testWidgets('uses initialVoice track id when provided', (tester) async {
      const voice = 'male';
      await pump(tester, initialVoice: voice);
      final captured = verify(() => handler.loadVoice(captureAny())).captured;
      expect(captured.last, 'assets/audio/hc_male_final.mp3');
    });

    testWidgets('loadVoice and play are skipped when matching audio is already loaded (>0 duration)', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      await pump(tester);
      verifyNever(() => handler.loadVoice(any()));
      verifyNever(() => handler.play());
    });

    testWidgets('reloads and plays when loaded audio does not match selected track', (tester) async {
      when(() => handler.duration).thenReturn(const Duration(minutes: 10));
      when(() => handler.currentAssetPath).thenReturn('assets/audio/hc_female_final.mp3');
      await pump(tester, initialVoice: 'male');
      verify(() => handler.loadVoice('assets/audio/hc_male_final.mp3')).called(1);
      verify(() => handler.play()).called(1);
    });

    testWidgets('initialises via listener when handler is null at widget build time', (tester) async {
      audioHandlerNotifier.value = null;
      await tester.pumpWidget(_wrap());
      await tester.pump();
      verifyNever(() => handler.loadVoice(any()));
      audioHandlerNotifier.value = handler;
      await tester.pump();
      await tester.pump();
      verify(() => handler.loadVoice(any())).called(1);
    });

    testWidgets('listener is removed after first handler set — second change ignored', (tester) async {
      audioHandlerNotifier.value = null;
      await tester.pumpWidget(_wrap());
      await tester.pump();
      audioHandlerNotifier.value = handler;
      await tester.pump();
      await tester.pump();

      final handler2 = MockHanumanAudioHandler();
      when(() => handler2.playerStateStream).thenAnswer((_) => const Stream.empty());
      when(() => handler2.positionStream).thenAnswer((_) => const Stream.empty());
      when(() => handler2.duration).thenReturn(Duration.zero);
      when(() => handler2.loadVoice(any())).thenAnswer((_) async {});
      when(() => handler2.play()).thenAnswer((_) async {});
      when(() => handler2.setSpeed(any())).thenAnswer((_) async {});
      when(() => handler2.volume).thenReturn(1.0);
      audioHandlerNotifier.value = handler2;
      await tester.pump();
      await tester.pump();
      verifyNever(() => handler2.loadVoice(any()));
    });

    testWidgets('audioInitialized guard prevents double-init when handler is replaced', (tester) async {
      await pump(tester);
      audioHandlerNotifier.value = handler;
      await tester.pump();
      verify(() => handler.loadVoice(any())).called(1);
    });

  });
}
