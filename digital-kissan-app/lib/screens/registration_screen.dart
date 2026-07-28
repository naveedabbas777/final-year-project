import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/utils/form_validators.dart';
import 'package:mockup_app/utils/error_presenter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
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
  final _countryCodes = [
    '+92',
    '+1',
    '+44',
    '+91',
    '+86',
    '+81',
    '+33',
    '+39',
    '+34',
  ];

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _startRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final fullPhone = phone.isNotEmpty ? '$_countryCode$phone' : '';
    final pass = _passController.text;
    final confirmPass = _confirmPassController.text;

    // Validation using form validators
    final nameError = FormValidators.validateName(name);
    if (nameError != null) {
      _showError(nameError);
      return;
    }

    final emailError = FormValidators.validateEmail(email);
    if (emailError != null) {
      _showError(emailError);
      return;
    }

    final phoneError = FormValidators.validatePhone(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    final passwordError = FormValidators.validatePassword(pass);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }

    if (pass != confirmPass) {
      _showError(_t('Passwords do not match', 'پاس ورڈز ایک جیسے نہیں ہیں'));
      return;
    }

    setState(() => _sending = true);

    try {
      // Step 1: Create Firebase account with email and password
      debugPrint('Step 1: Creating Firebase account...');
      try {
        await _auth
            .registerWithEmailPassword(email: email, password: pass)
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Firebase account creation error: $e');
        final message = ErrorPresenter.present(e);
        _showError(message);
        if (mounted) setState(() => _sending = false);
        return;
      }

      // Get current user directly from FirebaseAuth (avoids Pigeon call)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError(
          _t(
            'Account created but verification failed. Please login manually.',
            'اکاؤنٹ بن گیا لیکن تصدیق ناکام رہی۔ براہ کرم دستی طور پر لاگ ان کریں۔',
          ),
        );
        if (mounted) setState(() => _sending = false);
        return;
      }

      debugPrint('Step 2: Account created. User UID: ${user.uid}');

      // Step 3: Update user profile in Firestore (non-critical)
      try {
        // Ensure a Firestore user document exists with a default role of "farmer".
        // Some environments may not create this immediately via the backend,
        // so write the minimal document here (merge=true so backend fields stay intact).
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'firebaseUid': user.uid,
            'email': user.email ?? null,
            'displayName': name.isNotEmpty ? name : (user.displayName ?? null),
            'phoneNumber': fullPhone.isNotEmpty ? fullPhone : (user.phoneNumber ?? null),
            'role': 'farmer',
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ).timeout(const Duration(seconds: 15));
        // Also call backend-friendly update to ensure consistency.
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
      _showError('${_t('Registration failed', 'رجسٹریشن ناکام')}: ${e.toString()}');
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                  Text(
                    _t('Create an account', 'اکاؤنٹ بنائیں'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person),
                      labelText: _t('Full name', 'پورا نام'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      labelText: _t('Email', 'ای میل'),
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
                            labelText: _t('Country', 'ملک'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          items:
                              _countryCodes
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(code),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null)
                              setState(() => _countryCode = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          cursorColor: AppColors.primaryMid,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone),
                            labelText: _t('Phone number', 'فون نمبر'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: _t('e.g., 3001234567', 'مثال: 3001234567'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: _t('Password', 'پاس ورڈ'),
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
                    style: const TextStyle(color: AppColors.textPrimary),
                    cursorColor: AppColors.primaryMid,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: _t('Confirm password', 'پاس ورڈ کی تصدیق'),
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
                              ? const CompactLoadingIndicator(
                                size: 16,
                                color: Colors.white,
                              )
                              : const Icon(Icons.person_add),
                      label: Text(_t('Register', 'رجسٹر کریں')),
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
