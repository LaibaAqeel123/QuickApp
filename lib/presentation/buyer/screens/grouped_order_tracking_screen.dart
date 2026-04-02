import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

class GroupedOrderTrackingScreen extends StatefulWidget {
  final String groupId;
  final List<Map<String, dynamic>> orders;

  const GroupedOrderTrackingScreen({
    super.key,
    required this.groupId,
    required this.orders,
  });

  @override
  State<GroupedOrderTrackingScreen> createState() =>
      _GroupedOrderTrackingScreenState();
}

class _GroupedOrderTrackingScreenState
    extends State<GroupedOrderTrackingScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  // deliveryStatus cache per orderId
  final Map<String, Map<String, dynamic>> _deliveryCache = {};

  @override
  void initState() {
    super.initState();
    _orders = List.from(widget.orders);
    _loadFreshOrders();
  }

  // ── Load fresh order data from API ──────────────────
  Future<void> _loadFreshOrders() async {
    setState(() => _isLoading = true);
    try {
      final result =
      await AuthService.instance.getOrdersByGroupId(widget.groupId);
      if (result.success && result.data != null && result.data!.isNotEmpty) {
        setState(() {
          _orders = result.data!
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
      // Load delivery info for each order
      await _loadDeliveries();
    } catch (e) {
      debugPrint('GroupedOrderTracking load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliveries() async {
    for (final o in _orders) {
      final oid = _orderId(o);
      if (oid.isEmpty) continue;
      try {
        final result =
        await AuthService.instance.getDeliveryByOrderId(oid);
        if (result.success && result.data != null && mounted) {
          setState(() => _deliveryCache[oid] = result.data!);
        }
      } catch (_) {}
    }
  }

  // ── Helpers ─────────────────────────────────────────
  String _orderId(Map<String, dynamic> o) =>
      (o['id'] ?? o['orderId'] ?? '').toString();

  String _orderNumber(Map<String, dynamic> o) =>
      (o['orderNumber'] ?? _orderId(o)).toString();

  String _supplierName(Map<String, dynamic> o) {
    final items = o['items'];
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map) {
        final n = first['supplierName']?.toString() ?? '';
        if (n.isNotEmpty) return n;
      }
    }
    return (o['supplierName'] ?? 'Supplier').toString();
  }

  int _orderStatus(Map<String, dynamic> o) =>
      (o['status'] ?? o['orderStatus'] ?? 2) as int;

  bool _isSupplierDelivery(Map<String, dynamic> o) =>
      o['isSupplierDelivery'] == true;

  // ── Status label & color ────────────────────────────
  String _statusLabel(Map<String, dynamic> o) {
    final oid = _orderId(o);
    final delivery = _deliveryCache[oid];
    if (delivery != null) {
      final ds = (delivery['deliveryStatus'] ?? delivery['status'] ?? '')
          .toString()
          .toLowerCase();
      if (ds == 'delivered' || ds == '5' || ds == '6') return 'Delivered';
      if (ds == 'pickedup' || ds == '4') return 'Out for Delivery';
      if (ds == 'accepted' || ds == '3') return 'Driver Assigned';
      if (ds == 'assigned' || ds == '2') return 'Driver Assigned';
    }
    switch (_orderStatus(o)) {
      case 2: return 'Confirmed';
      case 3: return 'Accepted';
      case 4: return 'Finding Driver';
      case 5: return 'Delivered';
      case 6: return 'Completed';
      case 7: return 'Cancelled';
      case 8: return 'Out for Delivery';
      default: return 'Processing';
    }
  }

  Color _statusColor(Map<String, dynamic> o) {
    final label = _statusLabel(o).toLowerCase();
    if (label == 'delivered' || label == 'completed') return AppColors.success;
    if (label == 'cancelled') return AppColors.error;
    if (label == 'out for delivery') return AppColors.info;
    return AppColors.warning;
  }

  IconData _statusIcon(Map<String, dynamic> o) {
    final label = _statusLabel(o).toLowerCase();
    if (label == 'delivered' || label == 'completed')
      return Icons.check_circle;
    if (label == 'cancelled') return Icons.cancel;
    if (label == 'out for delivery') return Icons.local_shipping;
    if (label == 'driver assigned') return Icons.directions_bike;
    return Icons.autorenew;
  }

  // ── Can track ────────────────────────────────────────
  bool _canTrack(Map<String, dynamic> o) {
    final status = _orderStatus(o);
    return status == 3 ||
        status == 4 ||
        status == 5 ||
        status == 6 ||
        status == 8;
  }

  // ── Grand total ──────────────────────────────────────
  double get _grandTotal => _orders.fold(0.0, (sum, o) =>
  sum + ((o['total'] ?? o['totalAmount'] ?? 0) as num).toDouble());

  // ── Overall status label ─────────────────────────────
  String get _overallStatus {
    final statuses = _orders.map(_orderStatus).toList();
    if (statuses.every((s) => s == 6 || s == 5)) return 'All Delivered';
    if (statuses.every((s) => s == 7)) return 'All Cancelled';
    if (statuses.any((s) => s == 8 || s == 4)) return 'In Progress';
    if (statuses.any((s) => s == 7)) return 'Partially Cancelled';
    return 'Processing';
  }

  // ── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFreshOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadFreshOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Summary header ──────────────────
              _buildSummaryHeader(),

              // ── Supplier cards ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orders by Supplier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._orders.map((o) => _buildSupplierCard(o)),
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

  // ── Summary header ───────────────────────────────────
  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.storefront, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            '${_orders.length} Supplier Order',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Amount',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '£${_grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _overallStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  // ── Supplier card ────────────────────────────────────
  Widget _buildSupplierCard(Map<String, dynamic> o) {
    final oid          = _orderId(o);
    final statusLabel  = _statusLabel(o);
    final statusColor  = _statusColor(o);
    final statusIcon   = _statusIcon(o);
    final canTrack     = _canTrack(o);
    final isSupDel     = _isSupplierDelivery(o);
    final items        = o['items'];
    final itemCount    = items is List ? items.length : 0;
    final total        =
    ((o['total'] ?? o['totalAmount'] ?? 0) as num).toDouble();
    final isCancelled  = _orderStatus(o) == 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Card header ────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _supplierName(o),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _orderNumber(o),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '£${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // ── Delivery type badge ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSupDel
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSupDel
                      ? AppColors.warning.withOpacity(0.4)
                      : AppColors.info.withOpacity(0.4),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isSupDel ? Icons.store : Icons.delivery_dining,
                  size: 11,
                  color: isSupDel ? AppColors.warning : AppColors.info,
                ),
                const SizedBox(width: 4),
                Text(
                  isSupDel ? 'Supplier Delivery' : 'Driver Delivery',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSupDel ? AppColors.warning : AppColors.info,
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
              '$itemCount item${itemCount != 1 ? "s" : ""}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),

        // ── Track button ───────────────────────────────
        if (!isCancelled)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canTrack
                    ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(order: o),
                  ),
                )
                    : null,
                icon: Icon(
                  canTrack ? Icons.location_on : Icons.hourglass_empty,
                  size: 18,
                ),
                label: Text(
                  canTrack
                      ? (isSupDel ? 'View Timeline' : 'Track on Map')
                      : 'Waiting for Supplier',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  canTrack ? AppColors.primary : AppColors.surfaceLight,
                  foregroundColor:
                  canTrack ? Colors.white : AppColors.textSecondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined,
                      size: 16, color: AppColors.error),
                  SizedBox(width: 6),
                  Text('Order Cancelled',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error)),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}