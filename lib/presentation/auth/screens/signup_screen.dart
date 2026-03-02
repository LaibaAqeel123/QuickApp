// lib/presentation/auth/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

// ─────────────────────────────────────────────
//  User type enum
//  1 = Customer, 2 = Supplier, 3 = Driver, 4 = Admin
// ─────────────────────────────────────────────
enum UserType { customer, driver }

extension UserTypeExt on UserType {
  String get label {
    switch (this) {
      case UserType.customer: return 'Customer';
      case UserType.driver:   return 'Driver';
    }
  }

  String get apiValue {
    switch (this) {
      case UserType.customer: return '1';
      case UserType.driver:   return '3';
    }
  }

  IconData get icon {
    switch (this) {
      case UserType.customer: return Icons.shopping_bag_outlined;
      case UserType.driver:   return Icons.delivery_dining_outlined;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case UserType.customer: return Icons.shopping_bag;
      case UserType.driver:   return Icons.delivery_dining;
    }
  }

  String get description {
    switch (this) {
      case UserType.customer: return 'Order food from restaurants';
      case UserType.driver:   return 'Deliver orders & earn money';
    }
  }
}

// ─────────────────────────────────────────────
//  SignupScreen
// ─────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey                   = GlobalKey<FormState>();
  final _firstNameController       = TextEditingController();
  final _lastNameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _licenseNumberController   = TextEditingController();
  final _licensePlateController    = TextEditingController();

  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading                = false;
  UserType _selectedType         = UserType.customer;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _licenseNumberController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────
  String? _req(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.length < 7) return 'Enter a valid phone number';
    return null;
  }

  // Always outputs clean E.164 +44XXXXXXXXXX — handles all input variants
  String _formatPhoneForBackend(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+44')) {
      // Guard against +4444... (double country code)
      final digits = cleaned.substring(3);
      if (digits.startsWith('44')) return '+44${digits.substring(2)}';
      return cleaned;
    }
    // 447700123456 — no plus but has country code
    if (cleaned.startsWith('44') && cleaned.length >= 12) return '+$cleaned';
    // 07700123456 — leading zero local format
    if (cleaned.startsWith('0')) return '+44${cleaned.substring(1)}';
    // 7700123456 — bare local number
    return '+44$cleaned';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── Submit ───────────────────────────────────
  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final formattedPhone = _formatPhoneForBackend(_phoneController.text.trim());
    debugPrint('Phone formatted for backend: $formattedPhone');

    final result = await AuthService.instance.register(
      firstName:    _firstNameController.text.trim(),
      lastName:     _lastNameController.text.trim(),
      email:        _emailController.text.trim(),
      password:     _passwordController.text,
      phoneNumber:  formattedPhone,
      userType:     _selectedType.apiValue,
      businessName: '',  // not used for customer/driver — always send empty string
      licenseNumber: _selectedType == UserType.driver
          ? _licenseNumberController.text.trim().toUpperCase()
          : '',
      licensePlate: _selectedType == UserType.driver
          ? _licensePlateController.text.trim().toUpperCase()
          : '',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showEmailVerificationDialog(_emailController.text.trim());
    } else {
      _showSnackbar(
        result.message ?? 'Registration failed. Please try again.',
        isError: true,
      );
    }
  }

  // ── Email Verification Popup ──────────────────
  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EmailVerificationDialog(
        email: email,
        onGoToLogin: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _onTypeChanged(UserType type) {
    setState(() => _selectedType = type);
    type == UserType.driver
        ? _animController.forward()
        : _animController.reverse();
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        size: 40, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create Account',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your details to get started',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ── Role Selector ─────────────────────────
                _sectionLabel('Register as'),
                const SizedBox(height: 10),
                Row(
                  children: UserType.values
                      .map((type) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: type == UserType.customer ? 8 : 0,
                                left:  type == UserType.driver   ? 8 : 0,
                              ),
                              child: _UserTypeCard(
                                type:       type,
                                isSelected: _selectedType == type,
                                onTap:      () => _onTypeChanged(type),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),

                // ── Personal Info ─────────────────────────
                _sectionLabel('Personal Information'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _req(v, 'First name'),
                        decoration: const InputDecoration(
                          labelText:  'First Name',
                          hintText:   'John',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _req(v, 'Last name'),
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          hintText:  'Doe',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    labelText:  'Email',
                    hintText:   'john@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                  decoration: const InputDecoration(
                    labelText:  'Phone Number',
                    hintText:   '7700 000000',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+44 ',
                    prefixStyle: TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText:  'Password',
                    hintText:   'Min 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  validator: _validateConfirmPassword,
                  decoration: InputDecoration(
                    labelText:  'Confirm Password',
                    hintText:   'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                ),

                // ── Driver Fields — animated slide-in ─────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SizeTransition(
                    sizeFactor: _fadeAnim,
                    axisAlignment: -1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _sectionLabel('Driver Details'),
                        const SizedBox(height: 12),

                        // License Number
                        TextFormField(
                          controller: _licenseNumberController,
                          textCapitalization: TextCapitalization.characters,
                          validator: _selectedType == UserType.driver
                              ? (v) => _req(v, 'License number')
                              : null,
                          decoration: const InputDecoration(
                            labelText:  'License Number',
                            hintText:   'e.g. MORGA753116SM9IJ',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // License Plate
                        TextFormField(
                          controller: _licensePlateController,
                          textCapitalization: TextCapitalization.characters,
                          validator: _selectedType == UserType.driver
                              ? (v) => _req(v, 'License plate')
                              : null,
                          decoration: const InputDecoration(
                            labelText:  'License Plate',
                            hintText:   'e.g. AB12 CDE',
                            prefixIcon: Icon(Icons.directions_car_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Submit ────────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2.5))
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login link ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?',
                        style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize:      12,
          fontWeight:    FontWeight.w700,
          color:         AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}

// ─────────────────────────────────────────────
//  Email Verification Dialog
// ─────────────────────────────────────────────
class _EmailVerificationDialog extends StatefulWidget {
  final String email;
  final VoidCallback onGoToLogin;

  const _EmailVerificationDialog({
    required this.email,
    required this.onGoToLogin,
  });

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  bool _isResending    = false;
  String? _feedbackMessage;
  bool _feedbackSuccess = false;

  Future<void> _resend() async {
    setState(() {
      _isResending     = true;
      _feedbackMessage = null;
    });

    final result = await AuthService.instance.resendVerification();

    if (!mounted) return;
    setState(() {
      _isResending     = false;
      _feedbackSuccess = result.success;
      _feedbackMessage = result.success
          ? '✅ Email sent! Check your inbox & spam folder.'
          : result.message ?? 'Failed to resend. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verify Your Email',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                children: [
                  const TextSpan(text: 'A verification link has been sent to\n'),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const TextSpan(
                    text: '\n\nPlease verify your email before logging in.\n'
                        'Check your spam folder if you don\'t see it.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_feedbackMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _feedbackSuccess
                      ? Colors.green.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _feedbackSuccess ? Colors.green : AppColors.error,
                  ),
                ),
                child: Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _feedbackSuccess
                        ? Colors.green.shade700
                        : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onGoToLogin,
                child: const Text('Go to Login'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isResending ? null : _resend,
                child: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : const Text('Resend Verification Email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  User Type Card Widget
// ─────────────────────────────────────────────
class _UserTypeCard extends StatelessWidget {
  const _UserTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final UserType     type;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? type.activeIcon : type.icon,
              size:  30,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              type.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}