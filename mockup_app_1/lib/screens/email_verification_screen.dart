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
          const SnackBar(content: Text('Email verified successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is not verified yet.')),
        );
      }
    } catch (e) {
      debugPrint('[EmailVerification] Error checking verification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check verification right now.'),
        ),
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
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[EmailVerification] Firebase error resending email: ${e.code} - ${e.message}',
      );
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'too-many-requests':
          message = 'Too many requests. Please try again in a moment.';
          break;
        case 'network-request-failed':
          message = 'Network issue detected. Please check internet and retry.';
          break;
        default:
          message = e.message ?? 'Could not resend verification email.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('[EmailVerification] Error resending email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend verification email.')),
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
            ? 'Email verified'
            : (_checking
                ? 'Checking verification status...'
                : 'Email not verified yet');

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Email Verification'),
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
                    const Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A verification link was sent to ${widget.email}. Open your inbox and verify your account.',
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
                      label: const Text('Resend verification email'),
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
                      label: const Text('I have verified, check now'),
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
                      child: const Text('Continue to login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _finishAndReturn(verified: false),
                      child: const Text('Back to login'),
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
