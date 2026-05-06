import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

/// Simple ChangeNotifier that exposes the current [User?] and ensures a
/// per-user Firestore document exists when a user signs in.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firestoreService = FirebaseService();

  User? _user;
  StreamSubscription<User?>? _sub;

  AuthProvider() {
    _sub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  User? get user => _user;

  bool get isSignedIn => _user != null;

  Future<void> _onAuthStateChanged(User? u) async {
    _user = u;
    notifyListeners();

    if (u != null) {
      // Ensure a Firestore user document exists. This is idempotent.
      try {
        await _firestoreService.createUserIfNotExists(u);
      } catch (e) {
        // Don't crash the app on this background operation; log if needed.
        // In production you'd send this to your logging/analytics.
        // ignore: avoid_print
        print('Failed creating user doc: $e');
      }

      // Capture the current FCM token for this user so backend can push alerts.
      try {
        final token = await NotificationService().getFcmToken();
        if (token != null && token.isNotEmpty) {
          await _firestoreService.updateUserNotificationData(
            u.uid,
            fcmToken: token,
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('Failed updating user FCM token: $e');
      }
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
