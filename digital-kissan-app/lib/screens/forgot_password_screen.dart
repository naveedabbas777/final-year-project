import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _auth = AuthService();

  bool _sending = false;

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return _t(
          'Please enter a valid email address.',
          'براہ کرم درست ای میل ایڈریس درج کریں۔',
        );
      case 'operation-not-allowed':
        return _t(
          'Password reset is currently disabled in Firebase.',
          'فائر بیس میں پاس ورڈ ری سیٹ فی الحال غیر فعال ہے۔',
        );
      case 'network-request-failed':
        return _t(
          'Network issue detected. Please check internet and try again.',
          'نیٹ ورک مسئلہ ہے۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
        );
      case 'too-many-requests':
        return _t(
          'Too many attempts. Please wait a moment and try again.',
          'بہت زیادہ کوششیں ہو چکی ہیں۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
        );
      case 'user-not-found':
        return _t(
          'No account found for this email. Please register first.',
          'اس ای میل پر کوئی اکاؤنٹ نہیں ملا۔ پہلے رجسٹر کریں۔',
        );
      default:
        return e.message ??
            _t(
              'Could not send reset email. Please try again.',
              'ری سیٹ ای میل نہیں بھیجی جا سکی۔ دوبارہ کوشش کریں۔',
            );
    }
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (!_looksLikeEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Please enter a valid email address',
              'براہ کرم درست ای میل ایڈریس درج کریں',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(_t('Reset email sent', 'ری سیٹ ای میل بھیج دی گئی')),
              content: Text(
                _t(
                  'If this email is registered, a password reset link has been sent to $email.',
                  'اگر یہ ای میل رجسٹرڈ ہے تو $email پر پاس ورڈ ری سیٹ لنک بھیج دیا گیا ہے۔',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t('OK', 'ٹھیک ہے')),
                ),
              ],
            ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Could not send reset email. Please try again.',
              'ری سیٹ ای میل نہیں بھیجی جا سکی۔ دوبارہ کوشش کریں۔',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Forgot Password', 'پاس ورڈ بھول گئے')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t('Reset your password', 'اپنا پاس ورڈ ری سیٹ کریں'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Enter your email address and we will send you a reset link.',
                      'اپنا ای میل ایڈریس درج کریں، ہم آپ کو ری سیٹ لنک بھیجیں گے۔',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      labelText: _t('Email', 'ای میل'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _sendResetLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon:
                        _sending
                            ? const CompactLoadingIndicator(
                              size: 16,
                              color: Colors.white,
                            )
                            : const Icon(Icons.send),
                    label: Text(_t('Send reset link', 'ری سیٹ لنک بھیجیں')),
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
