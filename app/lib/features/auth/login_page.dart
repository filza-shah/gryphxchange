import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

//LoginPage is a ConsumerWidget so it can access Riverpod providers
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        //center login button
        child: FilledButton(
          onPressed: () {
            // Set authentication state to true (logged in)
            ref.read(authProvider.notifier).state = true;
            // Navigate to the home page using GoRouter
            context.go('/home');
          },
          child: const Text('Login'), // Text displayed on the button
        ),
      ),
    );
  }
}