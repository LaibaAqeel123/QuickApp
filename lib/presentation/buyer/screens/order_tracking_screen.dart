import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  /// Raw order map — at minimum needs an 'id' / 'orderId' field.
  /// The screen will fetch full detail from the API on load.
  final Map<String, dynamic> order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _orderDetail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  // ── Safe field helpers ─────────────────────────────────
  String get _orderId =>
      (widget.order['id'] ?? widget.order['orderId'] ?? widget.order['orderNumber'] ?? '')
          .toString();

  String _safeStr(dynamic val, [String fallback = '']) =>
      val?.toString() ?? fallback;

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw.toString()).toLocal();
      final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m    = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return raw.toString();
    }
  }

  String get _statusLabel {
    final src = _orderDetail ?? widget.order;
    final raw = src['status'] ?? src['orderStatus'];
    if (raw is String) return raw;
    if (raw is int) {
      switch (raw) {
        case 1: return 'Processing';
        case 2: return 'Out for Delivery';
        case 3: return 'Delivered';
        case 4: return 'Cancelled';
        default: return 'Unknown';
      }
    }
    return 'Unknown';
  }

  String get _displayOrderId {
    final src = _orderDetail ?? widget.order;
    return _safeStr(src['id'] ?? src['orderId'] ?? src['orderNumber'], '#N/A');
  }

  String get _supplierName {
    final src = _orderDetail ?? widget.order;
    return _safeStr(
        src['supplierName'] ?? src['supplier']?['name'] ?? src['vendor'],
        'Supplier');
  }

  int get _itemCount {
    final src   = _orderDetail ?? widget.order;
    final items = src['items'] ?? src['orderItems'];
    if (items is List) return items.length;
    final count = src['itemCount'] ?? src['totalItems'];
    if (count is num) return count.toInt();
    return 0;
  }

  double get _totalAmount {
    final src = _orderDetail ?? widget.order;
    final raw = src['total'] ?? src['totalAmount'] ?? src['grandTotal'] ?? 0;
    return (raw as num).toDouble();
  }

  String get _placedDate {
    final src = _orderDetail ?? widget.order;
    final raw = src['createdAt'] ?? src['date'] ?? src['orderDate'];
    return _formatDate(raw);
  }

  String get _placedTime {
    final src = _orderDetail ?? widget.order;
    final raw = src['createdAt'] ?? src['date'] ?? src['orderDate'];
    return _formatTime(raw);
  }

  Map<String, dynamic>? get _driverInfo {
    final src = _orderDetail ?? widget.order;
    return src['driver'] as Map<String, dynamic>?;
  }

  // ── Load full order detail ─────────────────────────────
  Future<void> _loadOrderDetail() async {
    if (_orderId.isEmpty) {
      setState(() { _isLoading = false; _error = 'Invalid order ID.'; });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final result = await AuthService.instance.getMyOrderById(_orderId);

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _orderDetail = result.data;
        _isLoading   = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error     = result.message;
        // Fall back to the passed-in data
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_displayOrderId),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          if (_driverInfo != null)
            IconButton(icon: const Icon(Icons.phone), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrderDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error banner (non-blocking — we still show fallback data)
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.error)),
                            ),
                          ],
                        ),
                      ),

                    // ── Map Placeholder ──────────────────
                    Container(
                      height: 250,
                      color: AppColors.surfaceLight,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_shipping,
                                size: 80, color: AppColors.primary),
                            const SizedBox(height: 12),
                            const Text('Tracking your delivery',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabel,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor())),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Driver Info ──────────────────────
                    if (_driverInfo != null ||
                        _statusLabel.toLowerCase() == 'out for delivery')
                      _DriverCard(driver: _driverInfo),

                    // ── Tracking Timeline ────────────────
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Status',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          _TrackingStep(
                            title:       'Order Placed',
                            subtitle:    '$_placedDate • $_placedTime',
                            isCompleted: true,
                            isActive:    false,
                            icon:        Icons.check_circle,
                          ),
                          _TrackingStep(
                            title:       'Order Confirmed',
                            subtitle:    'Your order has been confirmed',
                            isCompleted: _isAtLeast('processing'),
                            isActive:    false,
                            icon:        Icons.verified,
                          ),
                          _TrackingStep(
                            title: _statusLabel.toLowerCase() == 'processing'
                                ? 'Preparing Order'
                                : 'Order Prepared',
                            subtitle:    'Your order is being prepared',
                            isCompleted: _isAtLeast('out for delivery'),
                            isActive:    _statusLabel.toLowerCase() == 'processing',
                            icon:        Icons.inventory_2,
                          ),
                          _TrackingStep(
                            title:       'Out for Delivery',
                            subtitle:    'Driver is on the way',
                            isCompleted: _statusLabel.toLowerCase() == 'delivered',
                            isActive:
                                _statusLabel.toLowerCase() == 'out for delivery',
                            icon: Icons.local_shipping,
                          ),
                          _TrackingStep(
                            title:       'Delivered',
                            subtitle:    'Order has been delivered',
                            isCompleted: _statusLabel.toLowerCase() == 'delivered',
                            isActive:    false,
                            icon:        Icons.check_circle,
                            isLast:      true,
                          ),
                        ],
                      ),
                    ),

                    // ── Order Details ────────────────────
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Details',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon:  Icons.receipt,
                            label: 'Order ID',
                            value: _displayOrderId,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon:  Icons.store,
                            label: 'Supplier',
                            value: _supplierName,
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon:  Icons.shopping_basket,
                            label: 'Items',
                            value: '$_itemCount items',
                          ),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon:  Icons.attach_money,
                            label: 'Total Amount',
                            value: '£${_totalAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Color _statusColor() {
    switch (_statusLabel.toLowerCase()) {
      case 'processing':      return AppColors.warning;
      case 'out for delivery': return AppColors.info;
      case 'delivered':       return AppColors.success;
      case 'cancelled':       return AppColors.error;
      default:                return AppColors.textSecondary;
    }
  }

  bool _isAtLeast(String minStatus) {
    const order = ['processing', 'out for delivery', 'delivered'];
    final current = order.indexOf(_statusLabel.toLowerCase());
    final min     = order.indexOf(minStatus.toLowerCase());
    return current >= min && current != -1;
  }
}

// ══════════════════════════════════════════════════════════
//  DRIVER CARD
// ══════════════════════════════════════════════════════════
class _DriverCard extends StatelessWidget {
  final Map<String, dynamic>? driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final name   = driver?['name'] ?? driver?['fullName'] ?? 'Your Driver';
    final rating = driver?['rating']?.toString() ?? '—';
    final trips  = driver?['totalDeliveries']?.toString() ?? '';
    final vehicle = driver?['vehicle'] ?? driver?['vehicleType'] ?? 'Van';
    final plate   = driver?['licensePlate'] ?? driver?['plate'] ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toString(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    trips.isNotEmpty ? '$rating ($trips deliveries)' : rating,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  plate.toString().isNotEmpty
                      ? '$vehicle • $plate'
                      : vehicle.toString(),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: AppColors.primary),
            onPressed: () {},
            style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TRACKING STEP
// ══════════════════════════════════════════════════════════
class _TrackingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final IconData icon;
  final bool isLast;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.textHint;
    if (isCompleted) color = AppColors.success;
    if (isActive)    color = AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? color.withOpacity(0.1)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: isCompleted ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isActive || isCompleted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DETAIL ROW
// ══════════════════════════════════════════════════════════
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}