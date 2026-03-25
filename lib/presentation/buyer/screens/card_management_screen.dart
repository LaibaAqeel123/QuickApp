import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

class CardManagementScreen extends StatefulWidget {
  const CardManagementScreen({super.key});

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  List<Map<String, dynamic>> _cards      = [];
  bool                       _isLoading  = true;
  String?                    _busyCardId;
  String?                    _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await AuthService.instance.getSavedCards();
    if (!mounted) return;
    debugPrint('💳 [CardMgmt] getSavedCards success=${result.success} count=${result.data?.length} msg=${result.message}');
    if (result.success) {
      setState(() {
        _cards     = (result.data ?? []).whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _error     = result.message ?? 'Failed to load cards.';
        _isLoading = false;
      });
    }
  }

  Future<void> _setDefault(String cardId) async {
    setState(() => _busyCardId = cardId);
    final result = await AuthService.instance.setDefaultCard(cardId);
    if (!mounted) return;
    setState(() => _busyCardId = null);
    debugPrint('💳 [CardMgmt] setDefault success=${result.success} msg=${result.message}');
    if (result.success) {
      _snack('Default card updated.');
      await _loadCards();
    } else {
      _snack(result.message ?? 'Failed to update default card.', isError: true);
    }
  }

  Future<void> _deleteCard(String cardId, String last4) async {
    final confirm = await _confirmDelete(last4);
    if (!confirm || !mounted) return;
    setState(() => _busyCardId = cardId);
    final result = await AuthService.instance.deleteCard(cardId);
    if (!mounted) return;
    setState(() => _busyCardId = null);
    debugPrint('💳 [CardMgmt] deleteCard success=${result.success} msg=${result.message}');
    if (result.success) {
      _snack('Card removed.');
      await _loadCards();
    } else {
      _snack(result.message ?? 'Failed to remove card.', isError: true);
    }
  }

  Future<bool> _confirmDelete(String last4) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Card'),
        content: Text('Remove card ending in $last4?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Remove')),
        ],
      ),
    );
    return r ?? false;
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ));

  Color _brandColor(String? brand) {
    switch ((brand ?? '').toLowerCase()) {
      case 'visa':       return const Color(0xFF1A1F71);
      case 'mastercard': return const Color(0xFFEB001B);
      case 'amex':       return const Color(0xFF016FD0);
      case 'discover':   return const Color(0xFFFF6600);
      default:           return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadCards),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _cards.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadCards,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(children: [
                              const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text('${_cards.length} saved card${_cards.length == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            ]),
                          ),
                          ..._cards.map((card) {
                            final cardId   = (card['id'] ?? card['cardId'])?.toString() ?? '';
                            final last4    = card['last4']?.toString() ?? '••••';
                            final brand    = card['brand']?.toString() ?? 'Card';
                            final expMonth = card['expMonth']?.toString() ?? '';
                            final expYear  = card['expYear']?.toString() ?? '';
                            final isDef    = card['isDefault'] == true;
                            final isBusy   = _busyCardId == cardId;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDef ? AppColors.success : AppColors.border, width: isDef ? 2 : 1),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Container(width: 48, height: 48,
                                          decoration: BoxDecoration(color: _brandColor(brand).withOpacity(0.1), shape: BoxShape.circle),
                                          child: Icon(Icons.credit_card, color: _brandColor(brand), size: 26)),
                                      const SizedBox(width: 14),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Flexible(child: Text(
                                              '${brand[0].toUpperCase()}${brand.substring(1)} •••• $last4',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                                          if (isDef) ...[const SizedBox(width: 8),
                                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('Default', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)))],
                                        ]),
                                        const SizedBox(height: 3),
                                        Text((expMonth.isNotEmpty && expYear.isNotEmpty) ? 'Expires $expMonth/$expYear' : 'Saved card',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ])),
                                      if (isBusy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ]),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      if (!isDef)
                                        Expanded(child: OutlinedButton.icon(
                                          onPressed: isBusy ? null : () => _setDefault(cardId),
                                          icon:  const Icon(Icons.star_outline, size: 16),
                                          label: const Text('Set Default'),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              side: const BorderSide(color: AppColors.primary),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ))
                                      else
                                        Expanded(child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          alignment: Alignment.center,
                                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                            Icon(Icons.star, size: 16, color: AppColors.success),
                                            SizedBox(width: 4),
                                            Text('Default card', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                                          ]),
                                        )),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: isBusy ? null : () => _deleteCard(cardId, last4),
                                        icon:  const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Remove'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                  ]),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                            child: const Row(children: [
                              Icon(Icons.info_outline, color: AppColors.primary, size: 20), SizedBox(width: 12),
                              Expanded(child: Text(
                                'New cards are saved during checkout.\nToggle "Save card" when making a payment.',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
                            ]),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 56),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: _loadCards, icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ]),
  ));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
          child: const Icon(Icons.credit_card_off_outlined, size: 56, color: AppColors.textSecondary)),
      const SizedBox(height: 24),
      const Text('No Payment Methods', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      const Text('Your saved cards will appear here.\nCards are saved during checkout.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        onPressed: _showHowToAdd,
        icon: const Icon(Icons.info_outline), label: const Text('How to Add a Card'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
      ),
    ]),
  ));

  void _showHowToAdd() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Icon(Icons.add_card, color: AppColors.primary, size: 48),
        const SizedBox(height: 16),
        const Text('How to add a card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        const Text('Cards are saved during checkout. When placing an order, toggle "Save card for future payments" before paying.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(context), child: const Text('Got it'))),
        const SizedBox(height: 8),
      ]),
    ),
  );
}