import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthService] Starting registration for $email');
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] Registration successful for $email');
      return result;
    } catch (e) {
      debugPrint('[AuthService] Registration error: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthService] Starting sign-in for $email');
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] Sign-in successful for $email');
      return result;
    } catch (e) {
      debugPrint('[AuthService] Sign-in error: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendCurrentUserVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found to verify email.');
    }
    await user.sendEmailVerification();
  }

  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    await user?.reload();
    return _auth.currentUser;
  }
}
