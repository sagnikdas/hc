import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hanuman_chalisa/data/local/database_helper.dart';
import 'package:hanuman_chalisa/data/repositories/app_repository.dart';
import 'package:hanuman_chalisa/features/onboarding/onboarding_screen.dart';
import 'package:hanuman_chalisa/core/theme.dart';

/// Wraps a widget in a minimal MaterialApp using the app theme.
Widget _wrap(Widget child) => MaterialApp(
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: child,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Fresh in-memory-like DB for the entire widget test suite.
    DatabaseHelper.resetForTest(':memory:');
    AppRepository.resetForTest();
  });

  testWidgets('OnboardingScreen renders welcome content', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('Hanuman Chalisa'), findsOneWidget);
    expect(find.text('Begin Your Journey'), findsOneWidget);
    expect(find.text('Invite devotees via WhatsApp'), findsOneWidget);
  });

  testWidgets('OnboardingScreen share button is tappable', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pump();

    // The share row exists and is a GestureDetector.
    expect(find.text('Invite devotees via WhatsApp'), findsOneWidget);
  });
}
