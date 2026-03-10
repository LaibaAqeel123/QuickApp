import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_main_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double>    _scaleAnim;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // Check login state after a short delay so the splash is visible
    Future.delayed(const Duration(milliseconds: 1500), _checkLoginAndRoute);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Reads SharedPreferences via AuthService and decides where to navigate.
  Future<void> _checkLoginAndRoute() async {
    if (!mounted) return;

    final isLoggedIn = await AuthService.instance.isLoggedIn();

    if (!mounted) return;

    if (!isLoggedIn) {
      // No saved token → go to login
      _goTo(const LoginScreen(), removeAll: true);
      return;
    }

    // Token exists — read the saved role to skip login entirely
    final role = await AuthService.instance.getSavedRole();

    if (!mounted) return;

    if (role == 'driver' || role == '3') {
      // Driver — also need driverId for DriverMainScreen
      final driverId = await AuthService.instance.getSavedDriverId();
      _goTo(DriverMainScreen(driverId: driverId), removeAll: true);
    } else {
      // Buyer / customer / supplier / anything else
      _goTo(const BuyerMainScreen(), removeAll: true);
    }
  }

  void _goTo(Widget screen, {bool removeAll = false}) {
    if (!mounted) return;
    if (removeAll) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => screen),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // App name
            FadeTransition(
              opacity: _fadeAnim,
              child: const Text(
                'QuickApp',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeAnim,
              child: const Text(
                'Fresh food, fast delivery',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Loading indicator
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}