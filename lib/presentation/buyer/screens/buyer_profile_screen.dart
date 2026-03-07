import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_screen.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  // Profile data loaded from API
  String _displayName  = 'Loading...';
  String _email        = '';
  bool   _isLoading    = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await AuthService.instance.getProfile();
    if (!mounted) return;

    if (result.success && result.data != null) {
      final data      = result.data!;
      final firstName = data['firstName']?.toString() ?? '';
      final lastName  = data['lastName']?.toString()  ?? '';
      final business  = data['businessName']?.toString() ?? '';
      final email     = data['email']?.toString() ?? '';

      setState(() {
        _displayName = business.isNotEmpty
            ? business
            : '$firstName $lastName'.trim().isNotEmpty
                ? '$firstName $lastName'.trim()
                : 'My Account';
        _email    = email;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await _showLogoutDialog();
    if (!confirmed || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Call API logout — clears token from SharedPreferences
    await AuthService.instance.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Profile Header ─────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.primary,
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 4),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2),
                        )
                      : Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                  const SizedBox(height: 4),
                  if (_email.isNotEmpty)
                    Text(
                      _email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.8),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: AppColors.white),
                        SizedBox(width: 6),
                        Text(
                          'Verified Business',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats Cards ────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      icon:  Icons.shopping_bag,
                      value: '142',
                      label: 'Orders',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      icon:  Icons.favorite,
                      value: '24',
                      label: 'Favorites',
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      icon:  Icons.attach_money,
                      value: '£12.5K',
                      label: 'Spent',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            // ── Account Section ────────────────────────
            _SectionGroup(
              title: 'Account',
              items: [
                _MenuItem(
                  icon:     Icons.person_outline,
                  title:    'Business Information',
                  subtitle: 'Update your business details',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.location_on_outlined,
                  title:    'Delivery Addresses',
                  subtitle: 'Manage your addresses',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressScreen(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon:     Icons.payment,
                  title:    'Payment Methods',
                  subtitle: 'Manage payment options',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.card_membership,
                  title:    'Subscription',
                  subtitle: 'Premium • Renews Feb 2026',
                  onTap:    () {},
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Preferences Section ────────────────────
            _SectionGroup(
              title: 'Preferences',
              items: [
                _MenuItem(
                  icon:     Icons.favorite_outline,
                  title:    'Favorite Suppliers',
                  subtitle: 'Your saved suppliers',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.notifications_outlined,
                  title:    'Notifications',
                  subtitle: 'Manage notification preferences',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.language,
                  title:    'Language',
                  subtitle: 'English (UK)',
                  onTap:    () {},
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Support Section ────────────────────────
            _SectionGroup(
              title: 'Support',
              items: [
                _MenuItem(
                  icon:     Icons.help_outline,
                  title:    'Help Center',
                  subtitle: 'FAQs and support',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.privacy_tip_outlined,
                  title:    'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.description_outlined,
                  title:    'Terms & Conditions',
                  subtitle: 'Read terms of service',
                  onTap:    () {},
                ),
                _MenuItem(
                  icon:     Icons.info_outline,
                  title:    'About',
                  subtitle: 'App version 1.0.0',
                  onTap:    () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Logout Button ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SECTION GROUP
// ══════════════════════════════════════════════════════════
class _SectionGroup extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _SectionGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  STAT BOX
// ══════════════════════════════════════════════════════════
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  MENU ITEM
// ══════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 16, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}