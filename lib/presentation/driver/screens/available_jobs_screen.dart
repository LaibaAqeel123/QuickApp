import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/active_delivery_screen.dart';

class AvailableJobsScreen extends StatefulWidget {
  /// driverId passed from DriverHomeScreen (or DriverMainScreen).
  final String? driverId;
  const AvailableJobsScreen({super.key, this.driverId});

  @override
  State<AvailableJobsScreen> createState() => _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends State<AvailableJobsScreen> {
  // ── State ──────────────────────────────────────────────
  List<Map<String, dynamic>> _jobs = [];
  bool    _isLoading   = true;
  String? _errorMsg;
  String? _driverId;

  // ── Polling timer (every 30 seconds) ──────────────────
  Timer? _pollTimer;

  // ── Per-card countdown timers ──────────────────────────
  // Maps deliveryId → remaining seconds (updated every second)
  final Map<String, int> _countdowns = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Resolve driverId
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();

    // Initial load
    await _loadJobs();

    // Poll every 30 seconds for new offers
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadJobs(silent: true),
    );

    // Tick countdown every second
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdowns(),
    );
  }

  // ══════════════════════════════════════════════════════
  //  LOAD JOBS — GET /api/Deliveries?status=2
  // ══════════════════════════════════════════════════════
  Future<void> _loadJobs({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _isLoading = true; _errorMsg = null; });

    final result = await AuthService.instance.getDeliveries(status: 2);
    if (!mounted) return;

    if (result.success && result.data != null) {
      // Filter: only show cards assigned to THIS driver
      final all = result.data!
          .whereType<Map<String, dynamic>>()
          .toList();

      final filtered = _driverId != null
          ? all.where((d) {
        final id = (d['driverId'] ?? d['driver_id'] ?? '').toString();
        final status = (d['deliveryStatus'] ?? '').toString().toLowerCase();
        return id == _driverId && status != 'failed' && status != 'delivered';
      }).toList()
          : all;
      // Rebuild countdowns for new deliveries
      final Map<String, int> newCountdowns = {};
      for (final job in filtered) {
        final id = _jobId(job);
        final expires = _parseExpiry(job['expiresAt']?.toString());
        if (expires != null) {
          final remaining =
              expires.difference(DateTime.now().toUtc()).inSeconds;
          newCountdowns[id] = remaining > 0 ? remaining : 0;
        } else {
          newCountdowns[id] = _countdowns[id] ?? 600;
        }
      }

      setState(() {
        _jobs     = filtered;
        _isLoading = false;
        _countdowns
          ..clear()
          ..addAll(newCountdowns);
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = result.message ?? 'Failed to load jobs.';
      });
    }
  }

  // ── Countdown ticker ───────────────────────────────────
  void _tickCountdowns() {
    if (!mounted) return;
    setState(() {
      for (final key in _countdowns.keys.toList()) {
        if (_countdowns[key]! > 0) _countdowns[key] = _countdowns[key]! - 1;
      }
    });
  }

  // ── Field helpers ──────────────────────────────────────
  String _jobId(Map<String, dynamic> j) =>
      (j['deliveryId'] ?? j['id'] ?? '').toString();

  DateTime? _parseExpiry(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s).toUtc(); } catch (_) { return null; }
  }

  bool _isExpired(Map<String, dynamic> job) {
    final id  = _jobId(job);
    final secs = _countdowns[id] ?? 0;
    return secs <= 0;
  }

  String _formatCountdown(Map<String, dynamic> job) {
    final id   = _jobId(job);
    final secs = _countdowns[id] ?? 0;
    if (secs <= 0) return 'Expired';
    final m = secs ~/ 60;
    final s = secs % 60;
    return 'Expires in ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════
  //  ACCEPT — POST /api/Drivers/{driverId}/deliveries/{deliveryId}/accept
  // ══════════════════════════════════════════════════════
  Future<void> _acceptJob(Map<String, dynamic> job) async {
    if (_driverId == null) {
      _snack('Driver ID missing. Please log out and back in.', isError: true);
      return;
    }
    if (_isExpired(job)) {
      _snack('This offer has expired.', isError: true);
      return;
    }

    final delivId = _jobId(job);
    _setJobLoading(delivId, true);

    final result = await AuthService.instance.acceptDelivery(
      driverId: _driverId!,
      deliveryId: delivId,
    );
    if (!mounted) return;
    _setJobLoading(delivId, false);

    if (result.success) {
      _snack('Delivery accepted! Head to the pickup point. 🚗');
      // Remove from list and navigate to active delivery
      setState(() => _jobs.removeWhere((j) => _jobId(j) == delivId));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(delivery: job),
        ),
      );
    } else {
      _snack(result.message ?? 'Failed to accept. Try again.', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  REJECT — POST /api/Drivers/{driverId}/deliveries/{deliveryId}/reject
  // ══════════════════════════════════════════════════════
  void _promptReject(Map<String, dynamic> job) {
    String?        _selectedReason;
    String         _otherText = '';
    bool           _isRejecting = false;
    final reasons   = ['Too far away', 'Vehicle issue', 'Too busy', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Reason for Rejection',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...reasons.map((r) => RadioListTile<String>(
              value: r,
              groupValue: _selectedReason,
              title: Text(r),
              activeColor: AppColors.primary,
              onChanged: (v) => setBS(() => _selectedReason = v),
            )),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Please describe...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _otherText = v,
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isRejecting || _selectedReason == null
                    ? null
                    : () async {
                        setBS(() => _isRejecting = true);
                        final reason = _selectedReason == 'Other'
                            ? (_otherText.trim().isNotEmpty
                                ? _otherText.trim()
                                : 'Other')
                            : _selectedReason!;
                        Navigator.of(ctx).pop();
                        await _doReject(job, reason);
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: _isRejecting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Reject',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _doReject(Map<String, dynamic> job, String reason) async {
    if (_driverId == null) return;
    final delivId = _jobId(job);
    _setJobLoading(delivId, true);

    final result = await AuthService.instance.rejectDelivery(
      driverId:   _driverId!,
      deliveryId: delivId,
      reason:     reason,
    );
    if (!mounted) return;
    _setJobLoading(delivId, false);

    if (result.success) {
      setState(() => _jobs.removeWhere((j) => _jobId(j) == delivId));
      _snack('Delivery rejected. It will be reassigned.');
    } else {
      _snack(result.message ?? 'Failed to reject. Try again.', isError: true);
    }
  }

  // ── Per-card loading state ─────────────────────────────
  final Set<String> _loadingCards = {};
  void _setJobLoading(String id, bool v) {
    if (!mounted) return;
    setState(() => v ? _loadingCards.add(id) : _loadingCards.remove(id));
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
      appBar: AppBar(
        title: Text('Available Jobs (${_jobs.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadJobs(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? _ErrorView(message: _errorMsg!, onRetry: _loadJobs)
              : _jobs.isEmpty
                  ? _EmptyView(onRefresh: _loadJobs)
                  : RefreshIndicator(
                      onRefresh: _loadJobs,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jobs.length,
                        itemBuilder: (_, i) {
                          final job   = _jobs[i];
                          final id    = _jobId(job);
                          final busy  = _loadingCards.contains(id);
                          final expired = _isExpired(job);
                          return _JobCard(
                            job:           job,
                            countdown:     _formatCountdown(job),
                            isExpired:     expired,
                            isLoading:     busy,
                            onAccept:      expired || busy
                                ? null
                                : () => _acceptJob(job),
                            onReject:      busy
                                ? null
                                : () => _promptReject(job),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  JOB CARD
// ══════════════════════════════════════════════════════════
class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String   countdown;
  final bool     isExpired;
  final bool     isLoading;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _JobCard({
    required this.job,
    required this.countdown,
    required this.isExpired,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
  });

  String _str(String key, [String fallback = 'N/A']) =>
      (job[key] ?? job[_camel(key)] ?? fallback).toString();

  String _camel(String s) =>
      s.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final orderNum     = _str('orderNumber', 'Order');
    final pickup       = _str('pickupAddress');
    final delivery     = _str('deliveryAddress');
    final distRaw      = job['distanceKm'] ?? job['distance_km'] ?? job['distance'];
    final distance     = distRaw != null
        ? '${(distRaw as num).toStringAsFixed(1)} km'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? AppColors.error.withOpacity(0.4) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card header: order number + countdown ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isExpired
                ? AppColors.error.withOpacity(0.08)
                : AppColors.primary.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(orderNum,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            // Countdown chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isExpired
                    ? AppColors.error
                    : AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isExpired ? Icons.timer_off : Icons.timer_outlined,
                  size: 14,
                  color: isExpired ? Colors.white : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  countdown,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.white : AppColors.warning,
                  ),
                ),
              ]),
            ),
          ]),
        ),

        // ── Addresses ─────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _AddressRow(
              icon: Icons.store,
              color: AppColors.primary,
              label: 'Pickup',
              address: pickup,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 20),
                Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Icon(Icons.arrow_downward,
                      size: 14, color: AppColors.textHint),
                ),
              ]),
            ),
            _AddressRow(
              icon: Icons.location_on,
              color: AppColors.success,
              label: 'Delivery',
              address: delivery,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.route, size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text(distance,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ]),
          ]),
        ),

        // ── Accept / Reject buttons ────────────────
        if (isLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              // Reject
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Accept
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired
                          ? AppColors.border
                          : AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isExpired ? 'Offer Expired' : 'Accept',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, address;
  const _AddressRow({required this.icon, required this.color,
      required this.label, required this.address});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
              fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 2),
          Text(address, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
        ]),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════
//  EMPTY & ERROR VIEWS
// ══════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.work_off, size: 80, color: AppColors.textHint),
      const SizedBox(height: 16),
      const Text('No jobs available',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      const Text('Pull down to refresh or wait for new offers',
          style: TextStyle(fontSize: 14, color: AppColors.textHint)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh Now'),
      ),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 60, color: AppColors.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );
}