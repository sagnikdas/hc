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
import 'package:hanuman_chalisa_app/features/play/play_screen.dart';
import 'package:hanuman_chalisa_app/main.dart' show audioHandlerNotifier, isPlayScreenOpen;

class MockHanumanAudioHandler extends Mock implements HanumanAudioHandler {}

int _dbUid = 0;

void _freshDb() {
  final path = p.join(Directory.systemTemp.path, 'hc_play_dispose_${_dbUid++}.db');
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  DatabaseHelper.resetForTest(path);
}

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
    _freshDb();
    handler = MockHanumanAudioHandler();
    playerStateCtrl = StreamController<PlayerState>.broadcast();
    positionCtrl = StreamController<Duration>.broadcast();
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

  testWidgets('isPlayScreenOpen flips false on dispose', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(isPlayScreenOpen.value, true);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(isPlayScreenOpen.value, false);
  });

  testWidgets('timers and subscriptions do not throw after dispose', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const PlayScreen(),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 5));
    expect(() => playerStateCtrl.add(PlayerState(true, ProcessingState.completed)), returnsNormally);
  });
}
