import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'email_verification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback? onRegistered;
  const RegistrationScreen({Key? key, this.onRegistered}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  String _countryCode = '+92'; // Pakistan default
  final _auth = AuthService();
  final _firebaseService = FirebaseService();

  bool _sending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Common country codes
  final _countryCodes = ['+92', '+1', '+44', '+91', '+86', '+81', '+33', '+39', '+34'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _friendlyRegistrationError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login or use forgot password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password registration is currently disabled in Firebase.';
      case 'network-request-failed':
        return 'Network issue detected. Please check internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Registration failed. Please try again.';
    }
  }

  Future<void> _startRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final fullPhone = phone.isNotEmpty ? '$_countryCode$phone' : '';
    final pass = _passController.text;
    final confirmPass = _confirmPassController.text;

    // Validation
    if (name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }

    if (!_looksLikeEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    if (pass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (pass != confirmPass) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _sending = true);

    try {
      // Step 1: Create Firebase account with email and password
      debugPrint('Step 1: Creating Firebase account...');
      UserCredential? cred;
      try {
        cred = await _auth.registerWithEmailPassword(
          email: email,
          password: pass,
        ).timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Firebase account creation error: $e');
        if (e is TimeoutException) {
          _showError('Account creation timed out. Check your internet connection and try again.');
        } else if (e is FirebaseAuthException) {
          _showError(_friendlyRegistrationError(e));
        } else {
          _showError('Failed to create account: ${e.toString()}');
        }
        if (mounted) setState(() => _sending = false);
        return;
      }

      // Get current user directly from FirebaseAuth (avoids Pigeon call)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Account created but verification failed. Please login manually.');
        if (mounted) setState(() => _sending = false);
        return;
      }

      debugPrint('Step 2: Account created. User UID: ${user.uid}');

      // Step 3: Update user profile in Firestore (non-critical)
      try {
        await _firebaseService.createUserIfNotExists(
          user,
          displayName: name,
          phoneNumber: fullPhone,
        ).timeout(const Duration(seconds: 15));
        debugPrint('Step 3: User profile saved to Firestore');
      } catch (e) {
        debugPrint('Warning: Could not save to Firestore: $e');
        // Continue anyway, user data will be saved on next login
      }

      // Step 4: Send verification email (non-critical)
      try {
        await _auth.sendCurrentUserVerificationEmail().timeout(
          const Duration(seconds: 15),
        );
        debugPrint('Step 4: Verification email sent');
      } catch (e) {
        debugPrint('Warning: Could not send verification email: $e');
        // Continue anyway
      }

      // Step 5: Navigate to Email Verification Screen
      if (!mounted) return;
      debugPrint('Step 5: Navigating to email verification screen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    } catch (e) {
      debugPrint('Unexpected error during registration: $e');
      _showError('Registration failed: ${e.toString()}');
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(
                      Icons.person_add,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Create an account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      labelText: 'Full name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          value: _countryCode,
                          decoration: InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          items: _countryCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _countryCode = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone),
                            labelText: 'Phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'e.g., 3001234567',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                            () =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon:
                          _sending
                              ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.person_add),
                      label: const Text('Register'),
                      onPressed: _sending ? null : _startRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
