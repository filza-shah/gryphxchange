import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_header.dart';

// HomePage is a ConsumerWidget so it can access Riverpod providers
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: '/home'),
      body: Column( 
        children: [
          const AppHeader(title: 'Listings'), // custom app header
          Expanded(
            child: Center (
              child: FilledButton(
                onPressed: () {
                  // Set authentication state to false (logged out)
                  ref.read(authProvider.notifier).state = false;
                  // Navigate to the login page
                  context.go('/login');
                },
                child: const Text('Logout'), // Button label
              )

            )
          )
        ]
      )
    );
  }
}