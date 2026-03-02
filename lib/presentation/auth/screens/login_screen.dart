import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/constants/app_strings.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/auth/screens/signup_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible   = false;
  bool _isLoading           = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return AppStrings.emailRequired;
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 6) return AppStrings.passwordMinLength;
    return null;
  }

  // ── Field extractor ──────────────────────────
  String? _extractField(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      if (key.contains('.')) {
        final parts = key.split('.');
        dynamic node = body;
        for (final p in parts) {
          node = (node is Map<String, dynamic>) ? node[p] : null;
        }
        if (node != null) return node.toString();
      } else if (body[key] != null) {
        return body[key].toString();
      }
    }
    return null;
  }

  // ── Main login flow ──────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Step 1: Login
    final loginResult = await AuthService.instance.login(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!loginResult.success) {
      _showError(loginResult.message ?? 'Invalid credentials.');
      setState(() => _isLoading = false);
      return;
    }

    // Step 2: Get profile
    final profileResult = await AuthService.instance.getProfile();
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Step 3: Determine role
    final loginData = loginResult.data ?? {};
    String role = (_extractField(loginData, [
              'role', 'userType', 'user.role', 'data.role',
            ]) ?? 'customer')
        .toLowerCase();

    if (profileResult.success && profileResult.data != null) {
      final pr = _extractField(profileResult.data!, [
        'role', 'userType', 'user.role', 'data.role',
      ])?.toLowerCase();
      if (pr != null && pr.isNotEmpty) role = pr;
    }

    // Step 4: Route
    if (role == 'driver' || role == '3') {
      await _handleDriverFlow(loginData, profileResult.data);
    } else {
      _navigateToBuyer();
    }
  }

  // ── Driver flow ──────────────────────────────
  Future<void> _handleDriverFlow(
    Map<String, dynamic> loginData,
    Map<String, dynamic>? profileData,
  ) async {
    // Find driverId
    String? driverId = _extractField(loginData, [
          'driverId', 'driver_id', 'id', 'sub', 'userId',
        ]) ??
        _extractField(profileData ?? {}, [
          'driverId', 'driver_id', 'id', 'sub',
          'driver.id', 'data.driverId',
        ]);

    // Save driverId
    if (driverId != null) {
      await AuthService.instance.saveTokens(
        accessToken: (await AuthService.instance.getAccessToken()) ?? '',
        driverId: driverId,
      );
    }

    // Fetch driver profile for approval status
    String? approvalStatus;
    if (driverId != null) {
      final dr = await AuthService.instance.getDriverProfile(driverId);
      if (!mounted) return;
      if (dr.success && dr.data != null) {
        approvalStatus = _extractField(dr.data!, [
          'status', 'approvalStatus', 'accountStatus',
          'data.status', 'driver.status',
        ])?.toLowerCase();
      }
    }

    // Fallback to profile data
    approvalStatus ??= _extractField(profileData ?? {}, [
      'status', 'approvalStatus', 'accountStatus',
    ])?.toLowerCase();

    if (!mounted) return;

    final isApproved =
        approvalStatus == 'approved' || approvalStatus == 'active';

    if (isApproved) {
      _navigateToDriver(driverId);
    } else {
      _showPendingApprovalDialog();
    }
  }

  // ── Pending Approval Popup ────────────────────
  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
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
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 44, color: Colors.orange),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pending Approval',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your driver account is currently under review.\n\nOnce our admin team approves your application, you\'ll be able to start accepting deliveries.\n\nThis usually takes 24–48 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.orange),
                    SizedBox(width: 6),
                    Text(
                      'Status: Pending',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK, I'll Wait"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────
  void _navigateToBuyer() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BuyerMainScreen()),
      (route) => false,
    );
  }

  void _navigateToDriver(String? driverId) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => DriverMainScreen(driverId: driverId)),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          size: 50, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(AppStrings.welcomeBack,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(AppStrings.loginToContinue,
                      style: const TextStyle(
                          fontSize: 16, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                      labelText:  AppStrings.email,
                      hintText:   'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    decoration: InputDecoration(
                      labelText:  AppStrings.password,
                      hintText:   'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: forgot password
                      },
                      child: const Text(AppStrings.forgotPassword,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: AppColors.white, strokeWidth: 2.5))
                          : const Text(AppStrings.login),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(AppStrings.dontHaveAccount,
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen()),
                        ),
                        child: const Text(AppStrings.signUp,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            )),
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