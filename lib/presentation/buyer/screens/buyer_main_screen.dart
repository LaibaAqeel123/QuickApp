import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_home_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/browse_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/cart_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_history_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_profile_screen.dart';

class BuyerMainScreen extends StatefulWidget {
  // ══════════════════════════════════════════════════════
  //  reloadCart flag
  //
  //  FIX: When navigating here after a successful payment,
  //  PaymentSuccessScreen passes reloadCart=true.
  //  BuyerMainScreen uses this to call CartScreen.reload()
  //  immediately after the first frame renders, guaranteeing
  //  the cart shows as empty even if the clearCartApi() call
  //  was still in progress during navigation.
  // ══════════════════════════════════════════════════════
  final bool reloadCart;

  const BuyerMainScreen({super.key, this.reloadCart = false});

  static const String routeName = '/buyer-main';

  @override
  State<BuyerMainScreen> createState() => BuyerMainScreenState();
}

class BuyerMainScreenState extends State<BuyerMainScreen> {
  int _currentIndex = 0;

  final _cartKey = GlobalKey<CartScreenState>();

  @override
  void initState() {
    super.initState();

    // ── Reload cart on first frame if flagged ──────────
    // This handles the case where we just completed payment.
    // We post a frame callback so the CartScreen widget is
    // fully built before we call reload() on it.
    if (widget.reloadCart) {
      debugPrint('🛒 [BuyerMain] reloadCart=true — '
          'scheduling CartScreen.reload() after first frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartKey.currentState?.reload();
        debugPrint('🛒 [BuyerMain] CartScreen.reload() called');
      });
    }
  }

  /// Switch to a tab by index.
  /// Always reloads cart when switching to tab 2 (Cart).
  void switchTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartKey.currentState?.reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      // ── Home ──────────────────────────────────────────
      BuyerHomeScreen(
        onBrowseTap: ({String? searchQuery}) {
          if (searchQuery != null && searchQuery.isNotEmpty) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BrowseScreen(
                initialSearch: searchQuery,
                onViewCart:    () => switchTab(2),
              ),
            ));
          } else {
            switchTab(1);
          }
        },
        onViewCart: () => switchTab(2),
      ),

      // ── Browse ────────────────────────────────────────
      BrowseScreen(onViewCart: () => switchTab(2)),

      // ── Cart ──────────────────────────────────────────
      CartScreen(
        key:        _cartKey,
        onBrowseTap: () => switchTab(1),
      ),

      // ── Orders ────────────────────────────────────────
      const OrderHistoryScreen(),

      // ── Profile ───────────────────────────────────────
      const BuyerProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset:     const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex:        _currentIndex,
          onTap:               switchTab,
          type:                BottomNavigationBarType.fixed,
          selectedItemColor:   AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize:    12,
          unselectedFontSize:  12,
          items: const [
            BottomNavigationBarItem(
              icon:       Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label:      'Home',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label:      'Browse',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label:      'Cart',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label:      'Orders',
            ),
            BottomNavigationBarItem(
              icon:       Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label:      'Profile',
            ),
          ],
        ),
      ),
    );
  }
}