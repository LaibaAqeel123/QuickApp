import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/auth/screens/email_verification_screen.dart';


enum UserType { buyer, driver }

extension UserTypeExt on UserType {
  String get label    => name[0].toUpperCase() + name.substring(1);
  String get apiValue => name[0].toUpperCase() + name.substring(1); // 'Buyer' | 'Driver'

  IconData get icon {
    switch (this) {
      case UserType.buyer:  return Icons.shopping_bag_outlined;
      case UserType.driver: return Icons.delivery_dining_outlined;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case UserType.buyer:  return Icons.shopping_bag;
      case UserType.driver: return Icons.delivery_dining;
    }
  }

  String get description {
    switch (this) {
      case UserType.buyer:  return 'Order food from restaurants';
      case UserType.driver: return 'Deliver orders & earn money';
    }
  }
}

const List<String> kVehicleTypes = ['Car', 'Van', 'Bicycle', 'Truck'];


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
  UserType _selectedType         = UserType.buyer;
  String? _selectedVehicleType;

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
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
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
    if (_selectedType == UserType.driver && _selectedVehicleType == null) {
      _showError('Please select a vehicle type');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.instance.register(
      firstName:     _firstNameController.text.trim(),
      lastName:      _lastNameController.text.trim(),
      email:         _emailController.text.trim(),
      password:      _passwordController.text,
      phone:         _phoneController.text.trim(),
      userType:      _selectedType.apiValue,
      licenseNumber: _selectedType == UserType.driver
          ? _licenseNumberController.text.trim()
          : null,
      licensePlate:  _selectedType == UserType.driver
          ? _licensePlateController.text.trim()
          : null,
      vehicleType:   _selectedType == UserType.driver
          ? _selectedVehicleType
          : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else {
      _showError(result.message ?? 'Registration failed. Please try again.');
    }
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

  void _onTypeChanged(UserType type) {
    setState(() => _selectedType = type);
    type == UserType.driver
        ? _animController.forward()
        : _animController.reverse();
  }

  
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
                // ── Header ──────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fill in your details to get started',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // ── Role Selector ────────────────────────
                _sectionLabel('Register as'),
                const SizedBox(height: 10),
                Row(
                  children: UserType.values
                      .map((type) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: type == UserType.buyer ? 8 : 0,
                                left:  type == UserType.driver ? 8 : 0,
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

                // ── Personal Info ────────────────────────
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
                    hintText:   '+44 7700 000000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText:  'Password',
                    hintText:   'Create a password',
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
                      onPressed: () => setState(() =>
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible),
                    ),
                  ),
                ),

                // ── Driver Fields (animated slide-in) ────
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

                        TextFormField(
                          controller: _licenseNumberController,
                          textCapitalization: TextCapitalization.characters,
                          validator: _selectedType == UserType.driver
                              ? (v) => _req(v, 'License number')
                              : null,
                          decoration: const InputDecoration(
                            labelText:  'License Number',
                            hintText:   'e.g. AB123456',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

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
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          decoration: const InputDecoration(
                            labelText:  'Vehicle Type',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          hint: const Text('Select vehicle type'),
                          items: kVehicleTypes
                              .map((v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ))
                              .toList(),
                          onChanged: _selectedType == UserType.driver
                              ? (v) => setState(() => _selectedVehicleType = v)
                              : null,
                          validator: _selectedType == UserType.driver
                              ? (v) => v == null
                                  ? 'Please select a vehicle type'
                                  : null
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),

                
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
                          fontWeight: FontWeight.w600,
                        ),
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}


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
              size: 30,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 14,
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