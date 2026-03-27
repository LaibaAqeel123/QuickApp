import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/dispute_form_screen.dart';

const int _kStatusProcessing     = 1;
const int _kStatusOutForDelivery = 2;
const int _kStatusDelivered      = 3;
const int _kStatusCancelled      = 4;

// ── Payment status constants ────────────────────────────
const int _kPayPending   = 1;
const int _kPayCompleted = 2;
const int _kPayFailed    = 3;
const int _kPayCancelled = 4;
const int _kPayRefunded  = 5;

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _rawOrders = [];

  bool    _isLoading = true;
  String? _error;

  // Delivery status cache: orderId → raw status string
  final Map<String, String> _deliveryStatusCache = {};

  // Payment status cache: orderId → payment status int (1-5)
  final Map<String, int> _paymentStatusCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Order status helpers ────────────────────────────
  String _statusLabel(Map<String, dynamic> o) {
    final oid    = _orderId(o);
    final cached = (_deliveryStatusCache[oid] ?? '').toLowerCase().trim();

    if (cached == 'delivered')                          return 'Delivered';
    if (cached == 'pickedup' || cached == 'picked_up') return 'Out for Delivery';
    if (cached == 'accepted' || cached == 'assigned')  return 'Processing';
    if (cached == 'pendingassignment' ||
        cached == 'pending_assignment')                 return 'Processing';

    final raw = o['status'] ?? o['orderStatus'];
    if (raw is int) {
      switch (raw) {
        case _kStatusProcessing:     return 'Processing';
        case _kStatusOutForDelivery: return 'Out for Delivery';
        case _kStatusDelivered:      return 'Delivered';
        case _kStatusCancelled:      return 'Cancelled';
        default:                     return 'Processing';
      }
    }
    if (raw is String) {
      switch (raw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '')) {
        case 'processing':
        case 'pending':
        case 'confirmed':    return 'Processing';
        case 'outfordelivery':
        case 'intransit':    return 'Out for Delivery';
        case 'delivered':
        case 'completed':    return 'Delivered';
        case 'cancelled':
        case 'canceled':     return 'Cancelled';
        default:             return raw;
      }
    }
    return 'Processing';
  }

  bool _isActive(Map<String, dynamic> o) {
    final l = _statusLabel(o).toLowerCase();
    return l == 'processing' || l == 'out for delivery';
  }

  bool _isCompleted(Map<String, dynamic> o) =>
      _statusLabel(o).toLowerCase() == 'delivered';

  // ── Payment status helpers ──────────────────────────
  int? _paymentStatus(String orderId) => _paymentStatusCache[orderId];

  /// Returns label, color, and icon for a payment status int.
  ({String label, Color color, IconData icon}) _paymentInfo(int status) {
    switch (status) {
      case _kPayPending:
        return (
          label: 'Pending',
          color: const Color(0xFFF59E0B),   // amber
          icon:  Icons.hourglass_empty,
        );
      case _kPayCompleted:
        return (
          label: 'Paid',
          color: AppColors.success,
          icon:  Icons.check_circle_outline,
        );
      case _kPayFailed:
        return (
          label: 'Failed',
          color: AppColors.error,
          icon:  Icons.error_outline,
        );
      case _kPayCancelled:
        return (
          label: 'Cancelled',
          color: AppColors.textSecondary,
          icon:  Icons.cancel_outlined,
        );
      case _kPayRefunded:
        return (
          label: 'Refunded',
          color: const Color(0xFF3B82F6),   // blue
          icon:  Icons.reply_outlined,
        );
      default:
        return (
          label: 'Unknown',
          color: AppColors.textHint,
          icon:  Icons.help_outline,
        );
    }
  }

  // ── Field helpers ───────────────────────────────────
  String _orderId(Map<String, dynamic> o) =>
      (o['id'] ?? o['orderId'] ?? o['orderNumber'] ?? '').toString();

  String _orderNumber(Map<String, dynamic> o) =>
      (o['orderNumber'] ?? o['id'] ?? o['orderId'] ?? '').toString();

  String _orderDate(Map<String, dynamic> o) {
    final raw = o['createdAt'] ?? o['date'] ?? o['orderDate'];
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return raw.toString(); }
  }

  String _orderTime(Map<String, dynamic> o) {
    final raw = o['createdAt'] ?? o['date'] ?? o['orderDate'];
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min  = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min ${dt.hour >= 12 ? "PM" : "AM"}';
    } catch (_) { return ''; }
  }

  int _itemCount(Map<String, dynamic> o) {
    final items = o['items'] ?? o['orderItems'];
    if (items is List) return items.length;
    final c = o['itemCount'] ?? o['totalItems'];
    return c is num ? c.toInt() : 0;
  }

  double _orderTotal(Map<String, dynamic> o) =>
      ((o['total'] ?? o['totalAmount'] ?? o['grandTotal'] ?? 0) as num)
          .toDouble();

  String _supplierName(Map<String, dynamic> o) =>
      (o['supplierName'] ?? o['supplier']?['name'] ?? o['vendor'] ?? 'Supplier')
          .toString();

  // ── Load orders ─────────────────────────────────────
  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    _deliveryStatusCache.clear();
    _paymentStatusCache.clear();

    final futures = await Future.wait([
      AuthService.instance.getMyOrders(status: _kStatusProcessing,     pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusOutForDelivery, pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusDelivered,      pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusCancelled,      pageSize: 20),
      AuthService.instance.getMyOrders(pageSize: 100),
    ]);

    if (!mounted) return;

    final all = <Map<String, dynamic>>[];
    String? err;

    for (final r in futures) {
      if (r.data == null) { if (!r.success) err ??= r.message; continue; }
      final items = _extractItems(r.data!);
      if (!r.success) err ??= r.message;
      all.addAll(items);
    }

    final seen  = <String>{};
    final dedup = <Map<String, dynamic>>[];
    for (final o in all) {
      final id = _orderId(o);
      if (id.isNotEmpty && seen.add(id)) dedup.add(o);
    }

    // Pre-populate obvious delivered statuses from order data
    for (final o in dedup) {
      final raw = o['status'] ?? o['orderStatus'];
      final oid = _orderId(o);
      if (oid.isEmpty) continue;
      if (raw == _kStatusDelivered ||
          (raw is String && raw.toLowerCase().contains('deliver'))) {
        _deliveryStatusCache[oid] = 'delivered';
      }
    }

    setState(() {
      _rawOrders = dedup;
      _isLoading = false;
      _error     = dedup.isEmpty ? err : null;
    });

    // Enrich with delivery AND payment statuses in parallel
    await Future.wait([
      _enrichDeliveryStatuses(dedup),
      _enrichPaymentStatuses(dedup),
    ]);
  }

  // ── Delivery status enrichment ───────────────────────
  Future<void> _enrichDeliveryStatuses(
      List<Map<String, dynamic>> orders) async {
    final toCheck = orders.where((o) {
      final oid = _orderId(o);
      if (oid.isEmpty) return false;
      final raw = o['status'] ?? o['orderStatus'];
      if (raw == _kStatusCancelled) return false;
      if (raw is String) {
        final n = raw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
        if (n == 'cancelled' || n == 'canceled') return false;
      }
      return true;
    }).toList();

    for (int i = 0; i < toCheck.length; i += 5) {
      final batch = toCheck.skip(i).take(5).toList();
      await Future.wait(batch.map(_fetchDeliveryStatus));
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchDeliveryStatus(Map<String, dynamic> order) async {
    final oid = _orderId(order);
    if (oid.isEmpty) return;
    try {
      final result = await AuthService.instance.getDeliveryByOrderId(oid);
      if (result.success && result.data != null) {
        final rawStatus = (result.data!['deliveryStatus'] ??
                result.data!['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (rawStatus.isEmpty || rawStatus == 'failed') return;
        if (mounted) setState(() => _deliveryStatusCache[oid] = rawStatus);
      }
    } catch (e) { debugPrint('⚠️ delivery enrich $oid: $e'); }
  }

  // ── Payment status enrichment ─────────────────────────
  // Fetches GET /api/payments/order/{orderId} for every order
  // in batches of 5 to avoid hammering the API.
  Future<void> _enrichPaymentStatuses(
      List<Map<String, dynamic>> orders) async {
    // Only fetch for orders that have an id
    final toFetch = orders
        .where((o) => _orderId(o).isNotEmpty)
        .toList();

    for (int i = 0; i < toFetch.length; i += 5) {
      final batch = toFetch.skip(i).take(5).toList();
      await Future.wait(batch.map(_fetchPaymentStatus));
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchPaymentStatus(Map<String, dynamic> order) async {
    final oid = _orderId(order);
    if (oid.isEmpty) return;
    try {
      final result = await AuthService.instance.getPaymentByOrderId(oid);
      debugPrint('💳 [PayStatus] orderId=$oid '
          'success=${result.success} data=${result.data}');
      if (result.success && result.data != null) {
        // Backend may return paymentStatus as int or as paymentStatusName
        final raw = result.data!['paymentStatus'] ??
            result.data!['status'];

        int? statusInt;
        if (raw is int) {
          statusInt = raw;
        } else if (raw is String) {
          // Map string names to int constants
          switch (raw.toLowerCase()) {
            case 'pending':   statusInt = _kPayPending;   break;
            case 'completed':
            case 'paid':
            case 'succeeded': statusInt = _kPayCompleted; break;
            case 'failed':    statusInt = _kPayFailed;    break;
            case 'cancelled':
            case 'canceled':  statusInt = _kPayCancelled; break;
            case 'refunded':  statusInt = _kPayRefunded;  break;
          }
        }

        if (statusInt != null && mounted) {
          setState(() => _paymentStatusCache[oid] = statusInt!);
          debugPrint('💳 [PayStatus] $oid → $statusInt');
        }
      }
    } catch (e) {
      debugPrint('⚠️ payment enrich $oid: $e');
    }
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> data) {
    for (final key in ['items', 'orders', 'data', 'results', 'value', 'records']) {
      if (data[key] is List) {
        return (data[key] as List).whereType<Map<String, dynamic>>().toList();
      }
    }
    if (data.containsKey('orderId') || data.containsKey('id')) return [data];
    return [];
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) {
      final da = DateTime.tryParse(
              (a['createdAt'] ?? a['date'] ?? '').toString()) ??
          DateTime(2000);
      final db = DateTime.tryParse(
              (b['createdAt'] ?? b['date'] ?? '').toString()) ??
          DateTime(2000);
      return db.compareTo(da);
    });
    return copy;
  }

  // ── Cancel order ────────────────────────────────────
  Future<void> _showCancelDialog(Map<String, dynamic> order) async {
    final ctrl      = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Are you sure you want to cancel this order?'),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Order')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order',
                style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await AuthService.instance.cancelOrder(
      orderId: _orderId(order),
      reason:  ctrl.text.trim().isEmpty
          ? 'Cancelled by customer'
          : ctrl.text.trim(),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
          ? 'Order cancelled successfully.'
          : (result.message ?? 'Failed to cancel order.')),
      backgroundColor:
          result.success ? AppColors.success : AppColors.error,
    ));
    if (result.success) _loadOrders();
  }

  // ── Raise dispute ───────────────────────────────────
  Future<void> _raiseDispute(Map<String, dynamic> order) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DisputeFormScreen(
          orderId:     _orderId(order),
          orderNumber: _orderNumber(order),
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Dispute submitted! We will review it within 2-3 days.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final active    = _sorted(_rawOrders.where(_isActive).toList());
    final completed = _sorted(_rawOrders.where(_isCompleted).toList());
    final all       = _sorted(_rawOrders);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh),
            tooltip:   'Refresh',
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       AppColors.white,
          labelColor:           AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: [
            Tab(text: 'Active${active.isNotEmpty ? " (${active.length})" : ""}'),
            Tab(text: 'Completed${completed.isNotEmpty ? " (${completed.length})" : ""}'),
            Tab(text: 'All (${all.length})'),
          ],
        ),
      ),
      body: _isLoading && _rawOrders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rawOrders.isEmpty
              ? _ErrorView(message: _error!, onRetry: _loadOrders)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTab(
                      orders:      active,
                      emptyMsg:    'No active orders',
                      emptyIcon:   Icons.local_shipping_outlined,
                      showDispute: false,
                    ),
                    _buildTab(
                      orders:      completed,
                      emptyMsg:    'No completed orders',
                      emptyIcon:   Icons.check_circle_outline,
                      showDispute: true,
                    ),
                    _buildTab(
                      orders:      all,
                      emptyMsg:    'No orders found',
                      emptyIcon:   Icons.receipt_long,
                      showDispute: true,
                    ),
                  ],
                ),
    );
  }

  Widget _buildTab({
    required List<Map<String, dynamic>> orders,
    required String   emptyMsg,
    required IconData emptyIcon,
    required bool     showDispute,
  }) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                    height: MediaQuery.of(context).size.height * 0.25),
                Center(child: Column(children: [
                  Icon(emptyIcon, size: 80, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(emptyMsg,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Pull down to refresh',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textHint)),
                ])),
              ],
            )
          : ListView.builder(
              padding:    const EdgeInsets.all(16),
              itemCount:  orders.length,
              itemBuilder: (_, i) {
                final o              = orders[i];
                final oid            = _orderId(o);
                final isDelivered    = _isCompleted(o);
                final showDisputeBtn = showDispute && isDelivered;
                final payStatus      = _paymentStatus(oid);

                return _OrderCard(
                  orderId:       oid,
                  orderNumber:   _orderNumber(o),
                  status:        _statusLabel(o),
                  supplierName:  _supplierName(o),
                  date:          _orderDate(o),
                  time:          _orderTime(o),
                  items:         _itemCount(o),
                  totalAmount:   _orderTotal(o),
                  canCancel:     _isActive(o),
                  showDispute:   showDisputeBtn,
                  paymentStatus: payStatus,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              OrderTrackingScreen(order: o))),
                  onCancel:  () => _showCancelDialog(o),
                  onDispute: () => _raiseDispute(o),
                );
              },
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PAYMENT STATUS BADGE
// ══════════════════════════════════════════════════════════
class _PaymentBadge extends StatelessWidget {
  final int status;
  const _PaymentBadge(this.status);

  ({String label, Color color, IconData icon}) get _info {
    switch (status) {
      case _kPayPending:
        return (label: 'Pending',   color: const Color(0xFFF59E0B), icon: Icons.hourglass_empty);
      case _kPayCompleted:
        return (label: 'Paid',      color: AppColors.success,       icon: Icons.check_circle_outline);
      case _kPayFailed:
        return (label: 'Failed',    color: AppColors.error,         icon: Icons.error_outline);
      case _kPayCancelled:
        return (label: 'Cancelled', color: AppColors.textSecondary, icon: Icons.cancel_outlined);
      case _kPayRefunded:
        return (label: 'Refunded',  color: const Color(0xFF3B82F6), icon: Icons.reply_outlined);
      default:
        return (label: 'Unknown',   color: AppColors.textHint,      icon: Icons.help_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        info.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: info.color.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(info.icon, size: 11, color: info.color),
        const SizedBox(width: 3),
        Text(info.label,
            style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      info.color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER CARD — with payment status badge
// ══════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final String orderId, orderNumber, status, supplierName, date, time;
  final int    items;
  final double totalAmount;
  final bool   canCancel, showDispute;

  /// Payment status int (1-5) from GET /api/payments/order/{id}.
  /// Null means the API hasn't responded yet or returned nothing.
  final int?   paymentStatus;

  final VoidCallback onTap, onCancel, onDispute;

  const _OrderCard({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.supplierName,
    required this.date,
    required this.time,
    required this.items,
    required this.totalAmount,
    required this.canCancel,
    required this.showDispute,
    required this.onTap,
    required this.onCancel,
    required this.onDispute,
    this.paymentStatus,
  });

  Color _statusColor() {
    switch (status.toLowerCase()) {
      case 'processing':       return AppColors.warning;
      case 'out for delivery': return AppColors.info;
      case 'delivered':        return AppColors.success;
      case 'cancelled':        return AppColors.error;
      default:                 return AppColors.textSecondary;
    }
  }

  IconData _statusIcon() {
    switch (status.toLowerCase()) {
      case 'processing':       return Icons.autorenew;
      case 'out for delivery': return Icons.local_shipping;
      case 'delivered':        return Icons.check_circle;
      case 'cancelled':        return Icons.cancel;
      default:                 return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color       = _statusColor();
    final isDelivered = status.toLowerCase() == 'delivered';
    final isCancelled = status.toLowerCase() == 'cancelled';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [

          // ── Header row ───────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_statusIcon(), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  orderNumber.isNotEmpty ? orderNumber : orderId,
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.store, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(supplierName,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text('$date • $time',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textHint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
            // ── Right column: amount + order status + payment badge ──
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('£${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize:   17,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary)),
              const SizedBox(height: 5),
              // Order status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      color)),
              ),
              const SizedBox(height: 5),
              // ── Payment status badge ─────────────────
              if (paymentStatus != null)
                _PaymentBadge(paymentStatus!)
              else
                // Subtle loading shimmer while fetching
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    SizedBox(
                      width: 9, height: 9,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.textHint),
                    ),
                    SizedBox(width: 4),
                    Text('Payment',
                        style: TextStyle(
                            fontSize: 10,
                            color:    AppColors.textHint)),
                  ]),
                ),
            ]),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Footer row ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.shopping_basket,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text('$items items',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ]),
              Row(children: [
                // Cancel button (active orders)
                if (canCancel)
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error)),
                    ),
                  ),

                // Raise Dispute (delivered orders only)
                if (showDispute)
                  GestureDetector(
                    onTap: onDispute,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.warning.withOpacity(0.6)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        const Icon(Icons.gavel,
                            size: 13, color: AppColors.warning),
                        const SizedBox(width: 4),
                        const Text('Dispute',
                            style: TextStyle(
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.warning)),
                      ]),
                    ),
                  ),

                // Track / View Details link
                if (!isCancelled)
                  Text(
                    isDelivered ? 'View Details' : 'Track Order',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color: isDelivered
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_ios,
                    size: 13, color: AppColors.textHint),
              ]),
            ],
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.error_outline,
                size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
}