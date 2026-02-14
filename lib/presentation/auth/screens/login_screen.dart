import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/constants/app_strings.dart';
import 'package:food_delivery_app/presentation/supplier/screens/supplier_dashboard_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.emailRequired;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 6) {
      return AppStrings.passwordMinLength;
    }
    return null;
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Check dummy credentials for Supplier
        if (email == AppStrings.supplierEmail && password == AppStrings.supplierPassword) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SupplierDashboardScreen(),
            ),
          );
        }
        // Check dummy credentials for Buyer
        else if (email == AppStrings.buyerEmail && password == AppStrings.buyerPassword) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const BuyerMainScreen(),
            ),
          );
        }
        // Check dummy credentials for Driver
        else if (email == AppStrings.driverEmail && password == AppStrings.driverPassword) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DriverMainScreen(),
            ),
          );
        }
        else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid credentials.\n\n'
                    'Supplier: supplier@test.com / supplier123\n'
                    'Buyer: buyer@test.com / buyer123\n'
                    'Driver: driver@test.com / driver123',
              ),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 6),
            ),
          );
        }
      });
    }
  }

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
                  // Logo/Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome Text
                  Text(
                    AppStrings.welcomeBack,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.loginToContinue,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                      },
                      child: const Text(
                        AppStrings.forgotPassword,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text(AppStrings.login),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Dummy Credentials Hint
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Test Credentials',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Supplier Credentials
                        const Text(
                          'Supplier Login:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.supplierEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.supplierPassword,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Buyer Credentials
                        const Text(
                          'Buyer Login:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.buyerEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.buyerPassword,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Driver Credentials
                        const Text(
                          'Driver Login:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.driverEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.driverPassword,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.dontHaveAccount,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to sign up
                        },
                        child: const Text(
                          AppStrings.signUp,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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


