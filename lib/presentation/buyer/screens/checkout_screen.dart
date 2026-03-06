import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_bottom_sheet.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_success_screen.dart';

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
  // ── Address state ──────────────────────────────────────
  List<Map<String, dynamic>> _addresses          = [];
  Map<String, dynamic>?      _selectedAddress;
  bool                       _isLoadingAddresses = true;

  // ── Form state ─────────────────────────────────────────
  String    _deliveryType  = 'Standard';
  String    _paymentMethod = 'Card';
  DateTime  _selectedDate  = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime  = const TimeOfDay(hour: 10, minute: 0);

  final _specialInstructionsController = TextEditingController();
  final _discountCodeController         = TextEditingController();

  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _specialInstructionsController.dispose();
    _discountCodeController.dispose();
    super.dispose();
  }

  // ── Load addresses and pick default ───────────────────
  Future<void> _loadAddresses() async {
    setState(() => _isLoadingAddresses = true);

    final result = await AuthService.instance.getAddresses();

    if (!mounted) return;

    if (result.success) {
      final list = (result.data ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      // Auto-select the default address, otherwise the first one
      Map<String, dynamic>? defaultAddr;
      if (list.isNotEmpty) {
        defaultAddr = list.firstWhere(
          (a) => a['isDefault'] == true,
          orElse: () => list.first,
        );
      }

      setState(() {
        _addresses         = list;
        _selectedAddress   = defaultAddr;
        _isLoadingAddresses = false;
      });
    } else {
      setState(() => _isLoadingAddresses = false);
    }
  }

  // ── Open AddressScreen in selection mode ───────────────
  Future<void> _changeAddress() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressScreen(selectionMode: true),
      ),
    );
    if (picked != null) {
      setState(() => _selectedAddress = picked);
    }
  }

  // ── Add a new address inline from checkout ─────────────
  Future<void> _addNewAddress() async {
    final saved = await AddressBottomSheet.show(context);
    if (saved != null && mounted) {
      await _loadAddresses();
      // Select the newly created address if it came back with an ID
      if (saved['id'] != null || saved['addressId'] != null) {
        setState(() => _selectedAddress = saved);
      }
    }
  }

  // ── Address ID helper ──────────────────────────────────
  String? get _deliveryAddressId {
    if (_selectedAddress == null) return null;
    return (_selectedAddress!['id'] ?? _selectedAddress!['addressId'])?.toString();
  }

  // ── Full address display helper ────────────────────────
  String _formatAddress(Map<String, dynamic> a) {
    final parts = <String>[
      if ((a['streetAddress'] ?? '').toString().isNotEmpty)
        a['streetAddress'].toString(),
      if ((a['apartment'] ?? '').toString().isNotEmpty)
        a['apartment'].toString(),
      if ((a['city'] ?? '').toString().isNotEmpty) a['city'].toString(),
      if ((a['postalCode'] ?? '').toString().isNotEmpty)
        a['postalCode'].toString(),
    ];
    return parts.join(', ');
  }

  String _addressLabel(Map<String, dynamic> a) {
    final lbl  = a['label']?.toString() ?? '';
    if (lbl.isNotEmpty) return lbl;
    final type = (a['addressType'] as num?)?.toInt() ?? 0;
    return ['Home', 'Work', 'Other'][type.clamp(0, 2)];
  }

  IconData _addressTypeIcon(Map<String, dynamic> a) {
    final type = (a['addressType'] as num?)?.toInt() ?? 0;
    switch (type) {
      case 1:  return Icons.work_outline;
      case 2:  return Icons.location_on_outlined;
      default: return Icons.home_outlined;
    }
  }

  // ── Place Order ────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_deliveryAddressId == null || _deliveryAddressId!.isEmpty) {
      _showSnackBar(
        'Please select a delivery address to continue.',
        isError: true,
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final result = await AuthService.instance.checkout(
      deliveryAddressId:   _deliveryAddressId!,
      billingAddressId:    _deliveryAddressId!,
      specialInstructions: _specialInstructionsController.text.trim(),
      discountCode: _discountCodeController.text.trim().isEmpty
          ? null
          : _discountCodeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isPlacingOrder = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(orderData: result.data),
        ),
      );
    } else {
      _showSnackBar(
          result.message ?? 'Checkout failed. Please try again.',
          isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Delivery Address ───────────────────────
              _SectionCard(
                title: 'Delivery Address',
                icon:  Icons.location_on,
                child: _isLoadingAddresses
                    ? const _LoadingRow(label: 'Loading addresses...')
                    : _selectedAddress != null
                        ? _SelectedAddressTile(
                            label:       _addressLabel(_selectedAddress!),
                            fullAddress: _formatAddress(_selectedAddress!),
                            typeIcon:    _addressTypeIcon(_selectedAddress!),
                            isDefault:   _selectedAddress!['isDefault'] == true,
                            onChangeAddress: _changeAddress,
                          )
                        : _NoAddressWidget(
                            hasAddresses: _addresses.isNotEmpty,
                            onSelectAddress: _changeAddress,
                            onAddAddress:    _addNewAddress,
                          ),
              ),
              const SizedBox(height: 16),

              // ── Delivery Schedule ──────────────────────
              _SectionCard(
                title: 'Delivery Schedule',
                icon:  Icons.access_time,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DeliveryTypeButton(
                            label:      'Standard',
                            subtitle:   'Next day',
                            icon:       Icons.local_shipping,
                            isSelected: _deliveryType == 'Standard',
                            onTap: () => setState(() => _deliveryType = 'Standard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DeliveryTypeButton(
                            label:      'Express',
                            subtitle:   'Same day',
                            icon:       Icons.bolt,
                            isSelected: _deliveryType == 'Express',
                            onTap: () => setState(() => _deliveryType = 'Express'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context:     context,
                                initialDate: _selectedDate,
                                firstDate:   DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (date != null) setState(() => _selectedDate = date);
                            },
                            child: _DateTimeBox(
                              icon:  Icons.calendar_today,
                              label: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context:     context,
                                initialTime: _selectedTime,
                              );
                              if (time != null) setState(() => _selectedTime = time);
                            },
                            child: _DateTimeBox(
                              icon:  Icons.access_time,
                              label: _selectedTime.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Special Instructions ───────────────────
              _SectionCard(
                title: 'Special Instructions',
                icon:  Icons.note_alt_outlined,
                child: TextField(
                  controller: _specialInstructionsController,
                  maxLines:   3,
                  decoration: const InputDecoration(
                    hintText: 'Any special delivery instructions? (optional)',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Discount Code ──────────────────────────
              _SectionCard(
                title: 'Discount Code',
                icon:  Icons.local_offer_outlined,
                child: TextField(
                  controller: _discountCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter discount code (optional)',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Payment Method ─────────────────────────
              _SectionCard(
                title: 'Payment Method',
                icon:  Icons.payment,
                child: Column(
                  children: [
                    _PaymentMethodTile(
                      icon:       Icons.credit_card,
                      title:      'Credit/Debit Card',
                      subtitle:   'Visa, Mastercard, Amex',
                      value:      'Card',
                      groupValue: _paymentMethod,
                      onChanged:  (v) => setState(() => _paymentMethod = v!),
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodTile(
                      icon:       Icons.account_balance,
                      title:      'Bank Transfer',
                      subtitle:   'Direct bank transfer',
                      value:      'Bank',
                      groupValue: _paymentMethod,
                      onChanged:  (v) => setState(() => _paymentMethod = v!),
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodTile(
                      icon:       Icons.money,
                      title:      'Cash on Delivery',
                      subtitle:   'Pay when you receive',
                      value:      'Cash',
                      groupValue: _paymentMethod,
                      onChanged:  (v) => setState(() => _paymentMethod = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Order Summary ──────────────────────────
              _SectionCard(
                title: 'Order Summary',
                icon:  Icons.receipt,
                child: Column(
                  children: [
                    _SummaryRow(title: 'Subtotal',
                        value: '£${widget.subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _SummaryRow(title: 'Delivery Fee',
                        value: '£${widget.deliveryFee.toStringAsFixed(2)}'),
                    const Divider(height: 24),
                    _SummaryRow(
                      title:  'Total',
                      value:  '£${widget.total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Place Order Button ─────────────────────
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2.5))
                      : const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SELECTED ADDRESS TILE
// ══════════════════════════════════════════════════════════
class _SelectedAddressTile extends StatelessWidget {
  final String label;
  final String fullAddress;
  final IconData typeIcon;
  final bool isDefault;
  final VoidCallback onChangeAddress;

  const _SelectedAddressTile({
    required this.label,
    required this.fullAddress,
    required this.typeIcon,
    required this.isDefault,
    required this.onChangeAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(typeIcon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  if (isDefault) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Default',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(fullAddress,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onChangeAddress,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Change Address',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  NO ADDRESS WIDGET
// ══════════════════════════════════════════════════════════
class _NoAddressWidget extends StatelessWidget {
  final bool hasAddresses;
  final VoidCallback onSelectAddress;
  final VoidCallback onAddAddress;

  const _NoAddressWidget({
    required this.hasAddresses,
    required this.onSelectAddress,
    required this.onAddAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_outlined,
                  color: AppColors.error, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No delivery address selected.\nPlease add or select one.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (hasAddresses)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSelectAddress,
                  icon:  const Icon(Icons.list_alt, size: 18),
                  label: const Text('Select Saved'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            if (hasAddresses) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddAddress,
                icon:  const Icon(Icons.add_location_alt, size: 18),
                label: const Text('Add New'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  LOADING ROW
// ══════════════════════════════════════════════════════════
class _LoadingRow extends StatelessWidget {
  final String label;
  const _LoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SECTION CARD
// ══════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String  title;
  final IconData icon;
  final Widget  child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DELIVERY TYPE BUTTON
// ══════════════════════════════════════════════════════════
class _DeliveryTypeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryTypeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  DATE TIME BOX
// ══════════════════════════════════════════════════════════
class _DateTimeBox extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _DateTimeBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PAYMENT METHOD TILE
// ══════════════════════════════════════════════════════════
class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Radio<String>(
              value:      value,
              groupValue: groupValue,
              onChanged:  onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SUMMARY ROW
// ══════════════════════════════════════════════════════════
class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool   isBold;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize:   isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color:      AppColors.textPrimary)),
        Text(value,
            style: TextStyle(
                fontSize:   isBold ? 18 : 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color:      isBold ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}