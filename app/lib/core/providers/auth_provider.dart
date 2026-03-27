import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

// Shared AuthService instance for dependency injection in feature screens.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Exposes Firebase auth changes as AsyncValue<User?> throughout the app.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChange();
});