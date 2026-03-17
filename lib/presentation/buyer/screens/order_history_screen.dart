import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

const int _kStatusProcessing     = 1;
const int _kStatusOutForDelivery = 2;
const int _kStatusDelivered      = 3;
const int _kStatusCancelled      = 4;

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

  // deliveryStatus cache: orderId → lowercase deliveryStatus from delivery API
  // "failed" is intentionally NEVER stored here — we skip it so those
  // orders fall back to their own order status field.
  final Map<String, String> _deliveryStatusCache = {};

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

  // ═══════════════════════════════════════════════════════════════════════
  //  STATUS RESOLUTION
  //
  //  Priority:
  //  1. delivery cache (only stores actionable statuses, never "failed")
  //  2. order's own status field
  // ═══════════════════════════════════════════════════════════════════════
  String _statusLabel(Map<String, dynamic> o) {
    final oid    = _orderId(o);
    final cached = (_deliveryStatusCache[oid] ?? '').toLowerCase().trim();

    if (cached == 'delivered')                              return 'Delivered';
    if (cached == 'pickedup' || cached == 'picked_up')     return 'Out for Delivery';
    if (cached == 'accepted' || cached == 'assigned')      return 'Processing';
    if (cached == 'pendingassignment' ||
        cached == 'pending_assignment')                     return 'Processing';

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
        case 'confirmed':        return 'Processing';
        case 'outfordelivery':
        case 'intransit':        return 'Out for Delivery';
        case 'delivered':
        case 'completed':        return 'Delivered';
        case 'cancelled':
        case 'canceled':         return 'Cancelled';
        default:                 return raw;
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

  // ═══════════════════════════════════════════════════════════════════════
  //  FIELD HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  String _orderId(Map<String, dynamic> o) =>
      (o['id'] ?? o['orderId'] ?? o['orderNumber'] ?? '').toString();

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

  // ═══════════════════════════════════════════════════════════════════════
  //  LOAD ALL ORDERS
  //
  //  Strategy:
  //  Step 1 — fetch all 4 status buckets in parallel (status=1,2,3,4)
  //  Step 2 — fetch with NO status filter as a fallback so we catch any
  //            orders the backend forgot to put in the right bucket
  //            (confirmed issue: completed orders stay in status=2)
  //  Step 3 — de-duplicate by orderId
  //  Step 4 — enrich every non-cancelled order with delivery API to get
  //            the real delivery status (catches backend not setting status=3)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    _deliveryStatusCache.clear();

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📋 [Orders] Starting full order fetch...');

    // ── Step 1: Fetch all 4 status buckets + no-status fallback ──────────
    final futures = await Future.wait([
      AuthService.instance.getMyOrders(status: _kStatusProcessing,     pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusOutForDelivery, pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusDelivered,      pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusCancelled,      pageSize: 20),
      // No-status fetch: catches orders the backend forgot to bucket correctly
      AuthService.instance.getMyOrders(pageSize: 100),
    ]);

    if (!mounted) return;

    final labels = [
      'Processing(1)', 'OutForDelivery(2)', 'Delivered(3)',
      'Cancelled(4)', 'AllOrders(no-filter)',
    ];

    final all   = <Map<String, dynamic>>[];
    String? err;

    for (int i = 0; i < futures.length; i++) {
      final r     = futures[i];
      final label = labels[i];
      debugPrint('📋 [$label] success=${r.success}');
      if (r.data == null) {
        if (!r.success) err ??= r.message;
        debugPrint('📋 [$label] data=NULL  message=${r.message}');
        continue;
      }
      final items = _extractItems(r.data!);
      debugPrint('📋 [$label] → ${items.length} orders');
      for (final item in items) {
        debugPrint('   id=${_orderId(item)}  status=${item['status'] ?? item['orderStatus']}');
      }
      if (!r.success) err ??= r.message;
      all.addAll(items);
    }

    // ── Step 2: De-duplicate by orderId ───────────────────────────────────
    final seen  = <String>{};
    final dedup = <Map<String, dynamic>>[];
    for (final o in all) {
      final id = _orderId(o);
      if (id.isNotEmpty && seen.add(id)) dedup.add(o);
    }
    debugPrint('📋 [Orders] Total unique: ${dedup.length}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Pre-seed cache for orders order-API already confirms as delivered
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

    // ── Step 3: Enrich with delivery API ─────────────────────────────────
    await _enrichDeliveryStatuses(dedup);
  }

  // ── Enrich every non-cancelled order via the delivery API ──────────────
  //
  //  This is the KEY fix for the backend bug where orders stay at
  //  status=2 (OutForDelivery) even after delivery is completed.
  //  The delivery API correctly returns "Delivered" — we use that
  //  to override the display status in _statusLabel().
  Future<void> _enrichDeliveryStatuses(
      List<Map<String, dynamic>> orders) async {
    final toCheck = orders.where((o) {
      final oid = _orderId(o);
      if (oid.isEmpty) return false;
      // Skip only orders already confirmed cancelled by the order API
      final raw = o['status'] ?? o['orderStatus'];
      if (raw == _kStatusCancelled) return false;
      if (raw is String) {
        final n = raw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
        if (n == 'cancelled' || n == 'canceled') return false;
      }
      return true;
    }).toList();

    debugPrint('📦 [Enrich] Checking ${toCheck.length} orders...');

    for (int i = 0; i < toCheck.length; i += 5) {
      final batch = toCheck.skip(i).take(5).toList();
      await Future.wait(batch.map(_fetchDeliveryStatus));
    }

    if (mounted) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📦 [Enrich] Final cache:');
      _deliveryStatusCache.forEach((k, v) => debugPrint('   $k → $v'));
      final active    = _rawOrders.where(_isActive).length;
      final completed = _rawOrders.where(_isCompleted).length;
      debugPrint('🗂  active=$active  completed=$completed  all=${_rawOrders.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      setState(() {});
    }
  }

  Future<void> _fetchDeliveryStatus(Map<String, dynamic> order) async {
    final oid = _orderId(order);
    if (oid.isEmpty) return;

    try {
      final result = await AuthService.instance.getDeliveryByOrderId(oid);

      if (result.success && result.data != null) {
        final data      = result.data!;
        final rawStatus = (data['deliveryStatus'] ??
                data['status'] ??
                '').toString().trim().toLowerCase();

        debugPrint('📦 [Enrich] order=$oid → "$rawStatus"');

        // NEVER cache "failed" — assignment failed ≠ order failed.
        // Not caching it means _statusLabel falls through to the order's
        // own status, which correctly shows Processing / Out for Delivery.
        if (rawStatus.isEmpty || rawStatus == 'failed') {
          debugPrint('📦 [Enrich] order=$oid → skipping "$rawStatus"');
          return;
        }

        if (mounted) {
          setState(() => _deliveryStatusCache[oid] = rawStatus);
        }
      } else {
        debugPrint('📦 [Enrich] order=$oid → no delivery record (${result.message})');
      }
    } catch (e) {
      debugPrint('⚠️  [Enrich] order=$oid → $e');
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

  // ═══════════════════════════════════════════════════════════════════════
  //  CANCEL ORDER
  // ═══════════════════════════════════════════════════════════════════════
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
      backgroundColor: result.success ? AppColors.success : AppColors.error,
    ));
    if (result.success) _loadOrders();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final active    = _sorted(_rawOrders.where(_isActive).toList());
    final completed = _sorted(_rawOrders.where(_isCompleted).toList());
    final all       = _sorted(_rawOrders);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
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
                      orders:    active,
                      emptyMsg:  'No active orders',
                      emptyIcon: Icons.local_shipping_outlined,
                    ),
                    _buildTab(
                      orders:    completed,
                      emptyMsg:  'No completed orders',
                      emptyIcon: Icons.check_circle_outline,
                    ),
                    _buildTab(
                      orders:    all,
                      emptyMsg:  'No orders found',
                      emptyIcon: Icons.receipt_long,
                    ),
                  ],
                ),
    );
  }

  Widget _buildTab({
    required List<Map<String, dynamic>> orders,
    required String   emptyMsg,
    required IconData emptyIcon,
  }) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(children: [
                    Icon(emptyIcon, size: 80, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(emptyMsg,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Pull down to refresh',
                        style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ]),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                return _OrderCard(
                  orderId:      _orderId(o),
                  status:       _statusLabel(o),
                  supplierName: _supplierName(o),
                  date:         _orderDate(o),
                  time:         _orderTime(o),
                  items:        _itemCount(o),
                  totalAmount:  _orderTotal(o),
                  canCancel:    _isActive(o),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: o))),
                  onCancel: () => _showCancelDialog(o),
                );
              },
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER CARD
// ══════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final String orderId, status, supplierName, date, time;
  final int    items;
  final double totalAmount;
  final bool   canCancel;
  final VoidCallback onTap, onCancel;

  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.supplierName,
    required this.date,
    required this.time,
    required this.items,
    required this.totalAmount,
    required this.canCancel,
    required this.onTap,
    required this.onCancel,
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
        child: Column(children: [
          // ── Header row ──────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_statusIcon(), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orderId,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('£${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ]),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Footer row ───────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.shopping_basket,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text('$items items',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
            Row(children: [
              if (canCancel)
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
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
              if (!isCancelled)
                Text(
                  isDelivered ? 'View Details' : 'Track Order',
                  style: TextStyle(
                    fontSize: 13,
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
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
}