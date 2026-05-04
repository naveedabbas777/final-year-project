import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Converts exceptions and error codes to user-friendly messages
class ErrorPresenter {
  /// Presents an exception as a user-friendly message
  static String present(dynamic error) {
    if (error is FirebaseAuthException) {
      return _presentFirebaseAuthError(error);
    }

    if (error is SocketException) {
      return 'Connection failed. Please check your internet connection and try again.';
    }

    if (error is TimeoutException) {
      return 'Request timed out. The service is slow or unreachable. Please try again.';
    }

    if (error is HttpException) {
      return 'Network error occurred. Please try again.';
    }

    final message = error.toString();

    // HTTP status codes
    if (message.contains('400')) {
      return 'Invalid request. Please check your input.';
    }
    if (message.contains('401')) {
      return 'Your session expired. Please log in again.';
    }
    if (message.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (message.contains('404')) {
      return 'The requested resource was not found.';
    }
    if (message.contains('429')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (message.contains('500')) {
      return 'Server error. Please try again later.';
    }
    if (message.contains('503')) {
      return 'Service unavailable. Please try again later.';
    }

    // Generic fallback
    return 'An error occurred. Please try again.';
  }

  static String _presentFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'The password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account exists with a different sign-in method.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
