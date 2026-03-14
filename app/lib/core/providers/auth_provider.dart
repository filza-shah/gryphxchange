import 'package:flutter_riverpod/flutter_riverpod.dart';

// Riverpod StateProvider to hold the user's authentication status.
// false = not authenticated, true = authenticated.
final authProvider = StateProvider<bool>((ref) => false);