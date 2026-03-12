import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/available_jobs_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/earnings_screen.dart';
import 'package:food_delivery_app/presentation/driver/screens/driver_stats_screen.dart';
import 'package:geolocator/geolocator.dart';

class DriverHomeScreen extends StatefulWidget {
  final String? driverId;
  const DriverHomeScreen({super.key, this.driverId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  // ── Loading flags ──────────────────────────────────────
  bool _isLoadingProfile = true;
  bool _isLoadingStats   = false;
  bool _isToggling       = false;
  bool _isOnline         = false;
  String? _driverId;

  // ── Profile fields (from GET /api/Drivers/{id}) ────────
  String _driverName   = 'Driver';
  String _vehicleType  = 'N/A';
  String _vehicleModel = 'N/A';
  String _licensePlate = 'N/A';
  double _rating       = 0.0;

  // ── Stats fields (from GET /api/Drivers/{id}/stats) ────
  int    _totalDeliveries = 0;
  double _totalEarnings   = 0.0;
  double _acceptanceRate  = 0.0;
  int    _totalOffers     = 0;
  bool   _statsLoaded     = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD ALL — profile + stats in parallel
  // ══════════════════════════════════════════════════════
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _isLoadingProfile = true; _statsLoaded = false; });

    // 1. Resolve driverId
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  DRIVER HOME — resolving driverId');
    debugPrint('║  widget.driverId : ${widget.driverId}');
    debugPrint('║  resolved        : $_driverId');
    debugPrint('╚══════════════════════════════════════╝');

    // Fallback: decode from JWT /me if still null
    if (_driverId == null) {
      debugPrint('║  driverId null — falling back to /api/auth/me');
      final profile = await AuthService.instance.getProfile();
      debugPrint('║  /me success: ${profile.success} | data: ${profile.data}');
      if (profile.success && profile.data != null) {
        _driverId = _extract(profile.data!, ['userId', 'id', 'sub', 'driverId']);
        debugPrint('║  driverId from /me: $_driverId');
      }
    }

    if (_driverId != null) {
      // Run profile + stats calls concurrently
      await Future.wait([
        _loadProfile(),
        _loadStats(),
      ]);
    } else {
      debugPrint('║  ⚠️  driverId still null — cannot load profile or stats');
    }

    if (mounted) setState(() => _isLoadingProfile = false);
  }

  // ── GET /api/Drivers/{driverId} ────────────────────────
  Future<void> _loadProfile() async {
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  LOAD PROFILE — GET /api/Drivers/$_driverId');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.getDriverProfile(_driverId!);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  LOAD PROFILE RESULT');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  message : ${result.message}');
    debugPrint('║  data    : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted || !result.success || result.data == null) return;
    final d = result.data!;
    setState(() {
      _driverName  = _extract(d, ['fullName', 'name', 'firstName']) ?? 'Driver';
      _vehicleType = _extract(d, ['vehicleType', 'vehicle.type'])   ?? 'N/A';
      _vehicleModel= _extract(d, ['vehicleModel', 'vehicle.model']) ?? 'N/A';
      _licensePlate= _extract(d, ['licensePlate', 'plate'])         ?? 'N/A';
      _rating      = double.tryParse(
          _extract(d, ['rating', 'averageRating']) ?? '0') ?? 0.0;
      final status = _extract(d, [
        'isAvailable', 'available', 'isOnline', 'online']);
      _isOnline    = status == 'true' || status == '1' || status == 'online';
    });
  }

  // ── GET /api/Drivers/{driverId}/stats ──────────────────
  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  LOAD STATS — GET /api/Drivers/$_driverId/stats');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.getDriverStats(_driverId!);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  LOAD STATS RESULT');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  message : ${result.message}');
    debugPrint('║  data    : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted) return;
    setState(() => _isLoadingStats = false);

    if (!result.success || result.data == null) return;
    final d = result.data!;
    setState(() {
      _statsLoaded     = true;
      _totalDeliveries = (d['totalDeliveries'] as num?)?.toInt()    ?? 0;
      _totalEarnings   = (d['totalEarnings']   as num?)?.toDouble() ?? 0.0;
      _acceptanceRate  = (d['acceptanceRate']  as num?)?.toDouble() ?? 0.0;
      _totalOffers     = (d['totalOffers']     as num?)?.toInt()    ?? 0;
      // Override rating from stats if available (more accurate)
      final statRating = (d['rating'] as num?)?.toDouble();
      if (statRating != null && statRating > 0) _rating = statRating;
    });
  }

  // ══════════════════════════════════════════════════════
  //  GET CURRENT LOCATION
  // ══════════════════════════════════════════════════════
  Future<Position?> _getCurrentLocation() async {
    try {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  GETTING CURRENT LOCATION');
      debugPrint('╚══════════════════════════════════════╝');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('║  ❌ Location services are disabled');
        _snack('Please enable location services to go online', isError: true);
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('║  ❌ Location permissions are denied');
          _snack('Location permissions are required to go online', isError: true);
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('║  ❌ Location permissions are permanently denied');
        _snack('Location permissions are permanently denied. Please enable in settings.', isError: true);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('║  ✅ Location obtained:');
      debugPrint('║     lat: ${position.latitude}');
      debugPrint('║     lng: ${position.longitude}');
      debugPrint('║     accuracy: ${position.accuracy}m');
      
      return position;
    } catch (e) {
      debugPrint('║  ❌ Error getting location: $e');
      _snack('Failed to get location: $e', isError: true);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  //  UPDATE DRIVER LOCATION
  // ══════════════════════════════════════════════════════
  Future<bool> _updateDriverLocation(Position position) async {
    try {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  UPDATING DRIVER LOCATION');
      debugPrint('║  driverId  : $_driverId');
      debugPrint('║  latitude  : ${position.latitude}');
      debugPrint('║  longitude : ${position.longitude}');
      debugPrint('║  accuracy  : ${position.accuracy}m');
      debugPrint('╚══════════════════════════════════════╝');

      final result = await AuthService.instance.updateDriverLocation(
        driverId: _driverId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        speedKmh: 0,
        headingDegrees: 0,
        isActiveDelivery: false,
      );

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  LOCATION UPDATE RESULT');
      debugPrint('║  success : ${result.success}');
      debugPrint('║  message : ${result.message}');
      debugPrint('╚══════════════════════════════════════╝');

      return result.success;
    } catch (e) {
      debugPrint('║  ❌ Error updating location: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  TOGGLE AVAILABILITY
  // ══════════════════════════════════════════════════════
  Future<void> _toggleAvailability() async {
    if (_driverId == null) {
      _snack('Driver ID not found. Please log out and log in again.',
          isError: true);
      return;
    }
    
    setState(() => _isToggling = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  TOGGLE AVAILABILITY');
    debugPrint('║  driverId : $_driverId');
    debugPrint('║  current  : ${_isOnline ? "Online" : "Offline"}');
    debugPrint('╚══════════════════════════════════════╝');

    // If trying to go online, get location first
    if (!_isOnline) {
      final position = await _getCurrentLocation();
      if (position == null) {
        setState(() => _isToggling = false);
        return; // Don't proceed if we can't get location
      }
      
      // Call toggle API
      final result = await AuthService.instance.toggleDriverAvailability(_driverId!);
      
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  TOGGLE RESULT');
      debugPrint('║  success : ${result.success}');
      debugPrint('║  message : ${result.message}');
      debugPrint('╚══════════════════════════════════════╝');

      if (!mounted) return;
      
      if (result.success) {
        // After successful toggle, update location
        final locationUpdated = await _updateDriverLocation(position);
        
        if (locationUpdated) {
          final raw = result.data != null
              ? _extract(result.data!, ['isAvailable', 'available', 'isOnline'])
              : null;
          final newState = raw != null ? (raw == 'true') : !_isOnline;
          
          setState(() { 
            _isOnline = newState; 
            _isToggling = false; 
          });
          
          _snack('You\'re now Online 🟢');
        } else {
          // Location update failed, revert toggle
          await AuthService.instance.toggleDriverAvailability(_driverId!);
          setState(() => _isToggling = false);
          _snack('Failed to update location. Please try again.', isError: true);
        }
      } else {
        setState(() => _isToggling = false);
        _snack(result.message ?? 'Failed to update status.', isError: true);
      }
    } else {
      // Going offline - no need for location
      final result = await AuthService.instance.toggleDriverAvailability(_driverId!);
      
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  TOGGLE RESULT (Offline)');
      debugPrint('║  success : ${result.success}');
      debugPrint('║  message : ${result.message}');
      debugPrint('╚══════════════════════════════════════╝');

      if (!mounted) return;
      
      if (result.success) {
        final raw = result.data != null
            ? _extract(result.data!, ['isAvailable', 'available', 'isOnline'])
            : null;
        final newState = raw != null ? (raw == 'true') : !_isOnline;
        
        setState(() { 
          _isOnline = newState; 
          _isToggling = false; 
        });
        
        _snack('You\'re now Offline 🔴');
      } else {
        setState(() => _isToggling = false);
        _snack(result.message ?? 'Failed to update status.', isError: true);
      }
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
                      // ── Header with toggle ──────────────
                      _buildHeader(),

                      // ── Quick Actions ───────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _buildQuickActions(context),
                      ),
                      const SizedBox(height: 20),

                      // ── Stats row ───────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('My Performance',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                if (_isLoadingStats)
                                  const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
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
                                icon:  Icons.trending_up,
                                value: _statsLoaded
                                    ? '${_acceptanceRate.toStringAsFixed(0)}%'
                                    : 'N/A',
                                label: 'Acceptance',
                                color: AppColors.info,
                              )),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Vehicle card ────────────────────
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Quick Actions row ──────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        // Available Jobs — primary CTA
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AvailableJobsScreen(driverId: _driverId),
              ),
            ),
            icon: const Icon(Icons.work),
            label: const Text('View Available Jobs',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 10),
        // Earnings + Stats side by side
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EarningsScreen(driverId: _driverId),
                  ),
                ),
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    size: 18),
                label: const Text('Earnings'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DriverStatsScreen(driverId: _driverId),
                  ),
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('Full Stats'),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $_driverName! 👋',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white)),
                  const SizedBox(height: 4),
                  const Text('Ready for deliveries?',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.white)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: AppColors.white,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Online/Offline toggle
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

        // Rating stars
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

        // Total offers pill (from stats)
        if (_statsLoaded && _totalOffers > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalOffers total offers received',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.white),
            ),
          ),
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