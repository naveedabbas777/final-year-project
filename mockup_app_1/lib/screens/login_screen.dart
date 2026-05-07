import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/utils/error_presenter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:provider/provider.dart';

import 'forgot_password_screen.dart';
import 'registration_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({Key? key, required this.onLogin}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _sending = false;
  bool _obscurePassword = true;
  bool _hasNavigated = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _attemptLogin() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || !_looksLikeEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (pass.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() => _sending = true);

    try {
      debugPrint('Attempting login with email: $email');

      // Sign in with email and password
      try {
        await _auth
            .signInWithEmailPassword(email: email, password: pass)
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Sign in error: $e');
        _showError(ErrorPresenter.present(e));
        if (mounted) setState(() => _sending = false);
        return;
      }

      // Get current user directly (avoid Pigeon call overhead)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Login failed. Please try again.');
        if (mounted) setState(() => _sending = false);
        return;
      }

      debugPrint(
        'Login successful. User: ${user.email}, Verified: ${user.emailVerified}',
      );

      // Check if email is verified
      if (!user.emailVerified) {
        debugPrint('Email not verified, redirecting to verification screen');

        // Try to send verification email silently
        try {
          await _auth.sendCurrentUserVerificationEmail().timeout(
            const Duration(seconds: 10),
          );
        } catch (e) {
          debugPrint('Could not send verification email: $e');
        }

        if (!mounted) return;

        // Navigate to verification screen
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );

        // result will be true if user verified, false otherwise
        if (result == true) {
          debugPrint('Email verified, proceeding to main app');
          if (!mounted) return;
          if (_hasNavigated) return;
          _hasNavigated = true;
          widget.onLogin();
        } else {
          debugPrint('User did not verify email, staying on login');
        }
        return;
      }

      // Email is verified, proceed to main app
      debugPrint('Proceeding to main app');
      if (!mounted) return;
      if (_hasNavigated) return;
      _hasNavigated = true;
      widget.onLogin();
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      _showError(ErrorPresenter.present(e));
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
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLocale = languageProvider.locale;
    final currentLanguageString =
        currentLocale.languageCode == 'en' ? 'English' : 'Urdu';

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
                      Icons.lock,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.welcomeMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in with email and password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      hintText: 'Email address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      hintText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          _sending
                              ? null
                              : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _sending ? null : _attemptLogin,
                      child:
                          _sending
                              ? const CompactLoadingIndicator(
                                size: 16,
                                color: Colors.white,
                              )
                              : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await Navigator.of(
                            context,
                          ).push<String?>(
                            MaterialPageRoute(
                              builder: (_) => const RegistrationScreen(),
                            ),
                          );

                          if (result != null && result.isNotEmpty && mounted) {
                            setState(() => _emailController.text = result);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Registration successful. Verify your email then login.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.language, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.languageLabel),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: currentLanguageString,
                        items: const [
                          DropdownMenuItem(
                            value: 'English',
                            child: Text('English'),
                          ),
                          DropdownMenuItem(value: 'Urdu', child: Text('Urdu')),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            final newLocale =
                                newValue == 'English'
                                    ? const Locale('en', '')
                                    : const Locale('ur', '');
                            languageProvider.setLocale(newLocale);
                          }
                        },
                      ),
                    ],
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
