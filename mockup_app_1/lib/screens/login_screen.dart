import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/utils/error_presenter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:provider/provider.dart';

import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginScreen({Key? key, required this.onLogin}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade100),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
      ),
    );
  }

  Future<void> _attemptLogin() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

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

      try {
        await _auth
            .signInWithEmailPassword(email: email, password: pass)
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Sign in error: $e');
        _showError(ErrorPresenter.present(e));
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Login failed. Please try again.');
        return;
      }

      debugPrint(
        'Login successful. User: ${user.email}, Verified: ${user.emailVerified}',
      );

      if (!user.emailVerified) {
        try {
          await _auth.sendCurrentUserVerificationEmail().timeout(
            const Duration(seconds: 10),
          );
        } catch (e) {
          debugPrint('Could not send verification email: $e');
        }

        if (!mounted) return;

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );

        if (result == true) {
          if (!mounted || _hasNavigated) return;
          _hasNavigated = true;
          widget.onLogin();
        }
        return;
      }

      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      widget.onLogin();
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      _showError(ErrorPresenter.present(e));
    } finally {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.white,
              AppColors.primarySurface,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -36,
                right: -24,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: -42,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Stack(
                          children: [
                            AbsorbPointer(
                              absorbing: _sending,
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.green.shade700,
                                              Colors.green.shade500,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.shade700
                                                  .withOpacity(0.22),
                                              blurRadius: 18,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.agriculture_rounded,
                                          size: 44,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.welcomeMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Sign in to manage crops, alerts, and market activity.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                      controller: _emailController,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      cursorColor: AppColors.primaryMid,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty)
                                          return 'Email is required';
                                        if (!_looksLikeEmail(email))
                                          return 'Enter a valid email address';
                                        return null;
                                      },
                                      decoration: _fieldDecoration(
                                        'Email address',
                                        Icons.email_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      cursorColor: AppColors.primaryMid,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      validator: (value) {
                                        if ((value ?? '').isEmpty)
                                          return 'Password is required';
                                        return null;
                                      },
                                      onFieldSubmitted:
                                          (_) =>
                                              _sending ? null : _attemptLogin(),
                                      decoration: _fieldDecoration(
                                        'Password',
                                        Icons.lock_outline,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () {
                                            setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                                                          (_) =>
                                                              const ForgotPasswordScreen(),
                                                    ),
                                                  );
                                                },
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            _sending ? null : _attemptLogin,
                                        child:
                                            _sending
                                                ? const CompactLoadingIndicator(
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                                : const Text(
                                                  'Login',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    IgnorePointer(
                                      ignoring: _sending,
                                      child: AnimatedOpacity(
                                        opacity: _sending ? 0.55 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Don't have an account?",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                final result = await Navigator.of(
                                                  context,
                                                ).push<String?>(
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const RegistrationScreen(),
                                                  ),
                                                );

                                                if (result != null &&
                                                    result.isNotEmpty &&
                                                    mounted) {
                                                  setState(
                                                    () =>
                                                        _emailController.text =
                                                            result,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
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
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.primaryBorder,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.language,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.languageLabel,
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String>(
                                            value: currentLanguageString,
                                            underline: const SizedBox.shrink(),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'English',
                                                child: Text('English'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Urdu',
                                                child: Text('Urdu'),
                                              ),
                                            ],
                                            onChanged: (String? newValue) {
                                              if (newValue == null) return;
                                              languageProvider.setLocale(
                                                newValue == 'English'
                                                    ? const Locale('en', '')
                                                    : const Locale('ur', ''),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_sending)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.88),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 18,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Signing in…',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
