import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

class PayoutHistoryScreen extends StatefulWidget {
  final String driverId;
  const PayoutHistoryScreen({super.key, required this.driverId});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  bool _isLoading = true;
  String? _errorMsg;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMsg = null; });

    final result = await AuthService.instance.getDriverPayouts(
        driverId: widget.driverId);

    if (!mounted) return;

    if (result.success && result.data != null) {
      setState(() {
        _payouts   = result.data!.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = result.message ?? 'Failed to load payouts.';
      });
    }
  }

  // ── Status helpers ──────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return const Color(0xFFF59E0B); // yellow
      case 'approved':   return const Color(0xFF3B82F6); // blue
      case 'processing': return const Color(0xFFF97316); // orange
      case 'completed':  return AppColors.success;       // green
      case 'failed':     return AppColors.error;         // red
      default:           return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return Icons.hourglass_empty;
      case 'approved':   return Icons.thumb_up_outlined;
      case 'processing': return Icons.sync;
      case 'completed':  return Icons.check_circle_outline;
      case 'failed':     return Icons.cancel_outlined;
      default:           return Icons.info_outline;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const m = ['', 'Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month]} ${d.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Payout History'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color:     AppColors.primary,
        child:     _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // ── Loading skeleton ──────────────────────────────
    if (_isLoading) {
      return ListView.builder(
        padding:     const EdgeInsets.all(16),
        itemCount:   5,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }

    // ── Error ─────────────────────────────────────────
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    // ── Empty state ───────────────────────────────────
    if (_payouts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 56, color: AppColors.textHint),
              ),
              const SizedBox(height: 20),
              const Text('No payouts yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text(
                  'Your completed payout periods\nwill appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textHint)),
            ]),
          ),
        ],
      );
    }

    // ── Payout list ───────────────────────────────────
    return ListView.builder(
      physics:     const AlwaysScrollableScrollPhysics(),
      padding:     const EdgeInsets.all(16),
      itemCount:   _payouts.length,
      itemBuilder: (_, i) => _PayoutCard(
        payout:      _payouts[i],
        statusColor: _statusColor,
        statusIcon:  _statusIcon,
        fmtDate:     _fmtDate,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PAYOUT CARD
// ══════════════════════════════════════════════════════════
class _PayoutCard extends StatelessWidget {
  final Map<String, dynamic>                    payout;
  final Color Function(String)                  statusColor;
  final IconData Function(String)               statusIcon;
  final String Function(String?)                fmtDate;

  const _PayoutCard({
    required this.payout,
    required this.statusColor,
    required this.statusIcon,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final status     = (payout['payoutStatus'] ?? 'Pending').toString();
    final netAmount  = (payout['netAmount']    ?? payout['totalAmount'] ?? 0) as num;
    final currency   = payout['currency']?.toString() ?? 'GBP';
    final symbol     = currency == 'GBP' ? '£' : '\$';
    final periodStart = fmtDate(payout['periodStart']?.toString());
    final periodEnd   = fmtDate(payout['periodEnd']?.toString());
    final color       = statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          // Status icon circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              shape:        BoxShape.circle,
            ),
            child: Icon(statusIcon(status), color: color, size: 24),
          ),
          const SizedBox(width: 14),

          // Period dates
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('$periodStart — $periodEnd',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ]),
          ),

          // Amount
          Text('$symbol${netAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LOADING SKELETON CARD
// ══════════════════════════════════════════════════════════
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Circle
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color:  AppColors.surfaceLight,
            shape:  BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _Bone(width: 160, height: 14),
            const SizedBox(height: 8),
            _Bone(width: 80,  height: 10),
          ]),
        ),
        _Bone(width: 60, height: 18),
      ]),
    );
  }
}

class _Bone extends StatelessWidget {
  final double width, height;
  const _Bone({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color:        AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}