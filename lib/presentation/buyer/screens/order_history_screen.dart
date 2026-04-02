import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/dispute_form_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/grouped_order_tracking_screen.dart';

// ── INCOMING: granular status codes matching real API ────
const int _kStatusConfirmed      = 2;
const int _kStatusAccepted       = 3;
const int _kStatusSentToDriver   = 4;
const int _kStatusOutForDelivery = 8;
const int _kStatusDelivered      = 5;
const int _kStatusCompleted      = 6;
const int _kStatusCancelled      = 7;

const int _kPayPending   = 1;
const int _kPayCompleted = 2;
const int _kPayFailed    = 3;
const int _kPayCancelled = 4;
const int _kPayRefunded  = 5;

// ══════════════════════════════════════════════════════════
//  FILTER MODEL  (CURRENT — kept in full)
// ══════════════════════════════════════════════════════════
class _OrderFilter {
  Set<String> orderStatuses;
  Set<int>    paymentStatuses;
  DateTime?   dateFrom;
  DateTime?   dateTo;
  bool        newestFirst;

  _OrderFilter({
    Set<String>? orderStatuses,
    Set<int>?    paymentStatuses,
    this.dateFrom,
    this.dateTo,
    this.newestFirst = true,
  })  : orderStatuses   = orderStatuses   ?? {},
        paymentStatuses = paymentStatuses ?? {};

  bool get hasActiveFilters =>
      orderStatuses.isNotEmpty  ||
      paymentStatuses.isNotEmpty ||
      dateFrom != null           ||
      dateTo   != null           ||
      !newestFirst;

  int get activeFilterCount {
    int c = 0;
    if (orderStatuses.isNotEmpty)             c++;
    if (paymentStatuses.isNotEmpty)           c++;
    if (dateFrom != null || dateTo != null)   c++;
    if (!newestFirst)                         c++;
    return c;
  }

  _OrderFilter copyWith({
    Set<String>? orderStatuses,
    Set<int>?    paymentStatuses,
    DateTime?    dateFrom,
    DateTime?    dateTo,
    bool?        newestFirst,
    bool         clearDateFrom = false,
    bool         clearDateTo   = false,
  }) => _OrderFilter(
        orderStatuses:   orderStatuses   ?? Set.from(this.orderStatuses),
        paymentStatuses: paymentStatuses ?? Set.from(this.paymentStatuses),
        dateFrom:  clearDateFrom ? null : (dateFrom  ?? this.dateFrom),
        dateTo:    clearDateTo   ? null : (dateTo    ?? this.dateTo),
        newestFirst: newestFirst ?? this.newestFirst,
      );

  _OrderFilter reset() => _OrderFilter(newestFirst: true);
}

// ══════════════════════════════════════════════════════════
//  ORDER GROUP MODEL  (INCOMING — multi-supplier grouping)
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
    if (items is List) return sum + (items as List).length;
    final c = o['itemCount'] ?? 0;
    return sum + (c as num).toInt();
  });
}

// ══════════════════════════════════════════════════════════
//  DELIVERY STATUS TRANSLATOR  (CURRENT — keeps translation at fetch time)
//
//  Maps raw backend delivery-status strings → customer-facing labels.
//  Returns null for terminal/unknown states so the order's own
//  status field shows through.
//
//  With the corrected int constants (INCOMING), OutForDelivery is
//  now int 8, so the backend no longer "sets it too early".
//  The delivery record is still the authoritative granular source.
// ══════════════════════════════════════════════════════════
String? _deliveryStatusToLabel(String raw) {
  final s = raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  switch (s) {
    case 'pendingassignment':
    case 'pending':
    case 'created':
    case 'new':
      return 'Processing';

    case 'accepted':
    case 'assigned':
    case 'driverassigned':
      return 'Processing';

    case 'pickedup':
    case 'pickeddup':
    case 'intransit':
    case 'ontheway':
    case 'enroute':
      return 'Out for Delivery';

    case 'delivered':
    case 'completed':
    case 'done':
      return 'Delivered';

    case 'cancelled':
    case 'canceled':
    case 'failed':
    case 'rejected':
      return null;   // terminal — let order status speak

    default:
      return null;
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER HISTORY SCREEN
// ══════════════════════════════════════════════════════════
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _rawOrders     = [];
  List<_OrderGroup>          _groupedOrders = [];

  bool    _isLoading = true;
  String? _error;

  // CURRENT: stores translated customer-facing label (not raw string)
  final Map<String, String> _deliveryStatusCache = {};
  final Map<String, int>    _paymentStatusCache  = {};

  // CURRENT: filter state
  _OrderFilter _filter = _OrderFilter();

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
    // CURRENT: cache stores translated label directly
    final cached = _deliveryStatusCache[oid];
    if (cached != null && cached.isNotEmpty) return cached;

    // INCOMING: correct int constants — no longer need OutForDelivery workaround
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
      return '${dt.day.toString().padLeft(2,'0')}/'
          '${dt.month.toString().padLeft(2,'0')}/${dt.year}';
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
    if (items is List) return (items as List).length;
    final c = o['itemCount'] ?? o['totalItems'];
    return c is num ? c.toInt() : 0;
  }

  double _orderTotal(Map<String, dynamic> o) =>
      ((o['total'] ?? o['totalAmount'] ?? o['grandTotal'] ?? 0) as num)
          .toDouble();

  String _supplierName(Map<String, dynamic> o) =>
      (o['supplierName'] ?? o['supplier']?['name'] ?? o['vendor'] ?? 'Supplier')
          .toString();

  DateTime? _orderDateTime(Map<String, dynamic> o) {
    final raw = o['createdAt'] ?? o['date'] ?? o['orderDate'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  // ── INCOMING: group orders by groupOrderId ──────────
  List<_OrderGroup> _groupOrders(List<Map<String, dynamic>> orders) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      final groupId = (o['groupOrderId'] ?? '').toString();
      final key     = groupId.isNotEmpty ? groupId : _orderId(o);
      groups.putIfAbsent(key, () => []).add(o);
    }
    return groups.entries.map((e) => _OrderGroup(
      groupId:         e.key,
      orders:          e.value,
      isMultiSupplier: e.value.length > 1,
    )).toList();
  }

  // ── CURRENT: filter + sort ──────────────────────────
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    final result = list.where((o) {
      final oid = _orderId(o);

      if (_filter.orderStatuses.isNotEmpty &&
          !_filter.orderStatuses.contains(_statusLabel(o))) return false;

      if (_filter.paymentStatuses.isNotEmpty) {
        final ps = _paymentStatusCache[oid];
        if (ps == null || !_filter.paymentStatuses.contains(ps)) return false;
      }

      final dt = _orderDateTime(o);
      if (_filter.dateFrom != null && dt != null &&
          dt.isBefore(_filter.dateFrom!)) return false;

      if (_filter.dateTo != null && dt != null) {
        final end = DateTime(_filter.dateTo!.year, _filter.dateTo!.month,
            _filter.dateTo!.day, 23, 59, 59);
        if (dt.isAfter(end)) return false;
      }

      return true;
    }).toList();

    result.sort((a, b) {
      final da = _orderDateTime(a) ?? DateTime(2000);
      final db = _orderDateTime(b) ?? DateTime(2000);
      return _filter.newestFirst ? db.compareTo(da) : da.compareTo(db);
    });

    return result;
  }

  // Apply filter then group — BOTH combined
  List<_OrderGroup> _applyFilterAndGroup(List<Map<String, dynamic>> list) {
    final filtered = _applyFilter(list);
    final groups   = _groupOrders(filtered);
    // Preserve sort order: sort groups by their primary order's date
    groups.sort((a, b) {
      final da = _orderDateTime(a.primaryOrder) ?? DateTime(2000);
      final db = _orderDateTime(b.primaryOrder) ?? DateTime(2000);
      return _filter.newestFirst ? db.compareTo(da) : da.compareTo(db);
    });
    return groups;
  }

  // ── Load orders ─────────────────────────────────────
  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    _deliveryStatusCache.clear();
    _paymentStatusCache.clear();

    // INCOMING: fetch all granular status buckets
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

    final all  = <Map<String, dynamic>>[];
    String? err;

    for (final r in futures) {
      if (r.data == null) { if (!r.success) err ??= r.message; continue; }
      all.addAll(_extractItems(r.data!));
      if (!r.success) err ??= r.message;
    }

    final seen  = <String>{};
    final dedup = <Map<String, dynamic>>[];
    for (final o in all) {
      final id = _orderId(o);
      if (id.isNotEmpty && seen.add(id)) dedup.add(o);
    }

    setState(() {
      _rawOrders     = dedup;
      _groupedOrders = _groupOrders(dedup);
      _isLoading     = false;
      _error         = dedup.isEmpty ? err : null;
    });

    // Enrich both delivery and payment in parallel
    await Future.wait([
      _enrichDeliveryStatuses(dedup),
      _enrichPaymentStatuses(dedup),
    ]);
  }

  // ── Delivery enrichment (CURRENT approach: translate at fetch time) ──
  Future<void> _enrichDeliveryStatuses(List<Map<String, dynamic>> orders) async {
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
      await Future.wait(toCheck.skip(i).take(5).map(_fetchDeliveryStatus));
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
            .toString().trim();

        if (rawStatus.isEmpty) return;

        // CURRENT: translate to customer-facing label at fetch time
        final label = _deliveryStatusToLabel(rawStatus);
        if (label == null) return;   // terminal/unknown — let order status show

        debugPrint('📦 [delivery] $oid: "$rawStatus" → "$label"');
        if (mounted) setState(() => _deliveryStatusCache[oid] = label);
      }
    } catch (e) { debugPrint('⚠️ delivery enrich $oid: $e'); }
  }

  // ── Payment enrichment ──────────────────────────────
  Future<void> _enrichPaymentStatuses(List<Map<String, dynamic>> orders) async {
    final toFetch = orders.where((o) => _orderId(o).isNotEmpty).toList();
    for (int i = 0; i < toFetch.length; i += 5) {
      await Future.wait(toFetch.skip(i).take(5).map(_fetchPaymentStatus));
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
    for (final key in ['items','orders','data','results','value','records']) {
      if (data[key] is List) {
        return (data[key] as List).whereType<Map<String, dynamic>>().toList();
      }
    }
    if (data.containsKey('orderId') || data.containsKey('id')) return [data];
    return [];
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

  // ══════════════════════════════════════════════════════
  //  FILTER BOTTOM SHEET  (CURRENT — kept in full)
  // ══════════════════════════════════════════════════════
  Future<void> _showFilterSheet() async {
    _OrderFilter temp = _filter.copyWith();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void toggleOrderStatus(String s) {
            setSheetState(() {
              final c = Set<String>.from(temp.orderStatuses);
              c.contains(s) ? c.remove(s) : c.add(s);
              temp = temp.copyWith(orderStatuses: c);
            });
          }

          void togglePayStatus(int s) {
            setSheetState(() {
              final c = Set<int>.from(temp.paymentStatuses);
              c.contains(s) ? c.remove(s) : c.add(s);
              temp = temp.copyWith(paymentStatuses: c);
            });
          }

          Future<void> pickDate(bool isFrom) async {
            final now    = DateTime.now();
            final picked = await showDatePicker(
              context:     ctx,
              initialDate: (isFrom ? temp.dateFrom : temp.dateTo) ?? now,
              firstDate:   DateTime(2020),
              lastDate:    now,
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                    colorScheme: ColorScheme.light(primary: AppColors.primary)),
                child: child!,
              ),
            );
            if (picked != null) {
              setSheetState(() {
                temp = isFrom
                    ? temp.copyWith(dateFrom: picked)
                    : temp.copyWith(dateTo:   picked);
              });
            }
          }

          String fmtDate(DateTime? d) {
            if (d == null) return 'Any';
            return '${d.day.toString().padLeft(2,'0')}/'
                '${d.month.toString().padLeft(2,'0')}/${d.year}';
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('Filter & Sort',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setSheetState(() => temp = _OrderFilter()),
                    child: const Text('Reset all',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ]),
                const SizedBox(height: 20),

                _SheetSection(label: 'Sort by Date', children: [
                  Row(children: [
                    Expanded(child: _SortChip(
                      label: 'Newest first', icon: Icons.arrow_downward,
                      selected: temp.newestFirst,
                      onTap: () => setSheetState(
                          () => temp = temp.copyWith(newestFirst: true)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _SortChip(
                      label: 'Oldest first', icon: Icons.arrow_upward,
                      selected: !temp.newestFirst,
                      onTap: () => setSheetState(
                          () => temp = temp.copyWith(newestFirst: false)),
                    )),
                  ]),
                ]),
                const SizedBox(height: 20),

                _SheetSection(label: 'Order Status', children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in [
                      'Processing', 'Out for Delivery', 'Delivered', 'Cancelled'
                    ])
                      _FilterChip(
                        label:    s,
                        selected: temp.orderStatuses.contains(s),
                        color:    _orderStatusColor(s),
                        onTap:    () => toggleOrderStatus(s),
                      ),
                  ]),
                ]),
                const SizedBox(height: 20),

                _SheetSection(label: 'Payment Status', children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _FilterChip(label: 'Paid',      selected: temp.paymentStatuses.contains(_kPayCompleted), color: AppColors.success,              onTap: () => togglePayStatus(_kPayCompleted)),
                    _FilterChip(label: 'Pending',   selected: temp.paymentStatuses.contains(_kPayPending),   color: const Color(0xFFF59E0B),        onTap: () => togglePayStatus(_kPayPending)),
                    _FilterChip(label: 'Failed',    selected: temp.paymentStatuses.contains(_kPayFailed),    color: AppColors.error,                onTap: () => togglePayStatus(_kPayFailed)),
                    _FilterChip(label: 'Refunded',  selected: temp.paymentStatuses.contains(_kPayRefunded),  color: const Color(0xFF3B82F6),        onTap: () => togglePayStatus(_kPayRefunded)),
                    _FilterChip(label: 'Cancelled', selected: temp.paymentStatuses.contains(_kPayCancelled), color: AppColors.textSecondary,        onTap: () => togglePayStatus(_kPayCancelled)),
                  ]),
                ]),
                const SizedBox(height: 20),

                _SheetSection(label: 'Date Range', children: [
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => pickDate(true),
                      child: _DateBox(
                        label: 'From', value: fmtDate(temp.dateFrom),
                        hasValue: temp.dateFrom != null,
                        onClear: temp.dateFrom != null
                            ? () => setSheetState(
                                () => temp = temp.copyWith(clearDateFrom: true))
                            : null,
                      ),
                    )),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () => pickDate(false),
                      child: _DateBox(
                        label: 'To', value: fmtDate(temp.dateTo),
                        hasValue: temp.dateTo != null,
                        onClear: temp.dateTo != null
                            ? () => setSheetState(
                                () => temp = temp.copyWith(clearDateTo: true))
                            : null,
                      ),
                    )),
                  ]),
                ]),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _filter = temp);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      temp.activeFilterCount > 0
                          ? 'Apply (${temp.activeFilterCount} active)'
                          : 'Apply',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Color _orderStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'processing':       return AppColors.warning;
      case 'out for delivery': return AppColors.info;
      case 'delivered':        return AppColors.success;
      case 'cancelled':        return AppColors.error;
      default:                 return AppColors.textSecondary;
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // BOTH: filter flat list → then group
    final activeGroups    = _applyFilterAndGroup(
        _rawOrders.where(_isActive).toList());
    final completedGroups = _applyFilterAndGroup(
        _rawOrders.where(_isCompleted).toList());
    final allGroups       = _applyFilterAndGroup(_rawOrders);

    // Raw (unfiltered) counts for filter-empty-state detection
    final activeRaw    = _rawOrders.where(_isActive).length;
    final completedRaw = _rawOrders.where(_isCompleted).length;
    final allRaw       = _rawOrders.length;

    final filterCount = _filter.activeFilterCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          // CURRENT: filter badge
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon:      const Icon(Icons.tune),
              tooltip:   'Filter & Sort',
              onPressed: _showFilterSheet,
            ),
            if (filterCount > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Center(child: Text(
                    filterCount > 9 ? '9+' : '$filterCount',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold,
                        color: Colors.white),
                  )),
                ),
              ),
          ]),
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
              : Column(children: [
                  // CURRENT: active filters bar
                  if (_filter.hasActiveFilters)
                    _ActiveFiltersBar(
                      filter:    _filter,
                      onClear:   () => setState(() => _filter = _OrderFilter()),
                      onTapEdit: _showFilterSheet,
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTab(
                          groups:      activeGroups,
                          rawCount:    activeRaw,
                          emptyMsg:    'No active orders',
                          emptyIcon:   Icons.local_shipping_outlined,
                          showDispute: false,
                        ),
                        _buildTab(
                          groups:      completedGroups,
                          rawCount:    completedRaw,
                          emptyMsg:    'No completed orders',
                          emptyIcon:   Icons.check_circle_outline,
                          showDispute: true,
                        ),
                        _buildTab(
                          groups:      allGroups,
                          rawCount:    allRaw,
                          emptyMsg:    'No orders found',
                          emptyIcon:   Icons.receipt_long,
                          showDispute: true,
                        ),
                      ],
                    ),
                  ),
                ]),
    );
  }

  Widget _buildTab({
    required List<_OrderGroup> groups,
    required int               rawCount,
    required String            emptyMsg,
    required IconData          emptyIcon,
    required bool              showDispute,
  }) {
    final filtered = _filter.hasActiveFilters && groups.length < rawCount;

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: groups.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(child: Column(children: [
                  Icon(emptyIcon, size: 80, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    filtered ? 'No orders match your filters' : emptyMsg,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (filtered)
                    TextButton.icon(
                      onPressed: () => setState(() => _filter = _OrderFilter()),
                      icon:  const Icon(Icons.filter_alt_off),
                      label: const Text('Clear filters'),
                    )
                  else
                    const Text('Pull down to refresh',
                        style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                ])),
              ],
            )
          : ListView.builder(
              padding:    const EdgeInsets.all(16),
              itemCount:  groups.length,
              itemBuilder: (_, i) {
                final group       = groups[i];
                final o           = group.primaryOrder;
                final oid         = _orderId(o);
                final isDelivered = _isCompleted(o);
                final showDisputeBtn = showDispute && isDelivered;
                final payStatus   = _paymentStatus(oid);

                // INCOMING: multi-supplier label
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
                    // INCOMING: route to grouped tracking if multi-supplier
                    if (group.isMultiSupplier) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GroupedOrderTrackingScreen(
                          groupId: group.groupId,
                          orders:  group.orders,
                        ),
                      ));
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: o)));
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
//  ACTIVE FILTERS BAR  (CURRENT)
// ══════════════════════════════════════════════════════════
class _ActiveFiltersBar extends StatelessWidget {
  final _OrderFilter filter;
  final VoidCallback onClear, onTapEdit;
  const _ActiveFiltersBar({
    required this.filter, required this.onClear, required this.onTapEdit});

  static const _payLabels = {
    _kPayPending:   'Pending',
    _kPayCompleted: 'Paid',
    _kPayFailed:    'Failed',
    _kPayCancelled: 'Cancelled',
    _kPayRefunded:  'Refunded',
  };

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];
    if (!filter.newestFirst) chips.add('Oldest first');
    for (final s in filter.orderStatuses) chips.add(s);
    for (final p in filter.paymentStatuses) chips.add(_payLabels[p] ?? 'Pay:$p');
    if (filter.dateFrom != null || filter.dateTo != null) {
      final from = filter.dateFrom != null
          ? '${filter.dateFrom!.day}/${filter.dateFrom!.month}' : '';
      final to   = filter.dateTo   != null
          ? '${filter.dateTo!.day}/${filter.dateTo!.month}'     : '';
      chips.add(from.isNotEmpty && to.isNotEmpty ? '$from – $to'
          : from.isNotEmpty ? 'From $from' : 'To $to');
    }

    return Container(
      color: AppColors.primary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips.map((chip) => Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(chip,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          )).toList()),
        )),
        GestureDetector(
          onTap: onClear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.close, size: 12, color: AppColors.error),
              SizedBox(width: 3),
              Text('Clear',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.error)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SHEET HELPER WIDGETS  (CURRENT)
// ══════════════════════════════════════════════════════════
class _SheetSection extends StatelessWidget {
  final String label; final List<Widget> children;
  const _SheetSection({required this.label, required this.children});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold,
              color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...children,
        ]);
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : AppColors.textSecondary)),
        ),
      );
}

class _SortChip extends StatelessWidget {
  final String label; final IconData icon; final bool selected;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.icon,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppColors.primary : AppColors.textSecondary)),
          ]),
        ),
      );
}

class _DateBox extends StatelessWidget {
  final String label, value; final bool hasValue; final VoidCallback? onClear;
  const _DateBox({required this.label, required this.value,
      required this.hasValue, this.onClear});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasValue ? AppColors.primary.withOpacity(0.06) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasValue ? AppColors.primary : AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            Text(value, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: hasValue ? AppColors.primary : AppColors.textSecondary)),
          ])),
          if (onClear != null)
            GestureDetector(onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.textHint)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  PAYMENT STATUS BADGE
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
        Text(info.label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: info.color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER CARD  (BOTH: CURRENT layout + INCOMING isMultiSupplier badge)
// ══════════════════════════════════════════════════════════
class _OrderCard extends StatelessWidget {
  final String orderId, orderNumber, status, supplierName, date, time;
  final int    items;
  final double totalAmount;
  final bool   canCancel, showDispute, isMultiSupplier;
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
    this.isMultiSupplier = false,
  });

  Color    _statusColor() {
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
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // INCOMING: multi-supplier badge
              if (isMultiSupplier)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.storefront, size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(supplierName, style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                  ]),
                ),
              Text(orderNumber.isNotEmpty ? orderNumber : orderId,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (!isMultiSupplier)
                Row(children: [
                  const Icon(Icons.store, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(child: Text(supplierName,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.access_time, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Flexible(child: Text('$date • $time',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('£${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(height: 5),
              if (paymentStatus != null)
                _PaymentBadge(paymentStatus!)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 9, height: 9,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.textHint)),
                    SizedBox(width: 4),
                    Text('Payment', style: TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
                  ]),
                ),
            ]),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.shopping_basket,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text('$items items', style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            ]),
            Row(children: [
              if (canCancel)
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: const Text('Cancel', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.error)),
                  ),
                ),
              if (showDispute)
                GestureDetector(
                  onTap: onDispute,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.warning.withOpacity(0.6)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.gavel, size: 13, color: AppColors.warning),
                      const SizedBox(width: 4),
                      const Text('Dispute', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.warning)),
                    ]),
                  ),
                ),
              if (!isCancelled)
                Text(
                  isDelivered ? 'View Details' : 'Track Order',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDelivered ? AppColors.textSecondary : AppColors.primary,
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
  final String message; final VoidCallback onRetry;
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
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
}