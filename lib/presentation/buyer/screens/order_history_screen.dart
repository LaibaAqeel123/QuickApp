import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

// ── Order status integer mapping (from API docs) ──────────
// Adjust these values if the backend uses different ints
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

  // Data per tab — null means not loaded yet
  List<Map<String, dynamic>> _activeOrders    = [];
  List<Map<String, dynamic>> _completedOrders = [];
  List<Map<String, dynamic>> _allOrders       = [];

  bool _isLoadingActive    = true;
  bool _isLoadingCompleted = true;
  bool _isLoadingAll       = true;

  String? _activeError;
  String? _completedError;
  String? _allError;

  // Pagination
  int _allPage = 1;
  bool _allHasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadActiveOrders();
    _loadCompletedOrders();
    _loadAllOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // Reload if tab is newly selected and data is empty / errored
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0: if (_activeOrders.isEmpty)    _loadActiveOrders();    break;
      case 1: if (_completedOrders.isEmpty) _loadCompletedOrders(); break;
      case 2: if (_allOrders.isEmpty)       _loadAllOrders();       break;
    }
  }

  // ── Safe field helpers ──────────────────────────────────
  String _orderId(Map<String, dynamic> o) =>
      (o['id'] ?? o['orderId'] ?? o['orderNumber'] ?? '').toString();

  String _orderDate(Map<String, dynamic> o) {
    final raw = o['createdAt'] ?? o['date'] ?? o['orderDate'];
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

  String _orderTime(Map<String, dynamic> o) {
    final raw = o['createdAt'] ?? o['date'] ?? o['orderDate'];
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min  = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    } catch (_) {
      return '';
    }
  }

  String _statusLabel(Map<String, dynamic> o) {
    final raw = o['status'] ?? o['orderStatus'];
    if (raw is String) return raw;
    if (raw is int) {
      switch (raw) {
        case _kStatusProcessing:     return 'Processing';
        case _kStatusOutForDelivery: return 'Out for Delivery';
        case _kStatusDelivered:      return 'Delivered';
        case _kStatusCancelled:      return 'Cancelled';
        default: return 'Unknown';
      }
    }
    return 'Unknown';
  }

  int _itemCount(Map<String, dynamic> o) {
    final items = o['items'] ?? o['orderItems'];
    if (items is List) return items.length;
    final count = o['itemCount'] ?? o['totalItems'];
    if (count is num) return count.toInt();
    return 0;
  }

  double _orderTotal(Map<String, dynamic> o) {
    final raw = o['total'] ?? o['totalAmount'] ?? o['grandTotal'] ?? 0;
    return (raw as num).toDouble();
  }

  String _supplierName(Map<String, dynamic> o) {
    final s = o['supplierName'] ?? o['supplier']?['name'] ?? o['vendor'] ?? 'Supplier';
    return s.toString();
  }

  bool _isActive(Map<String, dynamic> o) {
    final label = _statusLabel(o).toLowerCase();
    return label == 'processing' || label == 'out for delivery';
  }

  bool _isCompleted(Map<String, dynamic> o) =>
      _statusLabel(o).toLowerCase() == 'delivered';

  // ── API Calls ───────────────────────────────────────────
  Future<void> _loadActiveOrders() async {
    setState(() { _isLoadingActive = true; _activeError = null; });

    // Fetch both processing and out-for-delivery — API filters by status int
    final results = await Future.wait([
      AuthService.instance.getMyOrders(status: _kStatusProcessing,     pageSize: 50),
      AuthService.instance.getMyOrders(status: _kStatusOutForDelivery, pageSize: 50),
    ]);

    if (!mounted) return;

    final combined = <Map<String, dynamic>>[];
    String? error;

    for (final r in results) {
      if (r.success && r.data != null) {
        final items = _extractItems(r.data!);
        combined.addAll(items);
      } else if (r.message != null) {
        error = r.message;
      }
    }

    setState(() {
      _activeOrders    = combined;
      _isLoadingActive = false;
      _activeError     = combined.isEmpty ? error : null;
    });
  }

  Future<void> _loadCompletedOrders() async {
    setState(() { _isLoadingCompleted = true; _completedError = null; });

    final result = await AuthService.instance
        .getMyOrders(status: _kStatusDelivered, pageSize: 50);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _completedOrders    = _extractItems(result.data ?? {});
        _isLoadingCompleted = false;
      });
    } else {
      setState(() {
        _isLoadingCompleted = false;
        _completedError     = result.message;
      });
    }
  }

  Future<void> _loadAllOrders({bool refresh = false}) async {
    if (refresh) {
      _allPage    = 1;
      _allHasMore = true;
      setState(() { _allOrders = []; _isLoadingAll = true; _allError = null; });
    } else {
      setState(() { _isLoadingAll = true; _allError = null; });
    }

    final result = await AuthService.instance
        .getMyOrders(page: _allPage, pageSize: 10);

    if (!mounted) return;

    if (result.success) {
      final newItems = _extractItems(result.data ?? {});
      setState(() {
        _allOrders   = refresh ? newItems : [..._allOrders, ...newItems];
        _allHasMore  = newItems.length >= 10;
        _allPage++;
        _isLoadingAll = false;
      });
    } else {
      setState(() {
        _isLoadingAll = false;
        _allError     = result.message;
      });
    }
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> data) {
    List<dynamic> raw = [];
    if (data['items']  is List) raw = data['items']  as List;
    if (data['orders'] is List) raw = data['orders'] as List;
    if (data['data']   is List) raw = data['data']   as List;
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ── Cancel Order ────────────────────────────────────────
  Future<void> _showCancelDialog(Map<String, dynamic> order) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText:   'Reason (optional)',
                border:      OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style:    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
      reason:  reasonController.text.trim().isEmpty
          ? 'Cancelled by customer'
          : reasonController.text.trim(),
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Order cancelled successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Refresh all tabs
      _loadActiveOrders();
      _loadAllOrders(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(result.message ?? 'Failed to cancel order.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Tab
          _OrderListView(
            isLoading:  _isLoadingActive,
            error:      _activeError,
            orders:     _activeOrders,
            onRetry:    _loadActiveOrders,
            onRefresh:  _loadActiveOrders,
            statusLabel: _statusLabel,
            itemCount:  _itemCount,
            total:      _orderTotal,
            date:       _orderDate,
            time:       _orderTime,
            supplier:   _supplierName,
            orderId:    _orderId,
            onTap: (order) {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(order: order)));
            },
            onCancel:   _isActive,
            onCancelTap: _showCancelDialog,
          ),

          // Completed Tab
          _OrderListView(
            isLoading:  _isLoadingCompleted,
            error:      _completedError,
            orders:     _completedOrders,
            onRetry:    _loadCompletedOrders,
            onRefresh:  _loadCompletedOrders,
            statusLabel: _statusLabel,
            itemCount:  _itemCount,
            total:      _orderTotal,
            date:       _orderDate,
            time:       _orderTime,
            supplier:   _supplierName,
            orderId:    _orderId,
            onTap: (order) {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(order: order)));
            },
            onCancel:    (_) => false,
            onCancelTap: _showCancelDialog,
          ),

          // All Tab
          _OrderListView(
            isLoading:  _isLoadingAll,
            error:      _allError,
            orders:     _allOrders,
            onRetry:    () => _loadAllOrders(refresh: true),
            onRefresh:  () => _loadAllOrders(refresh: true),
            statusLabel: _statusLabel,
            itemCount:  _itemCount,
            total:      _orderTotal,
            date:       _orderDate,
            time:       _orderTime,
            supplier:   _supplierName,
            orderId:    _orderId,
            onTap: (order) {
              Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(order: order)));
            },
            onCancel:   _isActive,
            onCancelTap: _showCancelDialog,
            hasMore:    _allHasMore,
            onLoadMore: _loadAllOrders,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER LIST VIEW
// ══════════════════════════════════════════════════════════
class _OrderListView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> orders;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final String Function(Map<String, dynamic>) statusLabel;
  final int    Function(Map<String, dynamic>) itemCount;
  final double Function(Map<String, dynamic>) total;
  final String Function(Map<String, dynamic>) date;
  final String Function(Map<String, dynamic>) time;
  final String Function(Map<String, dynamic>) supplier;
  final String Function(Map<String, dynamic>) orderId;
  final void Function(Map<String, dynamic>) onTap;
  final bool   Function(Map<String, dynamic>) onCancel;
  final void   Function(Map<String, dynamic>) onCancelTap;
  final bool hasMore;
  final VoidCallback? onLoadMore;

  const _OrderListView({
    required this.isLoading,
    required this.error,
    required this.orders,
    required this.onRetry,
    required this.onRefresh,
    required this.statusLabel,
    required this.itemCount,
    required this.total,
    required this.date,
    required this.time,
    required this.supplier,
    required this.orderId,
    required this.onTap,
    required this.onCancel,
    required this.onCancelTap,
    this.hasMore   = false,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 80, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('No orders found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton(
                  onPressed: onLoadMore,
                  child: const Text('Load More'),
                ),
              ),
            );
          }

          final order = orders[index];
          return _OrderCard(
            orderId:     orderId(order),
            status:      statusLabel(order),
            supplierName: supplier(order),
            date:        date(order),
            time:        time(order),
            items:       itemCount(order),
            totalAmount: total(order),
            canCancel:   onCancel(order),
            onTap:       () => onTap(order),
            onCancel:    () => onCancelTap(order),
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
  final String orderId;
  final String status;
  final String supplierName;
  final String date;
  final String time;
  final int    items;
  final double totalAmount;
  final bool   canCancel;
  final VoidCallback onTap;
  final VoidCallback onCancel;

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
      case 'processing':      return AppColors.warning;
      case 'out for delivery': return AppColors.info;
      case 'delivered':       return AppColors.success;
      case 'cancelled':       return AppColors.error;
      default:                return AppColors.textSecondary;
    }
  }

  IconData _statusIcon() {
    switch (status.toLowerCase()) {
      case 'processing':      return Icons.autorenew;
      case 'out for delivery': return Icons.local_shipping;
      case 'delivered':       return Icons.check_circle;
      case 'cancelled':       return Icons.cancel;
      default:                return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(), color: color, size: 24),
                ),
                const SizedBox(width: 12),

                // Order Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderId,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.store, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(supplierName,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('$date • $time',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textHint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),

                // Price & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('£${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('$items items',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    if (canCancel)
                      GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
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
                    if (status.toLowerCase() != 'delivered' &&
                        status.toLowerCase() != 'cancelled')
                      const Text('Track Order',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.textHint),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}