import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  String? _resendMessage;

  Future<void> _resendVerification() async {
    setState(() {
      _isResending    = true;
      _resendMessage  = null;
    });

    final result = await AuthService.instance
        .resendVerification(email: widget.email);

    if (!mounted) return;

    setState(() {
      _isResending   = false;
      _resendMessage = result.success
          ? 'Verification email sent! Check your inbox.'
          : result.message ?? 'Failed to resend. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Icon ─────────────────────────────────
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────
              const Text(
                'Check Your Email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // ── Subtitle ─────────────────────────────
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a verification link to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(
                        text:
                            '\n\nPlease verify your email before logging in.'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ── Resend feedback ───────────────────────
              if (_resendMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _resendMessage!.contains('sent')
                        ? Colors.green.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _resendMessage!.contains('sent')
                          ? Colors.green
                          : AppColors.error,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _resendMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _resendMessage!.contains('sent')
                          ? Colors.green.shade700
                          : AppColors.error,
                    ),
                  ),
                ),

              // ── Go to Login ───────────────────────────
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Go to Login'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Resend button ─────────────────────────
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isResending ? null : _resendVerification,
                  child: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Text('Resend Verification Email'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}