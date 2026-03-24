import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChange() => _auth.authStateChanges(); // Stream to listen for auth state changes

  // lets users sign in with email and password
  Future<UserCredential> signIn({ required String email, required String password }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // lets users sign up with email and password
  Future<UserCredential> signUp({ required String email, required String password }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // lets users sign out
  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser; // gets the currently signed-in user, if any
}