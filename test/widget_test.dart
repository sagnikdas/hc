import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanuman_chalisa/main.dart';

void main() {
  testWidgets('App renders minimal player', (WidgetTester tester) async {
    await tester.pumpWidget(const HanumanChalisaApp());

    expect(find.text('Hanuman Chalisa'), findsWidgets);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
