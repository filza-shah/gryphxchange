// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/providers/workflow_provider.dart';
import 'package:app/main.dart';
import 'package:app/services/workflow/workflow_controller.dart';

void main() {
  testWidgets('Loads login screen', (WidgetTester tester) async {
    final WorkflowController workflowController = WorkflowController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          workflowControllerProvider.overrideWithValue(workflowController),
        ],
        child: const GryphXChangeApp(),
      ),
    );

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
