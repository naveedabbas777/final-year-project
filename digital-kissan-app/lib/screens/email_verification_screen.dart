import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mockup_app/services/auth_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key, required this.email})
    : super(key: key);

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _auth = AuthService();

  bool _checking = false;
  bool _resending = false;
  bool _verified = false;

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _verified = _auth.currentUser?.emailVerified == true;
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    try {
      debugPrint('[EmailVerification] Checking email verification status...');
      final user = await _auth.reloadCurrentUser();
      final verified = user?.emailVerified == true;
      debugPrint('[EmailVerification] Verification status: $verified');
      if (!mounted) return;
      setState(() => _verified = verified);

      if (verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('Email verified successfully.', 'ای میل کامیابی سے تصدیق ہو گئی۔'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Email is not verified yet.', 'ای میل ابھی تک تصدیق شدہ نہیں ہے۔')),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmailVerification] Error checking verification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Could not check verification right now.', 'اس وقت تصدیق چیک نہیں ہو سکی۔'))),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _resending = true);
    try {
      debugPrint('[EmailVerification] Resending verification email...');
      await _auth.sendCurrentUserVerificationEmail();
      debugPrint('[EmailVerification] Verification email sent');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Verification email sent again.', 'تصدیقی ای میل دوبارہ بھیج دی گئی۔'))),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[EmailVerification] Firebase error resending email: ${e.code} - ${e.message}',
      );
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'too-many-requests':
          message = _t(
            'Too many requests. Please try again in a moment.',
            'بہت زیادہ درخواستیں۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
          );
          break;
        case 'network-request-failed':
          message = _t(
            'Network issue detected. Please check internet and retry.',
            'نیٹ ورک مسئلہ ہے۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
          );
          break;
        default:
          message =
              e.message ?? _t('Could not resend verification email.', 'تصدیقی ای میل دوبارہ نہیں بھیجی جا سکی۔');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('[EmailVerification] Error resending email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Could not resend verification email.', 'تصدیقی ای میل دوبارہ نہیں بھیجی جا سکی۔'))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _finishAndReturn({required bool verified}) async {
    if (!verified) {
      // User not verified, sign out and return to login
      await _auth.signOut();
    }
    if (!mounted) return;
    Navigator.of(context).pop(verified);
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        _verified
            ? Colors.green.shade700
            : (_checking ? Colors.orange.shade700 : Colors.red.shade700);
    final Color statusBackground =
        _verified
            ? Colors.green.shade50
            : (_checking ? Colors.orange.shade50 : Colors.red.shade50);
    final IconData statusIcon =
        _verified
            ? Icons.verified
            : (_checking ? Icons.hourglass_top : Icons.mark_email_unread);
    final String statusText =
        _verified
            ? _t('Email verified', 'ای میل تصدیق شدہ')
            : (_checking
                ? _t('Checking verification status...', 'تصدیقی حیثیت چیک کی جا رہی ہے...')
                : _t('Email not verified yet', 'ای میل ابھی تک تصدیق شدہ نہیں'));

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('Email Verification', 'ای میل کی تصدیق')),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        backgroundColor: Colors.green.shade50,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _t('Verify your email', 'اپنی ای میل کی تصدیق کریں'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'A verification link was sent to ${widget.email}. Open your inbox and verify your account.',
                        '${widget.email} پر تصدیقی لنک بھیج دیا گیا ہے۔ اپنا ان باکس کھولیں اور اکاؤنٹ کی تصدیق کریں۔',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _resending ? null : _resendVerificationEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon:
                          _resending
                              ? const CompactLoadingIndicator(
                                size: 16,
                                color: Colors.white,
                              )
                              : const Icon(Icons.email_outlined),
                      label: Text(_t('Resend verification email', 'تصدیقی ای میل دوبارہ بھیجیں')),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _checking ? null : _checkVerification,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon:
                          _checking
                              ? const CompactLoadingIndicator(size: 16)
                              : const Icon(Icons.refresh),
                      label: Text(_t('I have verified, check now', 'میں نے تصدیق کر لی ہے، ابھی چیک کریں')),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed:
                          _verified
                              ? () => _finishAndReturn(verified: true)
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_t('Continue to login', 'لاگ ان جاری رکھیں')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _finishAndReturn(verified: false),
                      child: Text(_t('Back to login', 'لاگ ان پر واپس جائیں')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
