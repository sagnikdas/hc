// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hanuman_chalisa_app/core/lyrics_service.dart';
import 'package:hanuman_chalisa_app/core/theme.dart';
import 'package:hanuman_chalisa_app/features/recitation/recitation_screen.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

// ── Test fixtures ─────────────────────────────────────────────────────────────

const _kLines = [
  LyricsLine(
    startSeconds: 2.75,
    text: '॥ दोहा ॥',
    transliteration: '|| Doha ||',
  ),
  LyricsLine(
    startSeconds: 2.75,
    text: 'श्रीगुरु चरन सरोज रज, निज मनु मुकुरु सुधारि।',
    transliteration: 'Shri Guru Charan Saroj Raj, Nij Man Mukur Sudhari,',
  ),
  LyricsLine(
    startSeconds: 14.45,
    text: 'बरनउँ रघुबर बिमल जसु, जो दायकु फल चारि॥',
    transliteration: 'Baranau Raghubar Bimal Jasu, Jo Dayaku Phal Chari.',
  ),
  LyricsLine(
    startSeconds: 56.57,
    text: '॥ चौपाई ॥',
    transliteration: '|| Chaupai ||',
  ),
  LyricsLine(
    startSeconds: 56.57,
    text: 'जय हनुमान ज्ञान गुन सागर।',
    transliteration: 'Jai Hanuman Gyan Gun Sagar,',
  ),
  LyricsLine(
    startSeconds: 62.27,
    text: 'जय कपीस तिहुँ लोक उजागर॥ १॥',
    transliteration: 'Jai Kapees Tihu Lok Ujagar. (1)',
  ),
];

// ── Widget helpers ─────────────────────────────────────────────────────────────

Widget _wrap({
  List<LyricsLine>? lines,
  List<NavigatorObserver> observers = const [],
}) =>
    MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      navigatorObservers: observers,
      home: RecitationScreen(debugLines: lines ?? _kLines),
    );

void _portraitView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Silence platform-channel calls (share_plus, haptics, SystemUI).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    registerFallbackValue(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
  });

  // ── 1. Initial render ──────────────────────────────────────────────────────

  group('initial render', () {
    testWidgets('screen title is Voice Recitation', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voice Recitation'), findsOneWidget);
    });

    testWidgets('back button is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('share button is present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('language toggle pills are present', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('हि'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('Hindi lyrics are shown by default', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('जय हनुमान ज्ञान गुन सागर।'), findsOneWidget);
    });

    testWidgets('section headers are rendered', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('॥ दोहा ॥'), findsOneWidget);
      expect(find.text('॥ चौपाई ॥'), findsOneWidget);
    });

    testWidgets('all verse lines are visible', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('श्रीगुरु चरन'), findsOneWidget);
      expect(find.textContaining('बरनउँ रघुबर'), findsOneWidget);
      expect(find.textContaining('जय कपीस'), findsOneWidget);
    });

    testWidgets('empty lyrics shows OM fallback (no lyrics list)', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap(lines: []));
      await tester.pumpAndSettle();
      // Empty state: no ListView (list is replaced by the OM center widget).
      // The background OM watermark + the content OM both render, so we
      // assert findsWidgets (≥1) rather than findsOneWidget.
      expect(find.text('ॐ'), findsWidgets);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('empty lyrics does not show toggle', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap(lines: []));
      await tester.pumpAndSettle();
      expect(find.text('EN'), findsNothing);
    });

    testWidgets('lyrics list is scrollable', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // ── 2. Language toggle ─────────────────────────────────────────────────────

  group('language toggle', () {
    testWidgets('tapping EN switches to English transliteration', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Jai Hanuman Gyan Gun Sagar,'), findsOneWidget);
    });

    testWidgets('tapping EN hides Hindi verse text', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('जय हनुमान ज्ञान गुन सागर।'), findsNothing);
    });

    testWidgets('tapping EN shows English section headers', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('|| Doha ||'), findsOneWidget);
      expect(find.text('|| Chaupai ||'), findsOneWidget);
    });

    testWidgets('tapping हि after EN switches back to Hindi', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('हि'));
      await tester.pumpAndSettle();
      expect(find.text('जय हनुमान ज्ञान गुन सागर।'), findsOneWidget);
      expect(find.text('Jai Hanuman Gyan Gun Sagar,'), findsNothing);
    });

    testWidgets('toggle not shown when no transliterations exist', (tester) async {
      _portraitView(tester);
      final linesNoEn = [
        const LyricsLine(startSeconds: 0, text: 'श्रीगुरु चरन सरोज रज'),
      ];
      await tester.pumpWidget(_wrap(lines: linesNoEn));
      await tester.pumpAndSettle();
      expect(find.text('EN'), findsNothing);
      expect(find.text('हि'), findsNothing);
    });

    testWidgets('Hindi is selected by default in the toggle', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // The हि pill should have primary background (selected) and EN should not.
      // We verify the state indirectly: Hindi text is visible.
      expect(find.text('॥ दोहा ॥'), findsOneWidget); // Hindi header
      expect(find.text('|| Doha ||'), findsNothing);  // English header absent
    });
  });

  // ── 3. Language toggle — null transliteration fallback ────────────────────

  group('null transliteration fallback', () {
    testWidgets('line with null transliteration shows Hindi in EN mode',
        (tester) async {
      _portraitView(tester);
      final mixedLines = [
        const LyricsLine(
          startSeconds: 0,
          text: 'हिंदी पंक्ति',
          transliteration: 'Hindi Line',
        ),
        // No transliteration — must fall back to Hindi even in EN mode.
        const LyricsLine(startSeconds: 5, text: 'बिना अनुवाद'),
      ];
      await tester.pumpWidget(_wrap(lines: mixedLines));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Hindi Line'), findsOneWidget);
      expect(find.text('बिना अनुवाद'), findsOneWidget); // falls back to Hindi
    });
  });

  // ── 4. Navigation ──────────────────────────────────────────────────────────

  group('navigation', () {
    testWidgets('back button pops the route', (tester) async {
      _portraitView(tester);
      final observer = _MockNavigatorObserver();
      await tester.pumpWidget(MaterialApp(
        theme: darkTheme,
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecitationScreen(debugLines: _kLines),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      // Open RecitationScreen.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Voice Recitation'), findsOneWidget);
      // Tap back.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Voice Recitation'), findsNothing);
      verify(() => observer.didPop(any(), any()))
          .called(greaterThanOrEqualTo(1));
    });
  });

  // ── 5. Responsiveness ──────────────────────────────────────────────────────

  group('responsiveness — no overflow on common screen sizes', () {
    for (final size in [
      const Size(320, 568),
      const Size(375, 667),
      const Size(390, 844),
      const Size(412, 915),
      const Size(430, 932),
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
      });
    }
  });

  // ── 6. Edge cases ──────────────────────────────────────────────────────────

  group('edge cases', () {
    testWidgets('single-line lyrics renders without crash', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap(lines: [
        const LyricsLine(
          startSeconds: 0,
          text: 'जय हनुमान',
          transliteration: 'Jai Hanuman',
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('जय हनुमान'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid toggle does not crash', (tester) async {
      _portraitView(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('EN'));
        await tester.pump();
        await tester.tap(find.text('हि'));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero image error fallback keeps UI intact', (tester) async {
      _portraitView(tester);
      // Background image will fail to load in tests (no asset bundle).
      // The errorBuilder should silently swallow the error.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Voice Recitation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('section header at index 0 renders correctly', (tester) async {
      _portraitView(tester);
      // Header as the very first item — no preceding verse padding issue.
      await tester.pumpWidget(_wrap(lines: [
        const LyricsLine(
          startSeconds: 0,
          text: '॥ दोहा ॥',
          transliteration: '|| Doha ||',
        ),
        const LyricsLine(
          startSeconds: 2,
          text: 'जय हनुमान',
          transliteration: 'Jai Hanuman',
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('॥ दोहा ॥'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
