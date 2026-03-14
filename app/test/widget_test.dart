// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Loads GryphXChange themed shell', (WidgetTester tester) async {
    await tester.pumpWidget(const GryphXChangeApp());

    expect(find.text('GryphXChange'), findsOneWidget);
    expect(find.text('Theme Imported'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
