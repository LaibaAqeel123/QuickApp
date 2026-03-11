import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/driver/screens/earnings_screen.dart';

// ── Delivery status constants (from API spec) ─────────────
// 2 = Assigned, 3 = Accepted, 4 = PickedUp, 6 = Delivered
class _DeliveryStatus {
  static const int accepted  = 3;
  static const int pickedUp  = 4;
  static const int delivered = 6;
}

/// ActiveDeliveryScreen — shows the live delivery journey.
///
/// [delivery]  — the raw delivery object from GET /api/Deliveries.
/// [driverId]  — required to call pickup/complete APIs.
///
/// If [delivery] is null (e.g. opened from bottom nav "Active" tab
/// without an accepted job), shows a "no active delivery" state.
class ActiveDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic>? delivery;
  final String? driverId;

  const ActiveDeliveryScreen({
    super.key,
    this.delivery,
    this.driverId,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  // ── Derived state ──────────────────────────────────────
  // 0 = Accepted (heading to pickup), 1 = PickedUp (heading to delivery), 2 = Delivered
  int     _step        = 0;
  bool    _isSubmitting = false;
  String? _driverId;
  String? _deliveryId;

  // ── Polling timer ──────────────────────────────────────
  Timer? _pollTimer;

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
    _driverId   = widget.driverId ??
        await AuthService.instance.getSavedDriverId();
    _deliveryId = _field(['deliveryId', 'id']);

    // Determine initial step from deliveryStatus field if present
    final statusRaw = widget.delivery?['deliveryStatus'] ??
        widget.delivery?['status'];
    if (statusRaw != null) {
      final s = statusRaw.toString().toLowerCase();
      if (s == '4' || s == 'pickedup' || s == 'picked_up' || s == 'picked up') {
        if (mounted) setState(() => _step = 1);
      }
    }

    // Poll for status updates every 30 seconds
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollStatus(),
    );
  }

  /// Poll GET /api/Deliveries and update step if status changed externally.
  Future<void> _pollStatus() async {
    if (!mounted || _deliveryId == null) return;
    final result = await AuthService.instance.getDeliveries(status: _step == 0 ? 3 : 4);
    if (!mounted || !result.success) return;
    final list = result.data ?? [];
    final match = list
        .whereType<Map<String, dynamic>>()
        .where((d) =>
            (d['deliveryId'] ?? d['id'])?.toString() == _deliveryId)
        .firstOrNull;
    if (match == null) return;
    final s = (match['deliveryStatus'] ?? match['status'] ?? '').toString().toLowerCase();
    if ((s == '4' || s == 'pickedup') && _step == 0 && mounted) {
      setState(() => _step = 1);
    }
  }

  // ── Safe field extractor ───────────────────────────────
  String _field(List<String> keys, [String fallback = 'N/A']) {
    final d = widget.delivery;
    if (d == null) return fallback;
    for (final key in keys) {
      if (d[key] != null) return d[key].toString();
    }
    return fallback;
  }

  // ── Step labels ────────────────────────────────────────
  static const _stepLabels = [
    'Heading to Pickup',
    'Heading to Delivery',
    'Delivered',
  ];

  // ══════════════════════════════════════════════════════
  //  CONFIRM PICKUP — POST .../pickup (multipart)
  // ══════════════════════════════════════════════════════
  void _showPickupSheet() {
    String notes = '';
    // In a real app you'd use image_picker here; we wire it up
    // with placeholder bytes for now and skip if null.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) {
          bool submitting = false;
          return Padding(
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
              const Text('Confirm Pickup',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Optional photo
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {/* TODO: image_picker */},
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo (optional)'),
                ),
              ),
              const SizedBox(height: 12),
              // Optional notes
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => notes = v,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setBS(() => submitting = true);
                          Navigator.of(ctx).pop();
                          await _doConfirmPickup(notes: notes);
                        },
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm Pickup',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _doConfirmPickup({String? notes}) async {
    if (_driverId == null || _deliveryId == null) {
      _snack('Driver/Delivery ID missing.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    final result = await AuthService.instance.confirmPickup(
      driverId:   _driverId!,
      deliveryId: _deliveryId!,
      notes:      notes,
      // photoBytes: pass actual bytes from image_picker here
    );
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
  //  COMPLETE DELIVERY — POST .../complete (multipart)
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) {
          bool submitting = false;
          return Padding(
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
              const Text('Complete Delivery',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Recipient name — REQUIRED
              TextField(
                controller: recipientCtrl,
                decoration: InputDecoration(
                  labelText: 'Recipient Name *',
                  border: const OutlineInputBorder(),
                  errorText: recipientError,
                ),
                onChanged: (_) {
                  if (recipientError != null) {
                    setBS(() => recipientError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              // Optional photo
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {/* TODO: image_picker */},
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo (optional)'),
                ),
              ),
              const SizedBox(height: 8),
              // Optional signature
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {/* TODO: signature pad */},
                  icon: const Icon(Icons.draw),
                  label: const Text('Get Signature (optional)'),
                ),
              ),
              const SizedBox(height: 12),
              // Optional notes
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => notes = v,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final name = recipientCtrl.text.trim();
                          if (name.isEmpty) {
                            setBS(() =>
                                recipientError = 'Recipient name is required');
                            return;
                          }
                          setBS(() => submitting = true);
                          Navigator.of(ctx).pop();
                          await _doCompleteDelivery(
                              recipientName: name, notes: notes);
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Complete Delivery',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _doCompleteDelivery({
    required String recipientName,
    String? notes,
  }) async {
    if (_driverId == null || _deliveryId == null) {
      _snack('Driver/Delivery ID missing.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    final result = await AuthService.instance.completeDelivery(
      driverId:      _driverId!,
      deliveryId:    _deliveryId!,
      recipientName: recipientName,
      notes:         notes,
      // photoBytes / signatureBytes: pass actual bytes from image_picker here
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      setState(() => _step = 2);
      // Brief pause then navigate to Earnings
      Future.delayed(const Duration(milliseconds: 400), () {
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
    final hasDelivery = widget.delivery != null;

    final orderNum        = _field(['orderNumber', 'order_number'], 'Active Delivery');
    final pickupAddress   = _field(['pickupAddress', 'pickup_address']);
    final deliveryAddress = _field(['deliveryAddress', 'delivery_address']);

    final distanceKm  = widget.delivery?['distanceKm'] ??
        widget.delivery?['distance_km'] ??
        widget.delivery?['distance'];
    final distanceStr = distanceKm != null
        ? '${(distanceKm as num).toStringAsFixed(1)} km away'
        : '';

    final paymentRaw = widget.delivery?['driverEarnings'] ??
        widget.delivery?['payment'] ??
        widget.delivery?['earnings'];
    final paymentStr = paymentRaw != null
        ? '£${(paymentRaw as num).toStringAsFixed(2)}'
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Active Delivery'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: !hasDelivery
          ? const _NoActiveDelivery()
          : _isSubmitting
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing...', style: TextStyle(
                          fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Map placeholder ──────────────────
                      Container(
                        height: 260,
                        color: AppColors.surfaceLight,
                        child: Stack(children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.navigation,
                                    size: 72, color: AppColors.primary),
                                const SizedBox(height: 10),
                                const Text('Navigation Active',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                if (distanceStr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(distanceStr,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            top: 12, right: 12,
                            child: FloatingActionButton.small(
                              heroTag: 'location_fab',
                              onPressed: () {},
                              backgroundColor: AppColors.white,
                              child: const Icon(Icons.my_location,
                                  color: AppColors.primary),
                            ),
                          ),
                        ]),
                      ),

                      // ── Status banner ─────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        color: AppColors.primary,
                        child: Column(children: [
                          Text(_stepLabels[_step],
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white)),
                          const SizedBox(height: 6),
                          Text(orderNum,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.white)),
                        ]),
                      ),

                      // ── Step progress ─────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(children: [
                          _StepDot(active: _step >= 0, done: _step > 0,
                              label: 'Pickup'),
                          Expanded(child: Container(height: 2,
                              color: _step > 0
                                  ? AppColors.success
                                  : AppColors.border)),
                          _StepDot(active: _step >= 1, done: _step > 1,
                              label: 'En Route'),
                          Expanded(child: Container(height: 2,
                              color: _step > 1
                                  ? AppColors.success
                                  : AppColors.border)),
                          _StepDot(active: _step >= 2, done: _step >= 2,
                              label: 'Done'),
                        ]),
                      ),

                      // ── Pickup card ───────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _DeliveryStep(
                          icon: Icons.store,
                          title: 'Pickup Location',
                          address: pickupAddress,
                          isCompleted: _step > 0,
                          isActive: _step == 0,
                          buttonText: 'Confirm Pickup',
                          onButtonPressed: _step == 0
                              ? _showPickupSheet
                              : null,
                        ),
                      ),

                      // ── Delivery card ─────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _DeliveryStep(
                          icon: Icons.location_on,
                          title: 'Delivery Location',
                          address: deliveryAddress,
                          isCompleted: _step >= 2,
                          isActive: _step == 1,
                          buttonText: 'Complete Delivery',
                          onButtonPressed: _step == 1
                              ? _showCompleteSheet
                              : null,
                        ),
                      ),

                      // ── Info card ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivery Details',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 12),
                              if (distanceStr.isNotEmpty)
                                _InfoRow(
                                    icon: Icons.route,
                                    label: 'Distance',
                                    value: distanceStr),
                              if (paymentStr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _InfoRow(
                                    icon: Icons.attach_money,
                                    label: 'Earnings',
                                    value: paymentStr),
                              ],
                              const SizedBox(height: 8),
                              _InfoRow(
                                  icon: Icons.flag,
                                  label: 'Status',
                                  value: _stepLabels[_step]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _showSuccessDialog(Map<String, dynamic>? responseData) {
    // Extract earnings from the delivery if available
    final earningsRaw = widget.delivery?['driverEarnings'] ??
        widget.delivery?['payment'] ??
        widget.delivery?['earnings'];
    final paymentStr = earningsRaw != null
        ? '£${(earningsRaw as num).toStringAsFixed(2)}'
        : '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                size: 60, color: AppColors.success),
          ),
          const SizedBox(height: 24),
          const Text('Delivery Completed!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          if (paymentStr.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('$paymentStr earned',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); // close success dialog
                // Navigate to Earnings screen
                final driverId = _driverId ??
                    await AuthService.instance.getSavedDriverId() ?? '';
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EarningsScreen(driverId: driverId),
                  ),
                );
              },
              child: const Text('View Earnings'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // back to jobs list
              },
              child: const Text('Back to Jobs'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NO ACTIVE DELIVERY
// ══════════════════════════════════════════════════════════
class _NoActiveDelivery extends StatelessWidget {
  const _NoActiveDelivery();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.local_shipping_outlined,
            size: 80, color: AppColors.textHint),
        const SizedBox(height: 20),
        const Text('No Active Delivery',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        const Text(
          'Accept a job from the Jobs tab\nto start a delivery.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textHint),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  STEP PROGRESS DOT
// ══════════════════════════════════════════════════════════
class _StepDot extends StatelessWidget {
  final bool active, done;
  final String label;
  const _StepDot({required this.active, required this.done,
      required this.label});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? AppColors.success
              : active
                  ? AppColors.primary
                  : AppColors.border,
        ),
        child: Icon(
          done ? Icons.check : Icons.circle,
          size: done ? 16 : 10,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: active || done
                  ? AppColors.textPrimary
                  : AppColors.textHint)),
    ],
  );
}

// ══════════════════════════════════════════════════════════
//  DELIVERY STEP CARD
// ══════════════════════════════════════════════════════════
class _DeliveryStep extends StatelessWidget {
  final IconData      icon;
  final String        title, address;
  final bool          isCompleted, isActive;
  final String        buttonText;
  final VoidCallback? onButtonPressed;

  const _DeliveryStep({
    required this.icon,
    required this.title,
    required this.address,
    required this.isCompleted,
    required this.isActive,
    required this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isCompleted
        ? AppColors.success
        : isActive
            ? AppColors.primary
            : AppColors.textHint;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : icon,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textPrimary)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.location_on, size: 15, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(address,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ]),
        if (isActive && onButtonPressed != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? AppColors.success
                    : AppColors.primary,
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  INFO ROW
// ══════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: AppColors.textSecondary),
    const SizedBox(width: 12),
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
    Text(value,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary)),
  ]);
}