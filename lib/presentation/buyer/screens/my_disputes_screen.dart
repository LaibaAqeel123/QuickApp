import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/dispute_detail_screen.dart';

class MyDisputesScreen extends StatefulWidget {
  const MyDisputesScreen({super.key});

  @override
  State<MyDisputesScreen> createState() => _MyDisputesScreenState();
}

class _MyDisputesScreenState extends State<MyDisputesScreen> {
  final List<Map<String, dynamic>> _disputes = [];
  final ScrollController _scroll = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMsg;
  int _page = 1;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMsg  = null;
        _page      = 1;
        _hasMore   = true;
        _disputes.clear();
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final result = await AuthService.instance.getMyDisputes(
        page: _page, pageSize: _pageSize);

    if (!mounted) return;

    if (result.success && result.data != null) {
      final items = _extractList(result.data!);
      setState(() {
        _disputes.addAll(items);
        _hasMore    = items.length == _pageSize;
        _page++;
        _isLoading      = false;
        _isLoadingMore  = false;
      });
    } else {
      setState(() {
        _isLoading     = false;
        _isLoadingMore = false;
        _errorMsg      = result.message ?? 'Failed to load disputes.';
      });
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> data) {
    for (final key in ['items', 'disputes', 'data', 'results']) {
      if (data[key] is List) {
        return (data[key] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
    return [];
  }

  // ── Status helpers ──────────────────────────────────
  static const _statusMap = {
    1: ('Open',         Color(0xFFF59E0B)),
    2: ('Under Review', Color(0xFF3B82F6)),
    3: ('Resolved',     AppColors.success),
    4: ('Rejected',     AppColors.error),
  };

  (String, Color) _status(dynamic raw) {
    if (raw is int) {
      return _statusMap[raw] ?? ('Unknown', AppColors.textSecondary);
    }
    if (raw is String) {
      switch (raw.toLowerCase()) {
        case 'open':         return _statusMap[1]!;
        case 'underreview':
        case 'under_review':
        case 'reviewing':    return _statusMap[2]!;
        case 'resolved':     return _statusMap[3]!;
        case 'rejected':     return _statusMap[4]!;
      }
    }
    return ('Open', const Color(0xFFF59E0B));
  }

  static const _typeNames = {
    1: 'Payment Issue',
    2: 'Delivery Issue',
    3: 'Product Issue',
    4: 'Other',
  };

  String _typeName(dynamic raw) {
    if (raw is int) return _typeNames[raw] ?? 'Dispute';
    return raw?.toString() ?? 'Dispute';
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('My Disputes'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          IconButton(
              icon:      const Icon(Icons.refresh),
              onPressed: () => _load(reset: true)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color:     AppColors.primary,
        child:     _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding:     const EdgeInsets.all(16),
        itemCount:   5,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }

    if (_errorMsg != null && _disputes.isEmpty) {
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
                onPressed: () => _load(reset: true),
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
    }

    if (_disputes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Column(children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                  color: AppColors.surfaceLight, shape: BoxShape.circle),
              child: const Icon(Icons.gavel_outlined,
                  size: 56, color: AppColors.textHint),
            ),
            const SizedBox(height: 20),
            const Text('No disputes yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Disputes you raise will appear here.',
                style: TextStyle(fontSize: 14, color: AppColors.textHint)),
          ]),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics:    const AlwaysScrollableScrollPhysics(),
      padding:    const EdgeInsets.all(16),
      itemCount:  _disputes.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _disputes.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final d = _disputes[i];
        final disputeId = (d['disputeId'] ?? d['id'] ?? '').toString();
        final orderNum  = (d['orderNumber'] ?? d['orderId'] ?? '').toString();
        final (statusLabel, statusColor) = _status(d['status'] ?? d['disputeStatus']);
        final typeName  = _typeName(d['disputeType'] ?? d['type']);
        final date      = _fmtDate((d['createdAt'] ?? d['createdDate'])?.toString());

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DisputeDetailScreen(disputeId: disputeId)),
          ),
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
                    offset:     const Offset(0, 2)),
              ],
            ),
            child: Row(children: [
              // Left icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color:  statusColor.withOpacity(0.12),
                    shape:  BoxShape.circle),
                child: Icon(Icons.gavel,
                    color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(typeName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                if (orderNum.isNotEmpty)
                  Text('Order: $orderNum',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ])),

              // Status badge + arrow
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor)),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.arrow_forward_ios,
                    size: 13, color: AppColors.textHint),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ── Skeleton ────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.surfaceLight, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _Bone(width: 140, height: 14),
            const SizedBox(height: 8),
            _Bone(width: 100, height: 11),
          ])),
          _Bone(width: 70, height: 22),
        ]),
      );
}

class _Bone extends StatelessWidget {
  final double width, height;
  const _Bone({required this.width, required this.height});
  @override
  Widget build(BuildContext context) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6)));
}