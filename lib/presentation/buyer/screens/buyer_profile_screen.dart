import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/my_disputes_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/card_management_screen.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  // Profile
  String _displayName = 'Loading...';
  String _email       = '';
  bool   _isLoading   = true;

  // Card count badge
  int    _cardCount   = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCardCount();
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

  Future<void> _loadCardCount() async {
    final result = await AuthService.instance.getSavedCards();
    if (!mounted) return;
    debugPrint('💳 [Profile] card count: ${result.data?.length} success=${result.success}');
    if (result.success) {
      setState(() => _cardCount = result.data?.length ?? 0);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
      ),
      body: SingleChildScrollView(
        child: Column(children: [

          // ── Profile Header ──────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            color: AppColors.primary,
            child: Column(children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    color: AppColors.white, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 4)),
                child: const Icon(Icons.person, size: 45, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                  : Text(_displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.white)),
              const SizedBox(height: 4),
              if (_email.isNotEmpty)
                Text(_email, style: TextStyle(fontSize: 13, color: AppColors.white.withOpacity(0.8))),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Account ──────────────────────────────────
          _SectionCard(label: 'Account', children: [
            _MenuItem(
                icon: Icons.person_outlined, title: 'Personal Information',
                subtitle: 'Update your name, email, phone', onTap: () {}),
            const Divider(height: 1),
            _MenuItem(
                icon: Icons.location_on_outlined, title: 'Addresses',
                subtitle: 'Manage delivery addresses', onTap: () {}),
            const Divider(height: 1),

            // ── Payment Methods → CardManagementScreen ──
            _MenuItem(
              icon:     Icons.credit_card_outlined,
              title:    'Payment Methods',
              subtitle: _cardCount > 0
                  ? '$_cardCount saved card${_cardCount == 1 ? '' : 's'}'
                  : 'Manage saved cards',
              trailingWidget: _cardCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('$_cardCount',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.white)))
                  : null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CardManagementScreen()),
                );
                // Refresh badge when returning
                _loadCardCount();
              },
            ),
          ]),
          const SizedBox(height: 16),

          // ── Orders & Disputes ─────────────────────────
          _SectionCard(label: 'Orders & Support', children: [
            _MenuItem(
                icon: Icons.receipt_long_outlined, title: 'Order History',
                subtitle: 'View all your past orders', onTap: () {}),
            const Divider(height: 1),
            _MenuItem(
              icon:      Icons.gavel_outlined,
              title:     'My Disputes',
              subtitle:  'Track and manage your disputes',
              iconColor: const Color(0xFFF59E0B),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MyDisputesScreen())),
            ),
            const Divider(height: 1),
            _MenuItem(
                icon: Icons.help_outlined, title: 'Help & Support',
                subtitle: 'FAQs and contact support', onTap: () {}),
          ]),
          const SizedBox(height: 16),

          // ── Settings ─────────────────────────────────
          _SectionCard(label: 'Settings', children: [
            _MenuItem(
                icon: Icons.notifications_outlined, title: 'Notifications',
                subtitle: 'Manage notification preferences', onTap: () {}),
            const Divider(height: 1),
            _MenuItem(icon: Icons.language, title: 'Language', subtitle: 'English (UK)', onTap: () {}),
            const Divider(height: 1),
            _MenuItem(icon: Icons.info_outlined, title: 'About', subtitle: 'App version 1.0.0', onTap: () {}),
          ]),
          const SizedBox(height: 24),

          // ── Logout ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity, height: 54,
              child: OutlinedButton(
                onPressed: _showLogoutDialog,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout), SizedBox(width: 8),
                  Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ── Section card ─────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String label; final List<Widget> children;
  const _SectionCard({required this.label, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: children)),
    ]),
  );
}

// ── Menu item ────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final VoidCallback onTap;
  final Color?       iconColor;
  final Widget?      trailingWidget; // custom trailing replaces arrow when set

  const _MenuItem({
    required this.icon, required this.title, required this.subtitle, required this.onTap,
    this.iconColor, this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
    ),
    title:    Text(title,    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    trailing: trailingWidget ?? const Icon(Icons.arrow_forward_ios, size: 15, color: AppColors.textHint),
    onTap:    onTap,
  );
}