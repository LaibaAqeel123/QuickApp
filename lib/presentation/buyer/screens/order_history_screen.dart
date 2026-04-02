import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/dispute_form_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/grouped_order_tracking_screen.dart';

const int _kStatusConfirmed      = 2;
const int _kStatusAccepted       = 3;
const int _kStatusSentToDriver   = 4;
const int _kStatusDelivered      = 5;
const int _kStatusCompleted      = 6;
const int _kStatusCancelled      = 7;
const int _kStatusOutForDelivery = 8;

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

  List<Map<String, dynamic>> _rawOrders    = [];
  List<_OrderGroup>          _groupedOrders = [];

  bool    _isLoading = true;
  String? _error;

  final Map<String, String> _deliveryStatusCache = {};
  final Map<String, int>    _paymentStatusCache  = {};

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

  // ── Status helpers ──────────────────────────────────
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
        case _kStatusConfirmed:      return 'Processing';
        case _kStatusAccepted:       return 'Processing';
        case _kStatusSentToDriver:   return 'Processing';
        case _kStatusOutForDelivery: return 'Out for Delivery';
        case _kStatusDelivered:      return 'Delivered';
        case _kStatusCompleted:      return 'Delivered';
        case _kStatusCancelled:      return 'Cancelled';
        default:                     return 'Processing';
      }
    }
    if (raw is String) {
      switch (raw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '')) {
        case 'processing':
        case 'pending':
        case 'confirmed':      return 'Processing';
        case 'outfordelivery':
        case 'intransit':      return 'Out for Delivery';
        case 'delivered':
        case 'completed':      return 'Delivered';
        case 'cancelled':
        case 'canceled':       return 'Cancelled';
        default:               return raw;
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

  int? _paymentStatus(String orderId) => _paymentStatusCache[orderId];

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

  // ── Group orders ────────────────────────────────────
  List<_OrderGroup> _groupOrders(List<Map<String, dynamic>> orders) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      final groupId = (o['groupOrderId'] ?? '').toString();
      final key     = groupId.isNotEmpty ? groupId : _orderId(o);
      groups.putIfAbsent(key, () => []).add(o);
    }
    return groups.entries.map((e) => _OrderGroup(
      groupId:        e.key,
      orders:         e.value,
      isMultiSupplier: e.value.length > 1,
    )).toList();
  }

  // ── Load orders ─────────────────────────────────────
  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    _deliveryStatusCache.clear();
    _paymentStatusCache.clear();

    final futures = await Future.wait([
      AuthService.instance.getMyOrders(status: _kStatusConfirmed,      pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusAccepted,       pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusSentToDriver,   pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusOutForDelivery, pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusDelivered,      pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusCompleted,      pageSize: 50),
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

    for (final o in dedup) {
      final raw = o['status'] ?? o['orderStatus'];
      final oid = _orderId(o);
      if (oid.isEmpty) continue;
      if (raw == _kStatusDelivered ||
          (raw is String && raw.toLowerCase().contains('deliver'))) {
        _deliveryStatusCache[oid] = 'delivered';
      }
    }

    _groupedOrders = _groupOrders(dedup);

    setState(() {
      _rawOrders = dedup;
      _isLoading = false;
      _error     = dedup.isEmpty ? err : null;
    });

    await Future.wait([
      _enrichDeliveryStatuses(dedup),
      _enrichPaymentStatuses(dedup),
    ]);
  }

  // ── Delivery enrichment ─────────────────────────────
  Future<void> _enrichDeliveryStatuses(
      List<Map<String, dynamic>> orders) async {
    final toCheck = orders.where((o) {
      final oid = _orderId(o);
      if (oid.isEmpty) return false;
      final raw = o['status'] ?? o['orderStatus'];
      if (raw == _kStatusCancelled || raw == _kStatusCompleted) return false;
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
            .toString().trim().toLowerCase();
        if (rawStatus.isEmpty || rawStatus == 'failed') return;
        if (mounted) setState(() => _deliveryStatusCache[oid] = rawStatus);
      }
    } catch (e) { debugPrint('⚠️ delivery enrich $oid: $e'); }
  }

  // ── Payment enrichment ──────────────────────────────
  Future<void> _enrichPaymentStatuses(
      List<Map<String, dynamic>> orders) async {
    final toFetch = orders.where((o) => _orderId(o).isNotEmpty).toList();
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
      if (result.success && result.data != null) {
        final raw = result.data!['paymentStatus'] ?? result.data!['status'];
        int? statusInt;
        if (raw is int) {
          statusInt = raw;
        } else if (raw is String) {
          switch (raw.toLowerCase()) {
            case 'pending':                        statusInt = _kPayPending;   break;
            case 'completed': case 'paid':
            case 'succeeded':                      statusInt = _kPayCompleted; break;
            case 'failed':                         statusInt = _kPayFailed;    break;
            case 'cancelled': case 'canceled':     statusInt = _kPayCancelled; break;
            case 'refunded':                       statusInt = _kPayRefunded;  break;
          }
        }
        if (statusInt != null && mounted) {
          setState(() => _paymentStatusCache[oid] = statusInt!);
        }
      }
    } catch (e) { debugPrint('⚠️ payment enrich $oid: $e'); }
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

  List<_OrderGroup> _sortedGroups(List<_OrderGroup> list) {
    final copy = List<_OrderGroup>.from(list);
    copy.sort((a, b) {
      final da = DateTime.tryParse(
          (a.primaryOrder['createdAt'] ?? a.primaryOrder['date'] ??
              a.primaryOrder['orderDate'] ?? '').toString()) ?? DateTime(2000);
      final db = DateTime.tryParse(
          (b.primaryOrder['createdAt'] ?? b.primaryOrder['date'] ??
              b.primaryOrder['orderDate'] ?? '').toString()) ?? DateTime(2000);
      return db.compareTo(da);
    });
    return copy;
  }

  // ── Cancel ──────────────────────────────────────────
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
      reason:  ctrl.text.trim().isEmpty ? 'Cancelled by customer' : ctrl.text.trim(),
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

  // ── Dispute ─────────────────────────────────────────
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
        content: Text('Dispute submitted! We will review it within 2-3 days.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeGroups    = _sortedGroups(_groupedOrders.where((g) => _isActive(g.primaryOrder)).toList());
    final completedGroups = _sortedGroups(_groupedOrders.where((g) => _isCompleted(g.primaryOrder)).toList());
    final allGroups       = _sortedGroups(_groupedOrders);

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
            Tab(text: 'Active${activeGroups.isNotEmpty ? " (${activeGroups.length})" : ""}'),
            Tab(text: 'Completed${completedGroups.isNotEmpty ? " (${completedGroups.length})" : ""}'),
            Tab(text: 'All (${allGroups.length})'),
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
            groups:      activeGroups,
            emptyMsg:    'No active orders',
            emptyIcon:   Icons.local_shipping_outlined,
            showDispute: false,
          ),
          _buildTab(
            groups:      completedGroups,
            emptyMsg:    'No completed orders',
            emptyIcon:   Icons.check_circle_outline,
            showDispute: true,
          ),
          _buildTab(
            groups:      allGroups,
            emptyMsg:    'No orders found',
            emptyIcon:   Icons.receipt_long,
            showDispute: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required List<_OrderGroup> groups,
    required String            emptyMsg,
    required IconData          emptyIcon,
    required bool              showDispute,
  }) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: groups.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
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
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          ])),
        ],
      )
          : ListView.builder(
        padding:    const EdgeInsets.all(16),
        itemCount:  groups.length,
        itemBuilder: (_, i) {
          final group          = groups[i];
          final o              = group.primaryOrder;
          final oid            = _orderId(o);
          final isDelivered    = _isCompleted(o);
          final showDisputeBtn = showDispute && isDelivered;
          final payStatus      = _paymentStatus(oid);

          final supplierLabel = group.isMultiSupplier
              ? '${group.orders.length} Suppliers'
              : _supplierName(o);

          return _OrderCard(
            orderId:         oid,
            orderNumber:     _orderNumber(o),
            status:          _statusLabel(o),
            supplierName:    supplierLabel,
            date:            _orderDate(o),
            time:            _orderTime(o),
            items:           group.totalItems,
            totalAmount:     group.grandTotal,
            canCancel:       _isActive(o),
            showDispute:     showDisputeBtn,
            paymentStatus:   payStatus,
            isMultiSupplier: group.isMultiSupplier,
            onTap: () {
              if (group.isMultiSupplier) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupedOrderTrackingScreen(
                      groupId: group.groupId,
                      orders:  group.orders,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(order: o)),
                );
              }
            },
            onCancel:  () => _showCancelDialog(o),
            onDispute: () => _raiseDispute(o),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER GROUP MODEL
// ══════════════════════════════════════════════════════════
class _OrderGroup {
  final String                     groupId;
  final List<Map<String, dynamic>> orders;
  final bool                       isMultiSupplier;

  const _OrderGroup({
    required this.groupId,
    required this.orders,
    required this.isMultiSupplier,
  });

  Map<String, dynamic> get primaryOrder => orders.first;

  double get grandTotal => orders.fold(0.0, (sum, o) =>
  sum + ((o['total'] ?? o['totalAmount'] ?? 0) as num).toDouble());

  int get totalItems => orders.fold(0, (sum, o) {
    final items = o['items'] ?? o['orderItems'];
    if (items is List) return sum + items.length;
    final c = o['itemCount'] ?? 0;
    return sum + (c as num).toInt();
  });
}

// ══════════════════════════════════════════════════════════
//  PAYMENT BADGE
// ══════════════════════════════════════════════════════════
class _PaymentBadge extends StatelessWidget {
  final int status;
  const _PaymentBadge(this.status);

  ({String label, Color color, IconData icon}) get _info {
    switch (status) {
      case _kPayPending:   return (label: 'Pending',   color: const Color(0xFFF59E0B), icon: Icons.hourglass_empty);
      case _kPayCompleted: return (label: 'Paid',      color: AppColors.success,       icon: Icons.check_circle_outline);
      case _kPayFailed:    return (label: 'Failed',    color: AppColors.error,         icon: Icons.error_outline);
      case _kPayCancelled: return (label: 'Cancelled', color: AppColors.textSecondary, icon: Icons.cancel_outlined);
      case _kPayRefunded:  return (label: 'Refunded',  color: const Color(0xFF3B82F6), icon: Icons.reply_outlined);
      default:             return (label: 'Unknown',   color: AppColors.textHint,      icon: Icons.help_outline);
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
                fontSize: 11, fontWeight: FontWeight.w600, color: info.color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER CARD
// ══════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final String       orderId, orderNumber, status, supplierName, date, time;
  final int          items;
  final double       totalAmount;
  final bool         canCancel, showDispute, isMultiSupplier;
  final int?         paymentStatus;
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
    this.isMultiSupplier = false,
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
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [

          // ── Header ───────────────────────────────────
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Multi-supplier badge
                    if (isMultiSupplier)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.storefront,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(supplierName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ]),
                      ),
                    Text(
                      orderNumber.isNotEmpty ? orderNumber : orderId,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (!isMultiSupplier)
                      Row(children: [
                        const Icon(Icons.store,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(supplierName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
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
            // ── Right column ─────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('£${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const SizedBox(height: 5),
              if (paymentStatus != null)
                _PaymentBadge(paymentStatus!)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 9, height: 9,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.textHint),
                    ),
                    SizedBox(width: 4),
                    Text('Payment',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textHint)),
                  ]),
                ),
            ]),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Footer ───────────────────────────────────
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
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.gavel,
                            size: 13, color: AppColors.warning),
                        const SizedBox(width: 4),
                        const Text('Dispute',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning)),
                      ]),
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
            icon:  const Icon(Icons.refresh),
            label: const Text('Retry')),
      ]),
    ),
  );
}