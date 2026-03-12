import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_home_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/available_jobs_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/active_delivery_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/earnings_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_profile_screen.dart';

/// DriverMainScreen — root scaffold with bottom nav.
///
/// Resolves driverId once and passes it down to every child screen
/// so they don't each have to look it up independently.
class DriverMainScreen extends StatefulWidget {
  final String? driverId;
  const DriverMainScreen({super.key, this.driverId});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int     _currentIndex    = 0;
  String? _resolvedDriverId;
  bool    _isResolving     = true;

  @override
  void initState() {
    super.initState();
    _resolveDriverId();
  }

  Future<void> _resolveDriverId() async {
    final id = widget.driverId ??
        await AuthService.instance.getSavedDriverId();

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  DRIVER MAIN — resolveDriverId');
    debugPrint('║  widget.driverId  : ${widget.driverId}');
    debugPrint('║  SharedPrefs id   : ${await AuthService.instance.getSavedDriverId()}');
    debugPrint('║  resolved final   : $id');
    debugPrint('╚══════════════════════════════════════╝');

    if (mounted) {
      setState(() {
        _resolvedDriverId = id;
        _isResolving      = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Show a loader until driverId is resolved so child
    // screens never start with a null ID.
    if (_isResolving) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Build screens lazily — IndexedStack keeps them alive
    // while preserving scroll position when switching tabs.
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0 — Home
          DriverHomeScreen(driverId: _resolvedDriverId),

          // 1 — Available Jobs
          AvailableJobsScreen(driverId: _resolvedDriverId),

          // 2 — Active Delivery (no active job yet when opened from nav)
          ActiveDeliveryScreen(driverId: _resolvedDriverId),

          // 3 — Earnings
          EarningsScreen(driverId: _resolvedDriverId),

          // 4 — Profile
          // Stats is accessible via the "Full Stats" button on the Home tab
          const DriverProfileScreen(),
        ],
      ),
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
          onTap: (index) {
            debugPrint(
                '\n[NAV] Tab tapped: $index | driverId: $_resolvedDriverId');
            setState(() => _currentIndex = index);
          },
          type:                  BottomNavigationBarType.fixed,
          selectedItemColor:     AppColors.primary,
          unselectedItemColor:   AppColors.textSecondary,
          selectedFontSize:      12,
          unselectedFontSize:    12,
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