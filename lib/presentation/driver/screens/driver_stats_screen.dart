import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

/// Screen 5 — Driver Stats
/// Calls GET /api/Drivers/{driverId}/stats
/// Shows acceptance rate, offers breakdown, deliveries, earnings, rating.
class DriverStatsScreen extends StatefulWidget {
  final String? driverId;
  const DriverStatsScreen({super.key, this.driverId});

  @override
  State<DriverStatsScreen> createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends State<DriverStatsScreen> {
  // ── State ──────────────────────────────────────────────
  bool    _isLoading = true;
  String? _errorMsg;
  String? _driverId;

  // ── API data ───────────────────────────────────────────
  String _fullName         = '';
  int    _totalOffers      = 0;
  int    _totalAccepted    = 0;
  int    _totalRejected    = 0;
  int    _totalExpired     = 0;
  double _acceptanceRate   = 0;
  int    _totalDeliveries  = 0;
  double _totalEarnings    = 0;
  double _rating           = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _driverId = widget.driverId ??
        await AuthService.instance.getSavedDriverId();
    await _load();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD — GET /api/Drivers/{driverId}/stats
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

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  DRIVER STATS — calling API');
    debugPrint('║  driverId: $_driverId');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.getDriverStats(_driverId!);

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  DRIVER STATS — response received');
    debugPrint('║  success : ${result.success}');
    debugPrint('║  message : ${result.message}');
    debugPrint('║  data    : ${result.data}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted) return;

    if (result.success && result.data != null) {
      final d = result.data!;
      setState(() {
        _isLoading       = false;
        _fullName        = d['fullName']?.toString()       ?? '';
        _totalOffers     = (d['totalOffers']     as num?)?.toInt()    ?? 0;
        _totalAccepted   = (d['totalAccepted']   as num?)?.toInt()    ?? 0;
        _totalRejected   = (d['totalRejected']   as num?)?.toInt()    ?? 0;
        _totalExpired    = (d['totalExpired']     as num?)?.toInt()    ?? 0;
        _acceptanceRate  = (d['acceptanceRate']  as num?)?.toDouble() ?? 0;
        _totalDeliveries = (d['totalDeliveries'] as num?)?.toInt()    ?? 0;
        _totalEarnings   = (d['totalEarnings']   as num?)?.toDouble() ?? 0;
        _rating          = (d['rating']          as num?)?.toDouble() ?? 0;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = result.message ?? 'Failed to load stats.';
      });
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
        title: const Text('My Stats'),
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
        // ── Acceptance rate hero ─────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(children: [
            if (_fullName.isNotEmpty) ...[
              Text(_fullName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white)),
              const SizedBox(height: 20),
            ],
            // Circular acceptance rate indicator
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 140, height: 140,
                child: CircularProgressIndicator(
                  value: _acceptanceRate / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.success),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${_acceptanceRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white),
                ),
                const Text('Acceptance',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.white)),
              ]),
            ]),

            // ── Rating stars ──────────────────────────────
            if (_rating > 0) ...[
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...List.generate(5, (i) => Icon(
                  i < _rating.floor()
                      ? Icons.star
                      : (i < _rating ? Icons.star_half : Icons.star_border),
                  size: 26, color: AppColors.warning,
                )),
                const SizedBox(width: 8),
                Text(
                  _rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white),
                ),
              ]),
            ],
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // ── Offers breakdown ──────────────────────────
            _SectionHeader(title: 'Offer Breakdown'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(
                icon: Icons.notifications_active,
                value: '$_totalOffers',
                label: 'Total Offers',
                color: AppColors.primary,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.check_circle_outline,
                value: '$_totalAccepted',
                label: 'Accepted',
                color: AppColors.success,
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(
                icon: Icons.cancel_outlined,
                value: '$_totalRejected',
                label: 'Rejected',
                color: AppColors.error,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.timer_off_outlined,
                value: '$_totalExpired',
                label: 'Expired',
                color: AppColors.warning,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Visual bar breakdown ──────────────────────
            if (_totalOffers > 0) ...[
              _OfferBreakdownBar(
                accepted: _totalAccepted,
                rejected: _totalRejected,
                expired:  _totalExpired,
                total:    _totalOffers,
              ),
              const SizedBox(height: 20),
            ],

            // ── Performance cards ─────────────────────────
            _SectionHeader(title: 'Performance'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(
                icon: Icons.local_shipping,
                value: '$_totalDeliveries',
                label: 'Deliveries',
                color: AppColors.info,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.account_balance_wallet,
                value: '£${_totalEarnings.toStringAsFixed(2)}',
                label: 'Total Earned',
                color: AppColors.success,
              )),
            ]),
            const SizedBox(height: 20),

            // ── Acceptance rate progress bar ──────────────
            _AcceptanceRateCard(rate: _acceptanceRate),
            const SizedBox(height: 32),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  OFFER BREAKDOWN VISUAL BAR
// ══════════════════════════════════════════════════════════
class _OfferBreakdownBar extends StatelessWidget {
  final int accepted, rejected, expired, total;
  const _OfferBreakdownBar({
    required this.accepted,
    required this.rejected,
    required this.expired,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final aFrac = total > 0 ? accepted / total : 0.0;
    final rFrac = total > 0 ? rejected / total : 0.0;
    final eFrac = total > 0 ? expired  / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Offer Distribution',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            if (aFrac > 0)
              Expanded(
                flex: (aFrac * 100).round(),
                child: Container(height: 18, color: AppColors.success),
              ),
            if (rFrac > 0)
              Expanded(
                flex: (rFrac * 100).round(),
                child: Container(height: 18, color: AppColors.error),
              ),
            if (eFrac > 0)
              Expanded(
                flex: (eFrac * 100).round(),
                child: Container(height: 18, color: AppColors.warning),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _LegendDot(color: AppColors.success,
              label: 'Accepted ${(aFrac * 100).toStringAsFixed(0)}%'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.error,
              label: 'Rejected ${(rFrac * 100).toStringAsFixed(0)}%'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.warning,
              label: 'Expired ${(eFrac * 100).toStringAsFixed(0)}%'),
        ]),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.textSecondary)),
    ],
  );
}

// ══════════════════════════════════════════════════════════
//  ACCEPTANCE RATE CARD
// ══════════════════════════════════════════════════════════
class _AcceptanceRateCard extends StatelessWidget {
  final double rate;
  const _AcceptanceRateCard({required this.rate});

  String get _label {
    if (rate >= 90) return 'Excellent 🌟';
    if (rate >= 75) return 'Good 👍';
    if (rate >= 60) return 'Average 😐';
    return 'Needs Improvement ⚠️';
  }

  Color get _color {
    if (rate >= 90) return AppColors.success;
    if (rate >= 75) return AppColors.info;
    if (rate >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Acceptance Rate',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _color)),
        ),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: rate / 100,
          minHeight: 12,
          backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation<Color>(_color),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('0%', style: TextStyle(
            fontSize: 11, color: AppColors.textHint)),
        Text('${rate.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _color)),
        const Text('100%', style: TextStyle(
            fontSize: 11, color: AppColors.textHint)),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  SECTION HEADER
// ══════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary)),
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
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
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
        const Icon(Icons.bar_chart, size: 60, color: AppColors.textHint),
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