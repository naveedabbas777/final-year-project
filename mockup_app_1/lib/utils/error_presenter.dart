import 'dart:async';
import 'dart:io';
import 'dart:convert';

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

    // Check for structured backend error response
    if (message.contains('"error"') || message.contains('"code"')) {
      return _parseStructuredError(message);
    }

    // Upload-specific errors
    if (message.contains('upload') || message.contains('Upload')) {
      return _presentUploadError(message);
    }

    // Validation errors
    if (message.contains('validation') || message.contains('Validation')) {
      return _presentValidationError(message);
    }

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
    if (message.contains('409')) {
      return 'This resource already exists.';
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

  static String _presentUploadError(String message) {
    if (message.contains('Image too large')) {
      return 'Image is too large. Maximum size is 5 MB.';
    }
    if (message.contains('Only image')) {
      return 'Only image files are allowed.';
    }
    if (message.contains('Cloudinary')) {
      return 'Failed to upload image to cloud storage. Please try again.';
    }
    if (message.contains('timeout')) {
      return 'Image upload timed out. Please try again.';
    }
    return 'Failed to upload image. Please try again.';
  }

  static String _presentValidationError(String message) {
    if (message.contains('required')) {
      return 'Please fill in all required fields.';
    }
    if (message.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('crop')) {
      return 'Crop name must be 2-50 characters and alphanumeric.';
    }
    if (message.contains('quantity')) {
      return 'Quantity must be between 0.1 and 999999.';
    }
    if (message.contains('price')) {
      return 'Price must be between 0.01 and 999999.';
    }
    return 'Please check your input and try again.';
  }

  static String _parseStructuredError(String message) {
    try {
      // Try to extract JSON from error message
      final start = message.indexOf('{');
      final end = message.lastIndexOf('}');
      if (start > -1 && end > -1) {
        final json = jsonDecode(message.substring(start, end + 1)) as Map<String, dynamic>;
        if (json['error'] is String) {
          return json['error'] as String;
        }
      }
    } catch (e) {
      // Ignore JSON parsing errors
    }
    return present(message);
  }
}
