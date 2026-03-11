import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_home_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/available_jobs_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/active_delivery_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/earnings_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_profile_screen.dart';

class DriverMainScreen extends StatefulWidget {
  final String? driverId;
  const DriverMainScreen({super.key, this.driverId});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int     _currentIndex      = 0;
  String? _resolvedDriverId;

  @override
  void initState() {
    super.initState();
    _resolveDriverId();
  }

  Future<void> _resolveDriverId() async {
    final id = widget.driverId ??
        await AuthService.instance.getSavedDriverId();
    if (mounted) setState(() => _resolvedDriverId = id);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DriverHomeScreen(driverId: _resolvedDriverId),
      AvailableJobsScreen(driverId: _resolvedDriverId),   // ← FIX: was const AvailableJobsScreen()
      const ActiveDeliveryScreen(),
      const EarningsScreen(),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon:       Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Active',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}