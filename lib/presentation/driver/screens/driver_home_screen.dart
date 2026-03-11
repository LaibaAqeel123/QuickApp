import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/available_jobs_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final String? driverId;
  const DriverHomeScreen({super.key, this.driverId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  // ── State ──────────────────────────────────────────────
  bool    _isLoadingProfile = true;
  bool    _isOnline         = false;
  bool    _isToggling       = false;
  String? _driverId;

  // ── Profile fields from API ────────────────────────────
  String _driverName     = 'Driver';
  String _vehicleType    = 'N/A';
  String _vehicleModel   = 'N/A';
  String _licensePlate   = 'N/A';
  double _rating         = 0.0;
  double _totalEarnings  = 0.0;
  int    _totalDeliveries = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD DRIVER PROFILE — GET /api/Drivers/{driverId}
  // ══════════════════════════════════════════════════════
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);

    // 1. Resolve driverId
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();

    // 2. Fallback: decode from JWT sub if still null
    if (_driverId == null) {
      final profile = await AuthService.instance.getProfile();
      if (profile.success && profile.data != null) {
        _driverId = _extract(profile.data!, ['userId', 'id', 'sub']);
      }
    }

    // 3. Load driver profile
    if (_driverId != null) {
      final result =
          await AuthService.instance.getDriverProfile(_driverId!);
      if (!mounted) return;
      if (result.success && result.data != null) {
        final d = result.data!;
        setState(() {
          _driverName      = _extract(d, ['fullName', 'name', 'firstName']) ?? 'Driver';
          _vehicleType     = _extract(d, ['vehicleType', 'vehicle.type'])   ?? 'N/A';
          _vehicleModel    = _extract(d, ['vehicleModel', 'vehicle.model'])  ?? 'N/A';
          _licensePlate    = _extract(d, ['licensePlate', 'plate'])          ?? 'N/A';
          _totalEarnings   = double.tryParse(
                _extract(d, ['totalEarnings', 'earnings']) ?? '0') ?? 0.0;
          _totalDeliveries = int.tryParse(
                _extract(d, ['totalDeliveries', 'deliveries']) ?? '0') ?? 0;
          _rating          = double.tryParse(
                _extract(d, ['rating', 'averageRating']) ?? '0') ?? 0.0;

          final status = _extract(d, [
            'isAvailable', 'available', 'isOnline', 'online',
          ]);
          _isOnline = status == 'true' || status == '1' || status == 'online';
        });
      }
    }

    if (mounted) setState(() => _isLoadingProfile = false);
  }

  // ══════════════════════════════════════════════════════
  //  TOGGLE AVAILABILITY — PATCH /api/Drivers/{id}/toggle-availability
  // ══════════════════════════════════════════════════════
  Future<void> _toggleAvailability() async {
    if (_driverId == null) {
      _snack('Driver ID not found. Please log out and log in again.',
          isError: true);
      return;
    }
    setState(() => _isToggling = true);

    final result =
        await AuthService.instance.toggleDriverAvailability(_driverId!);
    if (!mounted) return;

    if (result.success) {
      final raw = result.data != null
          ? _extract(result.data!, ['isAvailable', 'available'])
          : null;
      final newState = raw != null ? raw == 'true' : !_isOnline;
      setState(() { _isOnline = newState; _isToggling = false; });
      _snack(_isOnline ? 'You\'re now Online 🟢' : 'You\'re now Offline 🔴');
    } else {
      setState(() => _isToggling = false);
      _snack(result.message ?? 'Failed to update status.', isError: true);
    }
  }

  // ── Helpers ────────────────────────────────────────────
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────
                      _buildHeader(),

                      // ── Stats Row ──────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Stats',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: _StatCard(
                                icon:  Icons.local_shipping,
                                value: '$_totalDeliveries',
                                label: 'Deliveries',
                                color: AppColors.primary,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCard(
                                icon:  Icons.attach_money,
                                value: '£${_totalEarnings.toStringAsFixed(2)}',
                                label: 'Earned',
                                color: AppColors.success,
                              )),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _StatCard(
                                icon:  Icons.star,
                                value: _rating > 0
                                    ? _rating.toStringAsFixed(1)
                                    : 'N/A',
                                label: 'Rating',
                                color: AppColors.warning,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCard(
                                icon:  Icons.verified,
                                value: _isOnline ? 'Online' : 'Offline',
                                label: 'Status',
                                color: _isOnline
                                    ? AppColors.success
                                    : AppColors.error,
                              )),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Vehicle card ───────────────────
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
                              const Row(children: [
                                Icon(Icons.local_shipping,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Vehicle Details',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                              ]),
                              const SizedBox(height: 16),
                              _InfoRow(
                                  icon: Icons.directions_car,
                                  label: 'Type',
                                  value: _vehicleType),
                              const SizedBox(height: 10),
                              _InfoRow(
                                  icon: Icons.info_outline,
                                  label: 'Model',
                                  value: _vehicleModel),
                              const SizedBox(height: 10),
                              _InfoRow(
                                  icon: Icons.confirmation_number,
                                  label: 'Plate',
                                  value: _licensePlate),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── View Available Jobs button ─────
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AvailableJobsScreen(
                                    driverId: _driverId),
                              ),
                            ),
                            icon: const Icon(Icons.work),
                            label: const Text('View Available Jobs',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Header with online toggle ──────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, $_driverName! 👋',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white)),
              const SizedBox(height: 4),
              const Text('Ready for deliveries?',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.white)),
            ]),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: AppColors.white,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Online / Offline toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: _isOnline ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isOnline ? 'You\'re Online' : 'You\'re Offline',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white),
                ),
              ]),
              _isToggling
                  ? const SizedBox(
                      width: 36, height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2.5))
                  : Switch(
                      value: _isOnline,
                      onChanged: (_) => _toggleAvailability(),
                      activeColor: AppColors.success,
                    ),
            ],
          ),
        ),

        // Rating strip
        if (_rating > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            ...List.generate(5, (i) => Icon(
              i < _rating.floor()
                  ? Icons.star
                  : (i < _rating ? Icons.star_half : Icons.star_border),
              size: 20, color: AppColors.warning,
            )),
            const SizedBox(width: 8),
            Text(
              '${_rating.toStringAsFixed(1)} rating',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.white),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatCard({required this.icon, required this.value,
      required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 12),
      Text(value, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
          color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: AppColors.textSecondary),
    const SizedBox(width: 12),
    Expanded(child: Text(label, style: const TextStyle(
        fontSize: 14, color: AppColors.textSecondary))),
    Text(value, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary)),
  ]);
}