import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_bottom_sheet.dart';
import 'package:food_delivery_app/presentation/buyer/screens/payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final Map<String, dynamic>? cartMeta;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.cartMeta,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ── Address ────────────────────────────────────────────
  List<Map<String, dynamic>> _addresses          = [];
  Map<String, dynamic>?      _selectedAddress;
  bool                       _isLoadingAddresses = true;

  // ── Form fields that map directly to API params ────────
  // POST /api/orders/checkout accepts:
  //   deliveryAddressId, billingAddressId,
  //   specialInstructions, discountCode
  final _instructionsCtrl = TextEditingController();
  final _discountCtrl     = TextEditingController();
  bool  _isDiscountApplied = false;

  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  // ── Load addresses ─────────────────────────────────────
  Future<void> _loadAddresses() async {
    setState(() => _isLoadingAddresses = true);
    final result = await AuthService.instance.getAddresses();
    if (!mounted) return;
    if (result.success) {
      final list =
          (result.data ?? []).whereType<Map<String, dynamic>>().toList();
      setState(() {
        _addresses       = list;
        _selectedAddress = list.isEmpty
            ? null
            : list.firstWhere(
                (a) => a['isDefault'] == true,
                orElse: () => list.first,
              );
        _isLoadingAddresses = false;
      });
    } else {
      setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _changeAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => const AddressScreen(selectionMode: true)),
    );
    if (picked != null) setState(() => _selectedAddress = picked);
  }

  Future<void> _addNewAddress() async {
    final saved = await AddressBottomSheet.show(context);
    if (saved != null && mounted) {
      await _loadAddresses();
      if (saved['id'] != null || saved['addressId'] != null) {
        setState(() => _selectedAddress = saved);
      }
    }
  }

  String? get _deliveryAddressId =>
      (_selectedAddress?['id'] ?? _selectedAddress?['addressId'])
          ?.toString();

  String _formatAddress(Map<String, dynamic> a) => [
        if ((a['streetAddress'] ?? '').toString().isNotEmpty)
          a['streetAddress'],
        if ((a['apartment'] ?? '').toString().isNotEmpty) a['apartment'],
        if ((a['city'] ?? '').toString().isNotEmpty) a['city'],
        if ((a['postalCode'] ?? '').toString().isNotEmpty) a['postalCode'],
      ].join(', ');

  String _addressLabel(Map<String, dynamic> a) {
    final lbl = a['label']?.toString() ?? '';
    if (lbl.isNotEmpty) return lbl;
    final type = (a['addressType'] as num?)?.toInt() ?? 0;
    return ['Home', 'Work', 'Other'][type.clamp(0, 2)];
  }

  IconData _addressIcon(Map<String, dynamic> a) {
    switch ((a['addressType'] as num?)?.toInt() ?? 0) {
      case 1:  return Icons.work_outline;
      case 2:  return Icons.location_on_outlined;
      default: return Icons.home_outlined;
    }
  }

  // ── Deep order-id extractor ────────────────────────────
  String? _extractOrderId(Map<String, dynamic>? data) {
    if (data == null) return null;
    const keys = [
      'orderId', 'OrderId', 'id', 'Id',
      'orderNumber', 'OrderNumber', 'order_id'
    ];

    for (final k in keys) {
      final v = data[k];
      if (v != null && v.toString().isNotEmpty && v.toString() != 'null') {
        debugPrint('✅ [orderId] top "$k": $v');
        return v.toString();
      }
    }
    final order = data['order'];
    if (order is Map<String, dynamic>) {
      for (final k in keys) {
        final v = order[k];
        if (v != null && v.toString().isNotEmpty) {
          debugPrint('✅ [orderId] order.$k: $v');
          return v.toString();
        }
      }
    }
    final arr = data['orders'];
    if (arr is List &&
        arr.isNotEmpty &&
        arr.first is Map<String, dynamic>) {
      final first = arr.first as Map<String, dynamic>;
      for (final k in keys) {
        final v = first[k];
        if (v != null && v.toString().isNotEmpty) {
          debugPrint('✅ [orderId] orders[0].$k: $v');
          return v.toString();
        }
      }
    }
    // Deep recursive
    String? deep(dynamic node, int depth) {
      if (depth > 5) return null;
      if (node is Map<String, dynamic>) {
        for (final k in keys) {
          final v = node[k];
          if (v != null &&
              v.toString().isNotEmpty &&
              v.toString() != 'null') return v.toString();
        }
        for (final e in node.entries) {
          final f = deep(e.value, depth + 1);
          if (f != null) return f;
        }
      } else if (node is List) {
        for (final i in node) {
          final f = deep(i, depth + 1);
          if (f != null) return f;
        }
      }
      return null;
    }

    final d = deep(data, 0);
    if (d != null) return d;
    debugPrint('[orderId] NOT FOUND. Keys: ${data.keys.toList()}');
    return null;
  }

  // ══════════════════════════════════════════════════════
  //  PLACE ORDER
  //  Sends only what the API accepts:
  //    deliveryAddressId, billingAddressId,
  //    specialInstructions, discountCode
  //
  //  Cart is NOT cleared here — only cleared in
  //  PaymentSuccessScreen after payment succeeds.
  // ══════════════════════════════════════════════════════
  Future<void> _placeOrder() async {
    if (_deliveryAddressId == null || _deliveryAddressId!.isEmpty) {
      _snack('Please select a delivery address to continue.',
          isError: true);
      return;
    }

    // Count unique suppliers in cart
    final supplierIds = widget.cartItems
        .map((i) => (i['supplierId'] ?? i['supplier']?['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (supplierIds.length > 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Multiple Suppliers'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'You are ordering from ${supplierIds.length} suppliers.',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Each supplier will handle their own delivery separately. You will be charged a delivery fee per supplier.',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ]),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    // Go directly to payment screen — order placed AFTER payment
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId:             '', // empty — order not placed yet
          orderTotal:          widget.total,
          orderData:           null,
          deliveryAddressId:   _deliveryAddressId!,
          specialInstructions: _instructionsCtrl.text.trim(),
          discountCode: _discountCtrl.text.trim().isEmpty
              ? null
              : _discountCtrl.text.trim(),
        ),
      ),
    );
  }
  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 4),
      ));

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Checkout'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── 1. Delivery Address ───────────────────
              _Section(
                title: 'Delivery Address',
                icon:  Icons.location_on,
                child: _isLoadingAddresses
                    ? const _Loading(label: 'Loading addresses...')
                    : _selectedAddress != null
                        ? _AddressTile(
                            label:     _addressLabel(_selectedAddress!),
                            address:   _formatAddress(_selectedAddress!),
                            icon:      _addressIcon(_selectedAddress!),
                            isDefault:
                                _selectedAddress!['isDefault'] == true,
                            onChange: _changeAddress,
                          )
                        : _NoAddress(
                            hasAddresses: _addresses.isNotEmpty,
                            onSelect:     _changeAddress,
                            onAdd:        _addNewAddress,
                          ),
              ),
              const SizedBox(height: 16),

              // ── 2. Special Instructions ───────────────
              _Section(
                title: 'Special Instructions',
                icon:  Icons.note_alt_outlined,
                child: TextField(
                  controller:  _instructionsCtrl,
                  maxLines:    3,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDeco(
                      'Any special delivery instructions (optional)...'),
                ),
              ),
              const SizedBox(height: 16),

              // ── 3. Discount Code ──────────────────────
              _Section(
                title: 'Discount Code',
                icon:  Icons.local_offer_outlined,
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller:  _discountCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDeco('Enter promo code').copyWith(
                        suffixIcon: _isDiscountApplied
                            ? const Icon(Icons.check_circle,
                                color: AppColors.success)
                            : null,
                      ),
                      onChanged: (_) {
                        if (_isDiscountApplied) {
                          setState(() => _isDiscountApplied = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final code = _discountCtrl.text.trim();
                      if (code.isEmpty) {
                        _snack('Please enter a discount code.',
                            isError: true);
                        return;
                      }
                      // The code is validated server-side at checkout.
                      // We just give visual confirmation here.
                      setState(() => _isDiscountApplied = true);
                      _snack('Code "$code" will be applied at checkout.');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Apply'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── 4. Order Summary ──────────────────────
              _Section(
                title: 'Order Summary',
                icon:  Icons.receipt,
                child: Column(children: [

                  // Item list (max 3 shown, then "+ N more")
                  ...widget.cartItems.take(3).map((item) {
                    final name  = (item['productName'] ??
                            item['product']?['name'] ??
                            'Product')
                        .toString();
                    final qty   = ((item['quantity'] ?? 0) as num).toInt();
                    final price = ((item['unitPrice'] ??
                                item['price'] ??
                                item['product']?['price'] ??
                                0) as num)
                        .toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$name × $qty',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '£${(price * qty).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.textPrimary),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (widget.cartItems.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '+ ${widget.cartItems.length - 3} more items',
                        style: const TextStyle(
                            fontSize: 13,
                            color:    AppColors.textSecondary),
                      ),
                    ),

                  const Divider(height: 24),

                  // Price breakdown
                  _SummRow('Subtotal',
                      '£${widget.subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _SummRow('Delivery Fee',
                      '£${widget.deliveryFee.toStringAsFixed(2)}'),

                  if (_isDiscountApplied &&
                      _discountCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.local_offer,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Code: ${_discountCtrl.text.trim()}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.success),
                          ),
                        ]),
                        const Text('Applied ✓',
                            style: TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.success)),
                      ],
                    ),
                  ],

                  const Divider(height: 24),
                  _SummRow(
                    'Total',
                    '£${widget.total.toStringAsFixed(2)}',
                    bold: true,
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Proceed to Payment button ─────────────
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isPlacingOrder
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Processing...',
                                style: TextStyle(
                                    fontSize:   16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Proceed to Payment  •  '
                              '£${widget.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize:   16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_user_outlined,
                      size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Secured by Stripe',
                      style: TextStyle(
                          fontSize: 12,
                          color:    AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled:     true,
        fillColor:  AppColors.background,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5)),
      );
}

// ══════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Widget   child;
  const _Section(
      {required this.title,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: AppColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                    color:      AppColors.textPrimary)),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class _AddressTile extends StatelessWidget {
  final String   label, address;
  final IconData icon;
  final bool     isDefault;
  final VoidCallback onChange;
  const _AddressTile({
    required this.label,
    required this.address,
    required this.icon,
    required this.isDefault,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(label,
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary)),
              if (isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('Default',
                      style: TextStyle(
                          fontSize:   10,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.success)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(address,
                style: const TextStyle(
                    fontSize: 13,
                    color:    AppColors.textSecondary)),
          ]),
        ),
        TextButton(
            onPressed: onChange, child: const Text('Change')),
      ]);
}

class _NoAddress extends StatelessWidget {
  final bool         hasAddresses;
  final VoidCallback onSelect, onAdd;
  const _NoAddress({
    required this.hasAddresses,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.warning.withOpacity(0.3))),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('No delivery address selected.',
                  style: TextStyle(
                      fontSize: 13,
                      color:    AppColors.textPrimary)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (hasAddresses)
          OutlinedButton.icon(
              onPressed: onSelect,
              icon:  const Icon(Icons.location_on),
              label: const Text('Select Address'))
        else
          ElevatedButton.icon(
              onPressed: onAdd,
              icon:  const Icon(Icons.add_location_alt),
              label: const Text('Add New Address')),
      ]);
}

class _Loading extends StatelessWidget {
  final String label;
  const _Loading({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                color:    AppColors.textSecondary)),
      ]);
}

class _SummRow extends StatelessWidget {
  final String title, value;
  final bool   bold;
  const _SummRow(this.title, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: TextStyle(
                fontSize:   bold ? 16 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color:      AppColors.textPrimary)),
        Text(value,
            style: TextStyle(
                fontSize:   bold ? 18 : 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: bold
                    ? AppColors.primary
                    : AppColors.textPrimary)),
      ]);
}