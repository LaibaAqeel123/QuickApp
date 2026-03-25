import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/documents_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/payout_history_screen.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  final String? driverId;
  const DriverProfileScreen({super.key, this.driverId});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String? _driverId;

  @override
  void initState() {
    super.initState();
    _resolveDriverId();
  }

  Future<void> _resolveDriverId() async {
    final id = widget.driverId ??
        await AuthService.instance.getSavedDriverId();
    if (mounted) setState(() => _driverId = id);
  }

  // ── Logout dialog ───────────────────────────────────
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.instance.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Navigate to Payout History ──────────────────────
  void _openPayoutHistory(BuildContext context) {
    if (_driverId == null || _driverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver ID not found. Please log in again.'),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutHistoryScreen(driverId: _driverId!),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────
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
            color:   AppColors.primary,
            child: Column(children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color:  AppColors.white,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 4),
                ),
                child: const Icon(Icons.person,
                    size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('John Driver',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white)),
              const SizedBox(height: 4),
              Text('driver@test.com',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white.withOpacity(0.8))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.star, size: 20, color: AppColors.warning),
                const SizedBox(width: 4),
                const Text('4.9',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white)),
                const SizedBox(width: 4),
                Text('(250 deliveries)',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.8))),
              ]),
            ]),
          ),

          // ── Stats ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: _StatBox(
                  icon:  Icons.local_shipping,
                  value: '250',
                  label: 'Deliveries',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon:  Icons.attach_money,
                  value: '£12.5K',
                  label: 'Total Earned',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon:  Icons.timer,
                  value: '6mo',
                  label: 'Member',
                  color: AppColors.info,
                ),
              ),
            ]),
          ),

          // ── Vehicle ─────────────────────────────────
          _SectionCard(
            label: 'Vehicle',
            children: [
              _MenuItem(
                icon:     Icons.directions_car,
                title:    'Vehicle Type',
                subtitle: 'Van',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.confirmation_number,
                title:    'Registration',
                subtitle: 'ABC 1234',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.description,
                title:    'Documents',
                subtitle: 'View and manage',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DocumentsScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Earnings ─────────────────────────────────
          // NEW: Payout History added here
          _SectionCard(
            label: 'Earnings',
            children: [
              _MenuItem(
                icon:     Icons.receipt_long_outlined,
                title:    'Payout History',
                subtitle: 'View all your payout periods',
                // Highlighted in primary colour to draw attention
                iconColor: AppColors.primary,
                onTap: () => _openPayoutHistory(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Account ──────────────────────────────────
          _SectionCard(
            label: 'Account',
            children: [
              _MenuItem(
                icon:     Icons.person_outlined,
                title:    'Personal Information',
                subtitle: 'Update your details',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.account_balance_wallet,
                title:    'Payment Details',
                subtitle: 'Bank account for payouts',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.location_on_outlined,
                title:    'Preferred Areas',
                subtitle: 'Set your delivery zones',
                onTap:    () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Settings ─────────────────────────────────
          _SectionCard(
            label: 'Settings',
            children: [
              _MenuItem(
                icon:     Icons.notifications_outlined,
                title:    'Notifications',
                subtitle: 'Manage notification preferences',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.language,
                title:    'Language',
                subtitle: 'English (UK)',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.help_outlined,
                title:    'Help & Support',
                subtitle: 'FAQs and contact support',
                onTap:    () {},
              ),
              const Divider(height: 1),
              _MenuItem(
                icon:     Icons.info_outlined,
                title:    'About',
                subtitle: 'App version 1.0.0',
                onTap:    () {},
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Logout ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width:  double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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

// ══════════════════════════════════════════════════════════
//  SECTION CARD WRAPPER
// ══════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String        label;
  final List<Widget>  children;
  const _SectionCard({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  STAT BOX
// ══════════════════════════════════════════════════════════
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String   value, label;
  final Color    color;
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(children: [
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
                  fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  MENU ITEM
// ══════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData     icon;
  final String       title, subtitle;
  final VoidCallback onTap;
  final Color?       iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: iconColor ?? AppColors.primary, size: 24),
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