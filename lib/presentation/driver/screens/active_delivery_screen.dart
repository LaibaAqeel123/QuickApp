import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

/// ActiveDeliveryScreen receives the accepted delivery map from
/// AvailableJobsScreen so it can show real pickup/delivery addresses.
///
/// [delivery] — the raw delivery object from GET /api/Deliveries.
/// If null (e.g. tapped from the bottom nav "Active" tab directly),
/// the screen shows a "no active delivery" state.
class ActiveDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic>? delivery;
  const ActiveDeliveryScreen({super.key, this.delivery});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  // Step index: 0 = heading to pickup, 1 = heading to delivery, 2 = delivered
  int _step = 0;

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

  @override
  Widget build(BuildContext context) {
    final hasDelivery = widget.delivery != null;

    // Pull real values from the delivery object (with safe fallbacks)
    final orderNum       = _field(['orderNumber', 'order_number'], 'Active Delivery');
    final pickupAddress  = _field(['pickupAddress', 'pickup_address']);
    final deliveryAddress= _field(['deliveryAddress', 'delivery_address']);
    final distanceKm     = widget.delivery?['distanceKm'] ??
        widget.delivery?['distance_km'] ??
        widget.delivery?['distance'];
    final distanceStr    = distanceKm != null
        ? '${(distanceKm as num).toStringAsFixed(1)} km away'
        : '';

    // Payment — try common field names
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
          ? _NoActiveDelivery()
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
                          onPressed: () {},
                          backgroundColor: AppColors.white,
                          child: const Icon(Icons.my_location,
                              color: AppColors.primary),
                        ),
                      ),
                    ]),
                  ),

                  // ── Current status banner ────────────
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

                  // ── Step progress indicator ──────────
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

                  // ── Pickup step card ─────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _DeliveryStep(
                      icon: Icons.store,
                      title: 'Pickup Location',
                      address: pickupAddress,
                      isCompleted: _step > 0,
                      isActive: _step == 0,
                      buttonText: 'Mark as Picked Up',
                      onButtonPressed: _step == 0
                          ? () {
                              setState(() => _step = 1);
                              _snack('Items picked up! Head to delivery location.');
                            }
                          : null,
                    ),
                  ),

                  // ── Delivery step card ───────────────
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
                          ? () => _showCompleteDialog(paymentStr)
                          : null,
                    ),
                  ),

                  // ── Delivery info card ───────────────
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

  void _showCompleteDialog(String paymentStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Have you delivered all items successfully?'),
          const SizedBox(height: 16),
          const Text('Proof of Delivery',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {/* TODO: camera */},
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {/* TODO: signature */},
              icon: const Icon(Icons.draw),
              label: const Text('Get Signature'),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _step = 2);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _showSuccessDialog(paymentStr);
              });
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String paymentStr) {
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
              onPressed: () {
                Navigator.pop(ctx);       // close success dialog
                Navigator.pop(context);   // back to jobs list
              },
              child: const Text('Done'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NO ACTIVE DELIVERY state (shown from bottom nav tab)
// ══════════════════════════════════════════════════════════
class _NoActiveDelivery extends StatelessWidget {
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