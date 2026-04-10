import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/documents_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/payout_history_screen.dart';
import 'package:food_delivery_app/presentation/auth/screens/login_screen.dart';

// ══════════════════════════════════════════════════════════
//  DRIVER PROFILE MODEL
// ══════════════════════════════════════════════════════════
class _DriverProfile {
  final String name;
  final String email;
  final String vehicleType;
  final String registration;

  const _DriverProfile({
    required this.name,
    required this.email,
    required this.vehicleType,
    required this.registration,
  });

  /// Parses the raw JSON returned by GET /api/Drivers/{id}
  /// Name resolution matches DriverHomeScreen: fullName → name → firstName
  factory _DriverProfile.fromJson(Map<String, dynamic> json) {
    // Name: use the same priority order as DriverHomeScreen
    final name = _extractField(json, ['fullName', 'name', 'firstName']) ?? '';

    // Email
    final email = json['email']?.toString().trim() ?? '';

    // Vehicle details may be nested under 'vehicle' or 'vehicleDetails'
    final vehicleMap =
        json['vehicle']        is Map<String, dynamic> ? json['vehicle']        as Map<String, dynamic>
      : json['vehicleDetails'] is Map<String, dynamic> ? json['vehicleDetails'] as Map<String, dynamic>
      : null;

    final vehicleType = vehicleMap?['vehicleType']?.toString()
        ?? vehicleMap?['type']?.toString()
        ?? json['vehicleType']?.toString()
        ?? json['vehicle_type']?.toString()
        ?? '';

    final registration = vehicleMap?['licensePlate']?.toString()
        ?? vehicleMap?['registration']?.toString()
        ?? json['licensePlate']?.toString()
        ?? json['registration']?.toString()
        ?? '';

    return _DriverProfile(
      name:         name,
      email:        email,
      vehicleType:  vehicleType,
      registration: registration,
    );
  }

  /// Mirrors the _extract() helper used in DriverHomeScreen.
  /// Supports dot-notation keys (e.g. 'vehicle.type').
  static String? _extractField(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      if (key.contains('.')) {
        final parts = key.split('.');
        dynamic node = body;
        for (final p in parts) {
          node = (node is Map<String, dynamic>) ? node[p] : null;
        }
        if (node != null) return node.toString().trim();
      } else if (body[key] != null) {
        final val = body[key].toString().trim();
        if (val.isNotEmpty) return val;
      }
    }
    return null;
  }
}

// ══════════════════════════════════════════════════════════
//  DRIVER PROFILE SCREEN
// ══════════════════════════════════════════════════════════
class DriverProfileScreen extends StatefulWidget {
  final String? driverId;
  const DriverProfileScreen({super.key, this.driverId});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String?         _driverId;
  _DriverProfile? _profile;
  bool            _isLoading = true;
  String?         _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Resolve driver ID → fetch profile from backend ──────
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      // 1. Resolve driver ID (passed in or from SharedPreferences)
      final id = widget.driverId ??
          await AuthService.instance.getSavedDriverId();

      if (id == null || id.isEmpty) {
        if (mounted) {
          setState(() {
            _error     = 'Driver ID not found. Please log in again.';
            _isLoading = false;
          });
        }
        return;
      }

      // 2. GET /api/Drivers/{id}  →  AuthResult
      //    AuthResult.data is Map<String, dynamic> with driver JSON
      final result = await AuthService.instance.getDriverProfile(id);

      if (!mounted) return;

      if (result.success && result.data != null) {
        setState(() {
          _driverId  = id;
          _profile   = _DriverProfile.fromJson(result.data!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error     = result.message ?? 'Failed to load profile.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error     = 'Unexpected error. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Logout ───────────────────────────────────────────────
  void _showLogoutDialog() {
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
              Navigator.pop(ctx);
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

  // ── Payout History → PayoutHistoryScreen ────────────────
  // Uses: GET /api/Earnings/drivers/{driverId}/payouts
  void _openPayoutHistory() {
    if (_driverId == null || _driverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver ID not found. Please log in again.'),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PayoutHistoryScreen(driverId: _driverId!)),
    );
  }

  // ── Documents ────────────────────────────────────────────
  // Uses: POST /api/Drivers/{id}/upload-document
  void _openDocuments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DocumentsScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon:      const Icon(Icons.refresh),
              tooltip:   'Refresh',
              onPressed: _loadProfile,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                size: 52, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
            ),
          ]),
        ),
      );
    }

    // Success
    final profile = _profile!;
    return SingleChildScrollView(
      child: Column(children: [

        // ── Profile Header ──────────────────────────────
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          color:   AppColors.primary,
          child: Column(children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color:  AppColors.white,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 4),
              ),
              child: const Icon(Icons.person,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 14),

            // Name resolved via fullName → name → firstName
            // (matches DriverHomeScreen._extract logic)
            Text(
              profile.name.isNotEmpty ? profile.name : '—',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
            const SizedBox(height: 4),

            // Email from GET /api/Drivers/{id}
            if (profile.email.isNotEmpty)
              Text(
                profile.email,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.85)),
              ),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Vehicle ─────────────────────────────────────
        _SectionCard(
          label: 'Vehicle',
          children: [
            _MenuItem(
              icon:     Icons.directions_car,
              title:    'Vehicle Type',
              subtitle: profile.vehicleType.isNotEmpty
                  ? profile.vehicleType
                  : 'Not set',
              onTap:    () {},
            ),
            const Divider(height: 1),
            _MenuItem(
              icon:     Icons.confirmation_number,
              title:    'Registration',
              subtitle: profile.registration.isNotEmpty
                  ? profile.registration
                  : 'Not set',
              onTap:    () {},
            ),
            const Divider(height: 1),
            _MenuItem(
              icon:     Icons.description,
              title:    'Documents',
              subtitle: 'View and manage',
              onTap:    _openDocuments,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Earnings ─────────────────────────────────────
        _SectionCard(
          label: 'Earnings',
          children: [
            _MenuItem(
              icon:      Icons.receipt_long_outlined,
              iconColor: AppColors.primary,
              title:     'Payout History',
              subtitle:  'View all your payout periods',
              onTap:     _openPayoutHistory,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ── Logout ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width:  double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _showLogoutDialog,
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

        const SizedBox(height: 36),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SECTION CARD
// ══════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String       label;
  final List<Widget> children;
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
//  MENU ITEM
// ══════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
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