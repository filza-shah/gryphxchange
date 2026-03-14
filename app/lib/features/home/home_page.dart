import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

// HomePage is a ConsumerWidget so it can access Riverpod providers
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')), // App bar with title
      body: Center(
        // Center the logout button
        child: FilledButton(
          onPressed: () {
            // Set authentication state to false (logged out)
            ref.read(authProvider.notifier).state = false;
            // Navigate to the login page
            context.go('/login');
          },
          child: const Text('Logout'), // Button label
        ),
      ),
    );
  }
}