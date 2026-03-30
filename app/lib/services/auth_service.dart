import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Single source for auth session updates (router/providers subscribe here).
  Stream<User?> authStateChange() => _auth.authStateChanges();

  // Email/password sign-in used by the login screen.
  Future<UserCredential> signIn({ required String email, required String password }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Creates a Firebase Auth account; profile document is created elsewhere.
  Future<UserCredential> signUp({ required String email, required String password }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Clears the local auth session and notifies authState listeners.
  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;
}