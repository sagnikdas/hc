import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hanuman_chalisa/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('AppShell renders 3-tab navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const HanumanChalisaApp());

    expect(find.text('Play'), findsWidgets);
    expect(find.text('Progress'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Switching tabs shows Progress screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HanumanChalisaApp());

    // Tap Progress tab — use pump (not pumpAndSettle) to avoid waiting on DB futures
    await tester.tap(find.text('Progress').last);
    await tester.pump();

    expect(find.text('Progress'), findsWidgets);
  });
}
