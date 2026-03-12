import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/earnings_screen.dart';

// ── Delivery status constants ──────────────────────────────
// 2=Assigned, 3=Accepted, 4=PickedUp, 6=Delivered
class _DS {
  static const int accepted  = 3;
  static const int pickedUp  = 4;
}

/// ActiveDeliveryScreen
///
/// On init: calls GET /api/Deliveries?status=3 then ?status=4,
/// filters by driverId on frontend, shows the matched delivery.
/// Falls back to [delivery] param if API returns nothing.
/// Polls every 30s. All API calls are fully logged.
class ActiveDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic>? delivery;
  final String? driverId;
  const ActiveDeliveryScreen({super.key, this.delivery, this.driverId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  bool    _isLoading    = true;
  bool    _isSubmitting = false;
  String? _errorMsg;
  String? _driverId;
  Map<String, dynamic>? _activeDelivery;
  int     _step = 0; // 0=Accepted, 1=PickedUp, 2=Delivered
  Timer?  _pollTimer;

  static const _stepLabels = ['Heading to Pickup', 'Heading to Delivery', 'Delivered'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _driverId = widget.driverId ?? await AuthService.instance.getSavedDriverId();
    await _fetchActiveDelivery();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchActiveDelivery(silent: true));
  }

  // ══════════════════════════════════════════════════════
  //  FETCH — GET /api/Deliveries?status=3 then ?status=4
  //  Filter by driverId on frontend
  // ══════════════════════════════════════════════════════
  Future<void> _fetchActiveDelivery({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _isLoading = true; _errorMsg = null; });

    if (_driverId == null) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = 'Driver ID not found.'; });
      return;
    }

    Map<String, dynamic>? found;
    int foundStep = 0;

    // ── Step 1: GET /api/Deliveries?status=3 (Accepted) ──
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  FETCH ACTIVE DELIVERY — status=3 (Accepted)');
    debugPrint('║  driverId: $_driverId');
    debugPrint('╚══════════════════════════════════════╝');

    final r3 = await AuthService.instance.getDeliveries(status: _DS.accepted);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  FETCH ACTIVE DELIVERY RESPONSE — status=3');
    debugPrint('║  success : ${r3.success}');
    debugPrint('║  count   : ${r3.data?.length ?? 0}');
    debugPrint('║  data    : ${r3.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (r3.success && r3.data != null) {
      found = r3.data!
          .whereType<Map<String, dynamic>>()
          .where((d) => (d['driverId'] ?? d['driver_id'])?.toString() == _driverId)
          .firstOrNull;
      if (found != null) foundStep = 0;
    }

    // ── Step 2: GET /api/Deliveries?status=4 (PickedUp) if not found ──
    if (found == null) {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  FETCH ACTIVE DELIVERY — status=4 (PickedUp)');
      debugPrint('║  driverId: $_driverId');
      debugPrint('╚══════════════════════════════════════╝');

      final r4 = await AuthService.instance.getDeliveries(status: _DS.pickedUp);

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  FETCH ACTIVE DELIVERY RESPONSE — status=4');
      debugPrint('║  success : ${r4.success}');
      debugPrint('║  count   : ${r4.data?.length ?? 0}');
      debugPrint('║  data    : ${r4.data}');
      debugPrint('╚══════════════════════════════════════╝');

      if (r4.success && r4.data != null) {
        found = r4.data!
            .whereType<Map<String, dynamic>>()
            .where((d) => (d['driverId'] ?? d['driver_id'])?.toString() == _driverId)
            .firstOrNull;
        if (found != null) foundStep = 1;
      }
    }

    // ── Fallback to passed delivery ──
    if (found == null && widget.delivery != null) {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  FETCH ACTIVE DELIVERY — using passed delivery (fallback)');
      debugPrint('║  data: ${widget.delivery}');
      debugPrint('╚══════════════════════════════════════╝');
      found = widget.delivery;
      final s = (found?['deliveryStatus'] ?? found?['status'] ?? '').toString().toLowerCase();
      foundStep = (s == '4' || s == 'pickedup' || s == 'picked_up') ? 1 : 0;
    }

    if (!mounted) return;
    setState(() {
      _isLoading      = false;
      _activeDelivery = found;
      if (found != null && !_isSubmitting) _step = foundStep;
    });
  }

  String _field(List<String> keys, [String fallback = 'N/A']) {
    final d = _activeDelivery;
    if (d == null) return fallback;
    for (final k in keys) { if (d[k] != null) return d[k].toString(); }
    return fallback;
  }

  // ══════════════════════════════════════════════════════
  //  CONFIRM PICKUP SHEET
  //  POST /api/Drivers/{driverId}/deliveries/{deliveryId}/pickup
  // ══════════════════════════════════════════════════════
  void _showPickupSheet() {
    String notes = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) {
        bool sub = false;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _handle(),
            const SizedBox(height: 16),
            const Text('Confirm Pickup', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Confirm you have picked up the items.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {/* TODO: image_picker */},
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Notes (optional)',
                  hintText: 'e.g. Picked up from store', border: OutlineInputBorder()),
              onChanged: (v) => notes = v, maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: sub ? null : () async {
                  setBS(() => sub = true);
                  Navigator.of(ctx).pop();
                  await _doConfirmPickup(notes: notes.trim());
                },
                child: sub
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Confirm Pickup', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _doConfirmPickup({String? notes}) async {
    final deliveryId = _activeDelivery?['deliveryId'] ?? _activeDelivery?['id'];
    if (_driverId == null || deliveryId == null) {
      _snack('Driver/Delivery ID missing.', isError: true); return;
    }
    setState(() => _isSubmitting = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  CONFIRM PICKUP — REQUEST');
    debugPrint('║  driverId  : $_driverId');
    debugPrint('║  deliveryId: $deliveryId');
    debugPrint('║  notes     : $notes');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.confirmPickup(
      driverId: _driverId!, deliveryId: deliveryId.toString(), notes: notes,
    );

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  CONFIRM PICKUP — RESPONSE');
    debugPrint('║  success: ${result.success}');
    debugPrint('║  message: ${result.message}');
    debugPrint('║  data   : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result.success) {
      setState(() => _step = 1);
      _snack('Items picked up! Head to delivery location. 🚗');
    } else {
      _snack(result.message ?? 'Failed to confirm pickup.', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  COMPLETE DELIVERY SHEET
  //  POST /api/Drivers/{driverId}/deliveries/{deliveryId}/complete
  // ══════════════════════════════════════════════════════
  void _showCompleteSheet() {
    final recipientCtrl = TextEditingController();
    String notes = '';
    String? recipientError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) {
        bool sub = false;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _handle(),
            const SizedBox(height: 16),
            const Text('Complete Delivery', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Confirm delivery and get recipient details.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // REQUIRED recipient name
            TextField(
              controller: recipientCtrl,
              decoration: InputDecoration(
                labelText: 'Recipient Name *',
                hintText: 'e.g. John Smith',
                border: const OutlineInputBorder(),
                errorText: recipientError,
              ),
              onChanged: (_) {
                if (recipientError != null) setBS(() => recipientError = null);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {/* TODO: image_picker */},
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo (optional)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {/* TODO: signature pad */},
                icon: const Icon(Icons.draw),
                label: const Text('Get Signature (optional)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Notes (optional)',
                  hintText: 'e.g. Delivered successfully', border: OutlineInputBorder()),
              onChanged: (v) => notes = v, maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: sub ? null : () async {
                  final name = recipientCtrl.text.trim();
                  if (name.isEmpty) {
                    setBS(() => recipientError = 'Recipient name is required'); return;
                  }
                  setBS(() => sub = true);
                  Navigator.of(ctx).pop();
                  await _doCompleteDelivery(recipientName: name, notes: notes.trim());
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: sub
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Complete Delivery', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _doCompleteDelivery({required String recipientName, String? notes}) async {
    final deliveryId = _activeDelivery?['deliveryId'] ?? _activeDelivery?['id'];
    if (_driverId == null || deliveryId == null) {
      _snack('Driver/Delivery ID missing.', isError: true); return;
    }
    setState(() => _isSubmitting = true);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  COMPLETE DELIVERY — REQUEST');
    debugPrint('║  driverId     : $_driverId');
    debugPrint('║  deliveryId   : $deliveryId');
    debugPrint('║  recipientName: $recipientName');
    debugPrint('║  notes        : $notes');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.completeDelivery(
      driverId: _driverId!, deliveryId: deliveryId.toString(),
      recipientName: recipientName, notes: notes,
    );

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  COMPLETE DELIVERY — RESPONSE');
    debugPrint('║  success: ${result.success}');
    debugPrint('║  message: ${result.message}');
    debugPrint('║  data   : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result.success) {
      setState(() => _step = 2);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _showSuccessDialog(result.data);
      });
    } else {
      _snack(result.message ?? 'Failed to complete delivery.', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('Active Delivery'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      actions: [
        if (!_isLoading)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchActiveDelivery(),
          ),
      ],
    );

    if (_isLoading) {
      return Scaffold(backgroundColor: AppColors.background, appBar: appBar,
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_errorMsg != null && _activeDelivery == null) {
      return Scaffold(backgroundColor: AppColors.background, appBar: appBar,
          body: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_errorMsg!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: () => _fetchActiveDelivery(),
                  icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ]))));
    }
    if (_activeDelivery == null) {
      return Scaffold(backgroundColor: AppColors.background, appBar: appBar,
          body: const _NoActiveDelivery());
    }

    // ── Main UI ───────────────────────────────────────
    final orderNum        = _field(['orderNumber', 'order_number'], 'Active Delivery');
    final pickupAddress   = _field(['pickupAddress', 'pickup_address']);
    final deliveryAddress = _field(['deliveryAddress', 'delivery_address']);
    final distRaw         = _activeDelivery?['distanceKm'] ?? _activeDelivery?['distance_km'];
    final distanceStr     = distRaw != null ? '${(distRaw as num).toStringAsFixed(1)} km away' : '';
    final earnRaw         = _activeDelivery?['driverEarnings'] ?? _activeDelivery?['payment'] ?? _activeDelivery?['earnings'];
    final paymentStr      = earnRaw != null ? '£${(earnRaw as num).toStringAsFixed(2)}' : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: _isSubmitting
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing...', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ]))
          : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Map placeholder
              Container(height: 200, color: AppColors.surfaceLight,
                child: Stack(children: [
                  Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.navigation, size: 60, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text('Navigation Active', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (distanceStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(distanceStr, style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ])),
                  Positioned(top: 12, right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'active_loc_fab', onPressed: () {},
                      backgroundColor: AppColors.white,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ]),
              ),

              // Status banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                color: _step == 1 ? AppColors.success : AppColors.primary,
                child: Column(children: [
                  Text(_stepLabels[_step], style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.white)),
                  const SizedBox(height: 4),
                  Text(orderNum, style: const TextStyle(fontSize: 13, color: AppColors.white)),
                ]),
              ),

              // Step progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(children: [
                  _StepDot(active: _step >= 0, done: _step > 0, label: 'Pickup'),
                  Expanded(child: Container(height: 2,
                      color: _step > 0 ? AppColors.success : AppColors.border)),
                  _StepDot(active: _step >= 1, done: _step > 1, label: 'En Route'),
                  Expanded(child: Container(height: 2,
                      color: _step > 1 ? AppColors.success : AppColors.border)),
                  _StepDot(active: _step >= 2, done: _step >= 2, label: 'Done'),
                ]),
              ),

              // Pickup card
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _DeliveryStep(
                  icon: Icons.store, title: 'Pickup Location',
                  address: pickupAddress, isCompleted: _step > 0,
                  isActive: _step == 0, buttonText: 'Confirm Pickup',
                  buttonColor: AppColors.primary,
                  onButtonPressed: _step == 0 ? _showPickupSheet : null,
                ),
              ),

              // Delivery card
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _DeliveryStep(
                  icon: Icons.location_on, title: 'Delivery Location',
                  address: deliveryAddress, isCompleted: _step >= 2,
                  isActive: _step == 1, buttonText: 'Complete Delivery',
                  buttonColor: AppColors.success,
                  onButtonPressed: _step == 1 ? _showCompleteSheet : null,
                ),
              ),

              // Info card
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Delivery Details', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    if (distanceStr.isNotEmpty)
                      _InfoRow(icon: Icons.route, label: 'Distance', value: distanceStr),
                    if (paymentStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.attach_money, label: 'Earnings', value: paymentStr),
                    ],
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.flag, label: 'Status', value: _stepLabels[_step]),
                  ]),
                ),
              ),
            ])),
    );
  }

  Widget _handle() => Container(width: 40, height: 4,
      decoration: BoxDecoration(color: AppColors.border,
          borderRadius: BorderRadius.circular(2)));

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _showSuccessDialog(Map<String, dynamic>? responseData) {
    final earnRaw = _activeDelivery?['driverEarnings'] ?? _activeDelivery?['payment'];
    final paymentStr = earnRaw != null ? '£${(earnRaw as num).toStringAsFixed(2)}' : '';

    showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 60, color: AppColors.success)),
          const SizedBox(height: 24),
          const Text('Delivery Completed!', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (paymentStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('$paymentStr earned', style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
          ],
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final driverId = _driverId ??
                    await AuthService.instance.getSavedDriverId() ?? '';
                if (!mounted) return;
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => EarningsScreen(driverId: driverId)));
              },
              child: const Text('View Earnings'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: TextButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              child: const Text('Back to Jobs'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
class _NoActiveDelivery extends StatelessWidget {
  const _NoActiveDelivery();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.local_shipping_outlined, size: 80, color: AppColors.textHint),
        const SizedBox(height: 20),
        const Text('No Active Delivery', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        const Text('Accept a job from the Jobs tab\nto start a delivery.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textHint)),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
class _StepDot extends StatelessWidget {
  final bool active, done;
  final String label;
  const _StepDot({required this.active, required this.done, required this.label});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: done ? AppColors.success : active ? AppColors.primary : AppColors.border),
      child: Icon(done ? Icons.check : Icons.circle,
          size: done ? 16 : 10, color: Colors.white)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10,
        color: active || done ? AppColors.textPrimary : AppColors.textHint)),
  ]);
}

// ══════════════════════════════════════════════════════════
class _DeliveryStep extends StatelessWidget {
  final IconData icon;
  final String title, address, buttonText;
  final bool isCompleted, isActive;
  final Color buttonColor;
  final VoidCallback? onButtonPressed;
  const _DeliveryStep({
    required this.icon, required this.title, required this.address,
    required this.isCompleted, required this.isActive,
    required this.buttonText, required this.buttonColor,
    this.onButtonPressed,
  });
  @override
  Widget build(BuildContext context) {
    final Color color = isCompleted ? AppColors.success
        : isActive ? buttonColor : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isActive ? buttonColor : AppColors.border,
              width: isActive ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(isCompleted ? Icons.check_circle : icon,
                color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isActive ? buttonColor : AppColors.textPrimary))),
          if (isCompleted)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Done', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.location_on, size: 15, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(child: Text(address, style: TextStyle(fontSize: 13,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary))),
        ]),
        if (isActive && onButtonPressed != null) ...[
          const SizedBox(height: 14),
          SizedBox(width: double.infinity,
            child: ElevatedButton(onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
              child: Text(buttonText, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)))),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.textSecondary),
    const SizedBox(width: 12),
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
    Text(value, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
  ]);
}