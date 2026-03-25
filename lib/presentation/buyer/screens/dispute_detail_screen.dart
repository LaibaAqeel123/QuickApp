import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

class DisputeDetailScreen extends StatefulWidget {
  final String disputeId;
  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  Map<String, dynamic>? _dispute;
  bool    _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    final result = await AuthService.instance.getDisputeById(widget.disputeId);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() { _dispute = result.data; _isLoading = false; });
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg  = result.message ?? 'Failed to load dispute details.';
      });
    }
  }

  // ── Status helpers ──────────────────────────────────
  static const _statusMap = {
    1: ('Open',         Color(0xFFF59E0B)),
    2: ('Under Review', Color(0xFF3B82F6)),
    3: ('Resolved',     AppColors.success),
    4: ('Rejected',     AppColors.error),
  };

  (String, Color) _status(dynamic raw) {
    if (raw is int) return _statusMap[raw] ?? ('Unknown', AppColors.textSecondary);
    if (raw is String) {
      switch (raw.toLowerCase().replaceAll(RegExp(r'[\s_]'), '')) {
        case 'open':        return _statusMap[1]!;
        case 'underreview':
        case 'reviewing':   return _statusMap[2]!;
        case 'resolved':    return _statusMap[3]!;
        case 'rejected':    return _statusMap[4]!;
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
      const m = ['','Jan','Feb','Mar','Apr','May','Jun',
                     'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final min = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${m[d.month]} ${d.year} • $h:$min ${d.hour >= 12 ? "PM" : "AM"}';
    } catch (_) { return iso.substring(0, 10); }
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Dispute Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
    }

    final d = _dispute!;
    final (statusLabel, statusColor) =
        _status(d['status'] ?? d['disputeStatus']);
    final typeName = _typeName(d['disputeType'] ?? d['type']);
    final reason   = (d['reason'] ?? '').toString();
    final orderNum = (d['orderNumber'] ?? d['orderId'] ?? '').toString();
    final created  = _fmtDate((d['createdAt'] ?? d['createdDate'])?.toString());
    final resolved = _fmtDate(d['resolvedAt']?.toString());
    final resolutionNotes = (d['resolutionNotes'] ?? d['notes'] ?? '').toString();
    final images   = _extractImages(d);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Status card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color:  statusColor.withOpacity(0.15),
                  shape:  BoxShape.circle),
              child: Icon(Icons.gavel, color: statusColor, size: 30),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color:        statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor)),
            ),
            const SizedBox(height: 8),
            Text(typeName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            if (created.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Raised: $created',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Order ref
        if (orderNum.isNotEmpty)
          _DetailCard(
            title: 'Order Reference',
            child: _DRow(
                icon:  Icons.receipt_long,
                label: 'Order',
                value: orderNum),
          ),
        const SizedBox(height: 12),

        // Reason
        _DetailCard(
          title: 'Reason',
          child: Text(
            reason.isNotEmpty ? reason : 'No reason provided.',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),

        // Evidence images
        if (images.isNotEmpty) ...[
          _DetailCard(
            title: 'Evidence Photos',
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount:  images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _showImage(images[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[i],
                      width: 110, height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 110, height: 110,
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.broken_image,
                            color: AppColors.textHint),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Resolution notes (only when resolved/rejected)
        if (resolutionNotes.isNotEmpty) ...[
          _DetailCard(
            title: 'Resolution Notes',
            titleColor: statusColor,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(resolutionNotes,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5)),
              if (resolved.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Resolved on: $resolved',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 16),
      ]),
    );
  }

  List<String> _extractImages(Map<String, dynamic> d) {
    final raw = d['evidenceImages'] ?? d['images'] ?? d['attachments'];
    if (raw is List) {
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map) return (e['url'] ?? e['path'] ?? '').toString();
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared small widgets ────────────────────────────────
class _DetailCard extends StatelessWidget {
  final String  title;
  final Widget  child;
  final Color?  titleColor;
  const _DetailCard({
    required this.title,
    required this.child,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: AppColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: titleColor ?? AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _DRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis)),
      ]);
}