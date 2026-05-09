import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';

// PHASE 1: Explicit auth bootstrap state to avoid startup race conditions
enum AuthBootstrapState { unknown, authenticated, unauthenticated }

/// Enhanced ChangeNotifier that exposes the current [User?] and ensures a
/// per-user Firestore document exists when a user signs in.
///
/// PHASE 1 FIX: Added explicit bootstrap state to prevent race conditions
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firestoreService = FirebaseService();

  User? _user;
  AuthBootstrapState _bootstrapState = AuthBootstrapState.unknown;
  StreamSubscription<User?>? _sub;
  Timer? _bootstrapFallbackTimer;

  AuthProvider() {
    _sub = _auth.authStateChanges().listen(_onAuthStateChanged);

    // Fail-safe bootstrap: resolve quickly from current user and avoid
    // indefinite splash if the auth stream event is delayed on startup.
    Future.microtask(() {
      if (_bootstrapState != AuthBootstrapState.unknown) return;
      _user = _auth.currentUser;
      _bootstrapState =
          _user != null
              ? AuthBootstrapState.authenticated
              : AuthBootstrapState.unauthenticated;
      notifyListeners();
    });

    _bootstrapFallbackTimer = Timer(const Duration(seconds: 5), () {
      if (_bootstrapState != AuthBootstrapState.unknown) return;
      _user = _auth.currentUser;
      _bootstrapState =
          _user != null
              ? AuthBootstrapState.authenticated
              : AuthBootstrapState.unauthenticated;
      notifyListeners();
    });
  }

  User? get user => _user;

  bool get isSignedIn => _user != null;

  AuthBootstrapState get bootstrapState => _bootstrapState;

  /// Returns true only after bootstrap is complete
  bool get isBootstrapComplete => _bootstrapState != AuthBootstrapState.unknown;

  Future<void> _onAuthStateChanged(User? u) async {
    _bootstrapFallbackTimer?.cancel();
    _user = u;

    // Update bootstrap state based on auth result
    if (u != null) {
      _bootstrapState = AuthBootstrapState.authenticated;
    } else {
      _bootstrapState = AuthBootstrapState.unauthenticated;
    }

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

  /// Centralized sign-out with full bootstrap reset
  /// PHASE 1 FIX: Unified sign-out behavior
  Future<void> signOut() async {
    // Unregister FCM token so logged-out user stops receiving notifications
    try {
      await PushService.instance.dispose();
    } catch (_) {
      // Don't block sign-out if token cleanup fails
    }
    // Set unauthenticated (not unknown) so AppRouter goes straight to LoginScreen
    // without flashing the SplashScreen during the brief gap before Firebase
    // authStateChanges() fires.
    _user = null;
    _bootstrapState = AuthBootstrapState.unauthenticated;
    notifyListeners();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _bootstrapFallbackTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
