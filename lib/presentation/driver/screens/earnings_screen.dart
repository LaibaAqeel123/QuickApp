import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

/// EarningsScreen — shows driver earnings from the real API.
///
/// [driverId] — pass from parent (DriverHomeScreen / ActiveDeliveryScreen).
/// If null, it is resolved from SharedPreferences on init.
class EarningsScreen extends StatefulWidget {
  final String? driverId;
  const EarningsScreen({super.key, this.driverId});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab / period ────────────────────────────────────────
  late final TabController _tabController;
  static const _periods  = ['day', 'week', 'month'];
  static const _tabLabels = ['TODAY', 'THIS WEEK', 'THIS MONTH'];
  int _selectedTab = 1; // default = THIS WEEK

  // ── State ────────────────────────────────────────────────
  bool    _isLoading   = true;
  String? _errorMsg;
  String? _driverId;

  // ── API data ─────────────────────────────────────────────
  double        _totalEarnings    = 0;
  int           _totalDeliveries  = 0;
  String        _periodLabel      = '';
  List<dynamic> _deliveries       = [];
  List<dynamic> _byDay            = [];

  // ── Expandable delivery rows ──────────────────────────────
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_selectedTab != _tabController.index) {
        setState(() {
          _selectedTab = _tabController.index;
          _expanded.clear();
        });
        _load();
      }
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();
    await _load();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD — GET /api/Earnings/drivers/{driverId}/summary?period=...
  // ══════════════════════════════════════════════════════
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    if (_driverId == null || _driverId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg  = 'Driver ID not found. Please log in again.';
      });
      return;
    }

    final period = _periods[_selectedTab];
    final result = await AuthService.instance.getEarningsSummary(
      driverId: _driverId!,
      period:   period,
    );

    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;
      setState(() {
        _isLoading       = false;
        _totalEarnings   = (data['totalEarnings']   as num?)?.toDouble() ?? 0;
        _totalDeliveries = (data['totalDeliveries'] as num?)?.toInt()    ?? 0;
        _periodLabel     = data['period']?.toString() ?? '';
        _deliveries      = (data['deliveries'] as List?) ?? [];
        _byDay           = (data['byDay']       as List?) ?? [];
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = result.message ?? 'Failed to load earnings.';
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════
  double get _avgPerDelivery =>
      _totalDeliveries > 0 ? _totalEarnings / _totalDeliveries : 0;

  String _fmtCurrency(num? v) =>
      '£${(v ?? 0).toStringAsFixed(2)}';

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
              ? _ErrorView(message: _errorMsg!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        // ── Total earnings hero ──────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(children: [
            const Text('Total Earnings',
                style: TextStyle(fontSize: 16, color: AppColors.white)),
            const SizedBox(height: 12),
            Text(
              _fmtCurrency(_totalEarnings),
              style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white),
            ),
            if (_periodLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_periodLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.white.withOpacity(0.8))),
            ],
          ]),
        ),

        // ── Summary cards ────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_shipping,
                  value: _totalDeliveries.toString(),
                  label: 'Deliveries',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  value: _fmtCurrency(_avgPerDelivery),
                  label: 'Avg / Delivery',
                  color: AppColors.success,
                ),
              ),
            ]),
            // ── Daily breakdown chips ────────────────────
            if (_byDay.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DailyBreakdown(byDay: _byDay),
            ],
          ]),
        ),

        // ── Deliveries list ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deliveries',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text('${_deliveries.length} total',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (_deliveries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Icon(Icons.inbox_outlined,
                  size: 60, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(
                'No deliveries in this period',
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
            ]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: _deliveries.length,
            itemBuilder: (_, i) {
              final d   = _deliveries[i] as Map<String, dynamic>;
              final id  = d['deliveryId']?.toString() ?? i.toString();
              final isExpanded = _expanded.contains(id);
              return _DeliveryEarningCard(
                delivery:   d,
                isExpanded: isExpanded,
                onToggle: () => setState(() =>
                    isExpanded ? _expanded.remove(id) : _expanded.add(id)),
                fmtCurrency: _fmtCurrency,
                fmtDate: _fmtDate,
              );
            },
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DAILY BREAKDOWN
// ══════════════════════════════════════════════════════════
class _DailyBreakdown extends StatelessWidget {
  final List<dynamic> byDay;
  const _DailyBreakdown({required this.byDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Breakdown',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...byDay.map((d) {
            final day  = d as Map<String, dynamic>;
            DateTime? dt;
            try { dt = DateTime.parse(day['date'].toString()).toLocal(); }
            catch (_) {}
            final dateStr = dt != null
                ? '${dt.day}/${dt.month}/${dt.year}'
                : day['date']?.toString() ?? '';
            final amount = (day['amount'] as num?)?.toDouble() ?? 0;
            final count  = (day['deliveryCount'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(dateStr,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary))),
                Text('$count deliveries',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textHint)),
                const SizedBox(width: 12),
                Text('£${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DELIVERY EARNING CARD (expandable)
// ══════════════════════════════════════════════════════════
class _DeliveryEarningCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final bool         isExpanded;
  final VoidCallback onToggle;
  final String Function(num?) fmtCurrency;
  final String Function(String?) fmtDate;

  const _DeliveryEarningCard({
    required this.delivery,
    required this.isExpanded,
    required this.onToggle,
    required this.fmtCurrency,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final orderNumber = delivery['orderNumber']?.toString() ?? 'Order';
    final dateStr     = fmtDate(delivery['deliveryDate']?.toString());
    final distKm      = (delivery['distanceKm']  as num?)?.toDouble() ?? 0;
    final totalAmt    = (delivery['totalAmount']  as num?)?.toDouble() ?? 0;
    final baseAmt     = (delivery['baseAmount']   as num?)?.toDouble();
    final distAmt     = (delivery['distanceAmount']as num?)?.toDouble();
    final timeAmt     = (delivery['timeAmount']   as num?)?.toDouble();
    final mins        = (delivery['actualDeliveryMinutes'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // ── Row header ─────────────────────────────────
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderNumber,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                    if (distKm > 0) ...[
                      const SizedBox(height: 2),
                      Text('${distKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint)),
                    ],
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtCurrency(totalAmt),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textHint, size: 20,
                ),
              ]),
            ]),
          ),
        ),
        // ── Expanded breakdown ─────────────────────────
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Earnings Breakdown',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              if (baseAmt != null)
                _BreakdownRow(label: 'Base pay', value: fmtCurrency(baseAmt)),
              if (distAmt != null)
                _BreakdownRow(
                    label: 'Distance (${distKm.toStringAsFixed(1)} km)',
                    value: fmtCurrency(distAmt)),
              if (timeAmt != null)
                _BreakdownRow(
                    label: mins != null ? 'Time ($mins min)' : 'Time bonus',
                    value: fmtCurrency(timeAmt)),
              const Divider(height: 16),
              _BreakdownRow(
                  label: 'Total',
                  value: fmtCurrency(totalAmt),
                  bold: true),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label, value;
  final bool   bold;
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold
                  ? AppColors.textPrimary
                  : AppColors.textSecondary))),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: bold ? AppColors.success : AppColors.textPrimary)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  STAT CARD
// ══════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   value, label;
  final Color    color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 12),
      Text(value,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary)),
    ]),
  );
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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 60, color: AppColors.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ]),
    ),
  );
}