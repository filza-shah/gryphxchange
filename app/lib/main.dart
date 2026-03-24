import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/workflow_provider.dart';
import 'core/router/app_router.dart';
import 'services/workflow/workflow_controller.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// custom color constants for app theme
const Color _gryphRed = Color(0xFF8B0000);
const Color _gryphGold = Color(0xFFFFD700);
const Color _shellBackground = Color(0xFF101114);
const Color _pageBackground = Color(0xFFF5F5F5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with current platform options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final WorkflowController workflowController = WorkflowController();
  await workflowController.init();

  runApp(
    ProviderScope(
      overrides: <Override>[
        workflowControllerProvider.overrideWithValue(workflowController),
      ],
      child: const GryphXChangeApp(),
    ),
  );
}

class GryphXChangeApp extends ConsumerWidget {
  const GryphXChangeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // overall app theme
    final ThemeData theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gryphRed,
        primary: _gryphRed, // main color for app elements
        secondary: _gryphGold, // accent color for highlights
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _gryphRed, // AppBar background color
        foregroundColor: Colors.white, // AppBar text and icon color
      ),
      // filled button style
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gryphRed,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ), // button text style
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              10,
            ), // rounded corners for buttons
          ),
        ),
      ),
      // rounded card with with white background color and elevation
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
      ),
    );

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'GryphXChange',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        return Container(
          color: _shellBackground,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Material(
                color: theme.scaffoldBackgroundColor,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
