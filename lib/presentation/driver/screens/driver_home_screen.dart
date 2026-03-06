import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/job_detail_screen.dart';

class DriverHomeScreen extends StatefulWidget {

  final String? driverId;

  const DriverHomeScreen({super.key, this.driverId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
 
  bool _isOnline          = false;
  bool _isTogglingOnline  = false;
  bool _isLoadingProfile  = true;
  String? _driverId;
  String _driverName      = 'Driver';
  String _vehicleType     = 'N/A';
  String _licensePlate    = 'N/A';

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  
  Future<void> _loadDriverData() async {
    setState(() => _isLoadingProfile = true);

    
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();

    if (_driverId == null) {
      
      final profile = await AuthService.instance.getProfile();
      if (profile.success && profile.data != null) {
        _driverId = _extract(profile.data!, [
          'driverId', 'driver_id', 'id',
        ]);
        _driverName = _extract(profile.data!, [
              'fullName', 'name', 'firstName',
            ]) ??
            'Driver';
      }
    }

    if (_driverId != null) {
      final result =
          await AuthService.instance.getDriverProfile(_driverId!);
      if (result.success && result.data != null) {
        final data = result.data!;
        setState(() {
          _driverName  = _extract(data, ['fullName', 'name', 'firstName']) ?? _driverName;
          _vehicleType = _extract(data, ['vehicleType', 'vehicle.type', 'vehicle']) ?? 'N/A';
          _licensePlate= _extract(data, ['licensePlate', 'vehicle.plate', 'plate']) ?? 'N/A';

          
          final status = _extract(data, [
            'isAvailable', 'available', 'isOnline', 'online',
            'availabilityStatus',
          ]);
          _isOnline = status == 'true' || status == '1' || status == 'online';
        });
      }
    }

    if (mounted) setState(() => _isLoadingProfile = false);
  }

  // ── Toggle availability — real API call ───────
  Future<void> _toggleAvailability() async {
    if (_driverId == null) {
      _showSnackbar('Driver ID not found. Please log out and log in again.',
          isError: true);
      return;
    }

    setState(() => _isTogglingOnline = true);

    final result =
        await AuthService.instance.toggleDriverAvailability(_driverId!);

    if (!mounted) return;

    if (result.success) {
      // Toggle the UI state — server confirms via response or we optimistically flip
      final newStatus = result.data != null
          ? (_extract(result.data!, [
                'isAvailable', 'available', 'isOnline', 'online',
              ]) ==
              'true')
          : !_isOnline;

      setState(() {
        _isOnline          = newStatus;
        _isTogglingOnline  = false;
      });

      _showSnackbar(
        _isOnline ? 'You\'re now Online ' : 'You\'re now Offline',
        isError: false,
      );
    } else {
      setState(() => _isTogglingOnline = false);
      _showSnackbar(
          result.message ?? 'Failed to update availability. Try again.',
          isError: true);
    }
  }

  String? _extract(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      if (key.contains('.')) {
        final parts = key.split('.');
        dynamic node = body;
        for (final p in parts) {
          node = (node is Map<String, dynamic>) ? node[p] : null;
        }
        if (node != null) return node.toString();
      } else if (body[key] != null) {
        return body[key].toString();
      }
    }
    return null;
  }

  void _showSnackbar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, $_driverName! 👋',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Ready for deliveries?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.notifications_outlined),
                                color: AppColors.white,
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Online / Offline Toggle ───
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Status dot
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _isOnline
                                            ? AppColors.success
                                            : AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isOnline
                                          ? 'You\'re Online'
                                          : 'You\'re Offline',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                // Toggle — shows spinner while API call in progress
                                _isTogglingOnline
                                    ? const SizedBox(
                                        width: 36,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: AppColors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Switch(
                                        value: _isOnline,
                                        onChanged: (_) =>
                                            _toggleAvailability(),
                                        activeColor: AppColors.success,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Today's Summary ───────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.local_shipping,
                                  value: '12',
                                  label: 'Deliveries',
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.access_time,
                                  value: '8.5h',
                                  label: 'Hours',
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.attach_money,
                                  value: '£145',
                                  label: 'Earned',
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.route,
                                  value: '85km',
                                  label: 'Distance',
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Vehicle Status ────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_shipping,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Vehicle Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.directions_car,
                              label: 'Vehicle Type',
                              value: _vehicleType,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.confirmation_number,
                              label: 'Registration',
                              value: _licensePlate,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.verified,
                              label: 'Status',
                              value: _isOnline ? 'Online' : 'Offline',
                              valueColor: _isOnline
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Available Jobs Nearby ─────────────
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Jobs Nearby',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Jobs list (static for demo)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return _JobCard(
                          jobId: 'JOB${1001 + index}',
                          pickupLocation: 'Premium Wholesale',
                          deliveryLocation: 'The Italian Restaurant',
                          distance: '${3.5 + index} km',
                          payment:
                              '£${(12.50 + index * 2).toStringAsFixed(2)}',
                          deliverySize: index == 0
                              ? 'Medium'
                              : index == 1
                                  ? 'Large'
                                  : 'Small',
                          scheduledTime: '${10 + index}:30 AM',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JobDetailScreen(
                                jobId: 'JOB${1001 + index}',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable sub-widgets
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  const _StatCard({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            )),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  final String       jobId;
  final String       pickupLocation;
  final String       deliveryLocation;
  final String       distance;
  final String       payment;
  final String       deliverySize;
  final String       scheduledTime;
  final VoidCallback onTap;

  const _JobCard({
    required this.jobId,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.distance,
    required this.payment,
    required this.deliverySize,
    required this.scheduledTime,
    required this.onTap,
  });

  Color _sizeColor() {
    switch (deliverySize) {
      case 'Small':      return AppColors.success;
      case 'Medium':     return AppColors.info;
      case 'Large':      return AppColors.warning;
      case 'Extra Large':return AppColors.error;
      default:           return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jobId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(scheduledTime,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(payment,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        )),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _sizeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(deliverySize,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _sizeColor(),
                          )),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickupLocation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(deliveryLocation,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.route,
                        size: 16, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(distance,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}