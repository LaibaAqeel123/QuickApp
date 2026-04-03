import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_bottom_sheet.dart';
import 'package:food_delivery_app/presentation/buyer/screens/map_location_picker_screen.dart';
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
  List<Map<String, dynamic>> _addresses          = [];
  Map<String, dynamic>?      _selectedAddress;
  bool                       _isLoadingAddresses = true;
  bool                       _isMapPickedAddress = false;

  // Change 1 — new state variables
  List<Map<String, dynamic>> _supplierFees      = [];
  double                     _actualDeliveryFee = 0.0;
  bool                       _isCalculatingFee  = false;

  final _instructionsCtrl  = TextEditingController();
  final _discountCtrl      = TextEditingController();
  bool  _isDiscountApplied = false;
  bool  _isPlacingOrder    = false;

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

  Future<void> _loadAddresses() async {
    setState(() => _isLoadingAddresses = true);
    final result = await AuthService.instance.getAddresses();
    if (!mounted) return;
    if (result.success) {
      final list =
      (result.data ?? []).whereType<Map<String, dynamic>>().toList();
      // Change 4 — calculate fee after setting address
      setState(() {
        _addresses          = list;
        _selectedAddress    = list.isEmpty
            ? null
            : list.firstWhere(
              (a) => a['isDefault'] == true,
          orElse: () => list.first,
        );
        _isMapPickedAddress = false;
        _isLoadingAddresses = false;
      });
      await _calculateFee();
    } else {
      setState(() => _isLoadingAddresses = false);
    }
  }

  // Change 2 — new _calculateFee method
  Future<void> _calculateFee() async {
    if (_deliveryAddressId == null || _deliveryAddressId!.isEmpty) return;

    setState(() => _isCalculatingFee = true);

    try {
      final result = await AuthService.instance.calculateDeliveryFee(
        deliveryAddressId: _deliveryAddressId!,
      );

      if (result.success && result.data != null && mounted) {
        final data = result.data as Map<String, dynamic>;
        final suppliers = (data['suppliers'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final total = (data['totalDeliveryFee'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          _supplierFees      = suppliers;
          _actualDeliveryFee = total;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isCalculatingFee = false);
    }
  }

  // Change 3 — calculate fee after address change
  Future<void> _changeAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => const AddressScreen(selectionMode: true)),
    );
    if (picked != null) {
      setState(() {
        _selectedAddress    = picked;
        _isMapPickedAddress = false;
      });
      await _calculateFee();
    }
  }

  Future<void> _addNewAddress() async {
    final saved = await AddressBottomSheet.show(context);
    if (saved != null && mounted) {
      await _loadAddresses();
      if (saved['id'] != null || saved['addressId'] != null) {
        setState(() {
          _selectedAddress    = saved;
          _isMapPickedAddress = false;
        });
      }
    }
  }

  Future<void> _pickLocationFromMap() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapLocationPickerScreen()),
    );

    if (picked == null || !mounted) return;
    setState(() => _isLoadingAddresses = true);

    final saveResult = await AuthService.instance.createAddress(
      streetAddress: picked['streetAddress'] as String? ?? '',
      apartment:     picked['apartment']     as String? ?? '',
      city:          picked['city']          as String? ?? '',
      state:         picked['state']         as String? ?? '',
      postalCode:    picked['postalCode']    as String? ?? '',
      country:       picked['country']       as String? ?? 'UK',
      addressType:   picked['addressType']   as int?    ?? 2,
      isDefault:     false,
      label:         'Current Location',
      latitude:      picked['latitude']      as double? ?? 0.0,
      longitude:     picked['longitude']     as double? ?? 0.0,
    );

    if (!mounted) return;

    if (saveResult.success && saveResult.data != null) {
      setState(() {
        _selectedAddress    = saveResult.data;
        _isMapPickedAddress = true;
        _isLoadingAddresses = false;
      });
      _loadAddresses().then((_) {
        if (!mounted || _selectedAddress == null) return;
        final savedId =
            saveResult.data!['id'] ?? saveResult.data!['addressId'];
        if (savedId == null) return;
        final match = _addresses.firstWhere(
              (a) => (a['id'] ?? a['addressId']).toString() == savedId.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty && mounted) {
          // Change 5 — calculate fee after map pick
          setState(() {
            _selectedAddress    = match;
            _isMapPickedAddress = true;
          });
          _calculateFee();
        }
      });
    } else {
      setState(() {
        _selectedAddress    = picked;
        _isMapPickedAddress = true;
        _isLoadingAddresses = false;
      });
      _snack(
        'Location selected but could not be saved. '
            'Please add it manually if checkout fails.',
        isError: false,
      );
    }
  }

  String? get _deliveryAddressId =>
      (_selectedAddress?['id'] ?? _selectedAddress?['addressId'])
          ?.toString();

  String _formatAddress(Map<String, dynamic> a) => [
    if ((a['streetAddress'] ?? '').toString().isNotEmpty) a['streetAddress'],
    if ((a['apartment']     ?? '').toString().isNotEmpty) a['apartment'],
    if ((a['city']          ?? '').toString().isNotEmpty) a['city'],
    if ((a['postalCode']    ?? '').toString().isNotEmpty) a['postalCode'],
  ].join(', ');

  String _addressLabel(Map<String, dynamic> a) {
    if (_isMapPickedAddress) return 'Current Location';
    final lbl = a['label']?.toString() ?? '';
    if (lbl.isNotEmpty) return lbl;
    final type = (a['addressType'] as num?)?.toInt() ?? 0;
    return ['Home', 'Work', 'Other'][type.clamp(0, 2)];
  }

  IconData _addressIcon(Map<String, dynamic> a) {
    if (_isMapPickedAddress) return Icons.location_on;
    switch ((a['addressType'] as num?)?.toInt() ?? 0) {
      case 1:  return Icons.work_outline;
      case 2:  return Icons.location_on_outlined;
      default: return Icons.home_outlined;
    }
  }

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
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }
    final arr = data['orders'];
    if (arr is List && arr.isNotEmpty && arr.first is Map<String, dynamic>) {
      final first = arr.first as Map<String, dynamic>;
      for (final k in keys) {
        final v = first[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
    }

    String? deep(dynamic node, int depth) {
      if (depth > 5) return null;
      if (node is Map<String, dynamic>) {
        for (final k in keys) {
          final v = node[k];
          if (v != null && v.toString().isNotEmpty && v.toString() != 'null')
            return v.toString();
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
    if (d == null) {
      debugPrint('❌ [orderId] NOT FOUND. Keys: ${data.keys.toList()}');
    }
    return d;
  }

  Future<void> _placeOrder() async {
    if (_deliveryAddressId == null || _deliveryAddressId!.isEmpty) {
      _snack('Please select a delivery address to continue.', isError: true);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId:             '',
          orderTotal:          widget.subtotal + _actualDeliveryFee,
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

              _Section(
                title: 'Delivery Address',
                icon:  Icons.location_on,
                child: _isLoadingAddresses
                    ? const _Loading(label: 'Loading addresses...')
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedAddress != null)
                      _AddressTile(
                        label:       _addressLabel(_selectedAddress!),
                        address:     _formatAddress(_selectedAddress!),
                        icon:        _addressIcon(_selectedAddress!),
                        isDefault:   !_isMapPickedAddress &&
                            _selectedAddress!['isDefault'] == true,
                        isMapPicked: _isMapPickedAddress,
                        onChange:    _changeAddress,
                      )
                    else
                      _NoAddress(
                        hasAddresses: _addresses.isNotEmpty,
                        onSelect:     _changeAddress,
                        onAdd:        _addNewAddress,
                      ),
                    const SizedBox(height: 12),
                    _UseLocationButton(onTap: _pickLocationFromMap),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                title: 'Special Instructions',
                icon:  Icons.note_alt_outlined,
                child: TextField(
                  controller:      _instructionsCtrl,
                  maxLines:        3,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDeco(
                      'Any special delivery instructions (optional)...'),
                ),
              ),
              const SizedBox(height: 16),

              _Section(
                title: 'Discount Code',
                icon:  Icons.local_offer_outlined,
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
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
                        _snack('Please enter a discount code.', isError: true);
                        return;
                      }
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

              _Section(
                title: 'Order Summary',
                icon:  Icons.receipt,
                child: Column(children: [
                  ...widget.cartItems.take(3).map((item) {
                    final name  = (item['productName'] ??
                        item['product']?['name'] ?? 'Product').toString();
                    final qty   = ((item['quantity'] ?? 0) as num).toInt();
                    final price = ((item['unitPrice'] ??
                        item['price'] ??
                        item['product']?['price'] ?? 0) as num)
                        .toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('$name × $qty',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('£${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w600,
                                  color:      AppColors.textPrimary)),
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
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  const Divider(height: 24),
                  _SummRow('Subtotal',
                      '£${widget.subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),

                  // Change 6 — dynamic delivery fee display
                  if (_isCalculatingFee)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery Fee',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    )
                  else if (_supplierFees.length > 1)
                    Column(
                      children: [
                        ..._supplierFees.map((s) {
                          final name = s['supplierName']?.toString() ?? 'Store';
                          final fee  = (s['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('$name delivery',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text('£${fee.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                          );
                        }),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Delivery',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)),
                            Text('£${_actualDeliveryFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    )
                  else
                    _SummRow('Delivery Fee',
                        '£${_actualDeliveryFee.toStringAsFixed(2)}'),

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
                          Text('Code: ${_discountCtrl.text.trim()}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.success)),
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
                  // Change 7 — actual total
                  _SummRow(
                    'Total',
                    '£${(widget.subtotal + _actualDeliveryFee).toStringAsFixed(2)}',
                    bold: true,
                  ),
                ]),
              ),
              const SizedBox(height: 24),

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
                            color: AppColors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 20),
                      const SizedBox(width: 10),
                      // Change 8 — actual total in button
                      Text(
                        'Proceed to Payment  •  '
                            '£${(widget.subtotal + _actualDeliveryFee).toStringAsFixed(2)}',
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
                          fontSize: 12, color: AppColors.textSecondary)),
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
    filled:    true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.all(12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );
}

// ══════════════════════════════════════════════════════════
//  Use Current Location button
// ══════════════════════════════════════════════════════════
class _UseLocationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UseLocationButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
            color: AppColors.primary.withOpacity(0.35), width: 1.2),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color:        AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.my_location, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use Current Location',
                    style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.primary)),
                Text('Pick on map & auto-fill address',
                    style: TextStyle(
                        fontSize: 11,
                        color:    AppColors.primary.withOpacity(0.7))),
              ]),
        ),
        Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════
class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 16),
        child,
      ]));
}

class _AddressTile extends StatelessWidget {
  final String   label, address;
  final IconData icon;
  final bool     isDefault, isMapPicked;
  final VoidCallback onChange;

  const _AddressTile({
    required this.label,
    required this.address,
    required this.icon,
    required this.isDefault,
    required this.isMapPicked,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: isMapPicked
                  ? Colors.blue.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon,
              color: isMapPicked ? Colors.blue : AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 6, runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                    if (isMapPicked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('📍 Map Pick', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: Colors.blue)),
                      )
                    else if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Default', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                      ),
                  ]),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
            ])),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(
            padding:       const EdgeInsets.symmetric(horizontal: 8),
            minimumSize:   const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Change'),
        ),
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
              border: Border.all(color: AppColors.warning.withOpacity(0.3))),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('No delivery address selected.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
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
    const SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2)),
    const SizedBox(width: 12),
    Text(label, style: const TextStyle(
        fontSize: 14, color: AppColors.textSecondary)),
  ]);
}

class _SummRow extends StatelessWidget {
  final String title, value;
  final bool   bold;
  const _SummRow(this.title, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: TextStyle(
            fontSize:   bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color:      AppColors.textPrimary)),
        Text(value, style: TextStyle(
            fontSize:   bold ? 18 : 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color:      bold ? AppColors.primary : AppColors.textPrimary)),
      ]);
}