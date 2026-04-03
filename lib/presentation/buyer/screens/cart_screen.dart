import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onBrowseTap;
  const CartScreen({super.key, this.onBrowseTap});

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _cartMeta;
  bool _isLoading  = true;
  bool _isClearing = false;
  String? _errorMessage;
  bool _hasLoadedOnce = false;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCart();
    _hasLoadedOnce = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedOnce) _loadCart();
  }

  void reload() => _loadCart();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _loadCart();
  }

  // ── Field helpers ──────────────────────────────────────
  String _itemId(Map<String, dynamic> item) =>
      (item['id'] ?? item['cartItemId'] ?? '').toString();

  String _itemName(Map<String, dynamic> item) =>
      (item['productName'] ?? item['product']?['name'] ?? 'Product')
          .toString();

  String _itemCategory(Map<String, dynamic> item) =>
      (item['category'] ?? item['product']?['category'] ?? '').toString();

  double _itemPrice(Map<String, dynamic> item) =>
      ((item['unitPrice'] ??
                  item['price'] ??
                  item['product']?['price'] ??
                  0) as num)
          .toDouble();

  int _itemQty(Map<String, dynamic> item) =>
      ((item['quantity'] ?? 0) as num).toInt();

  String _itemUnit(Map<String, dynamic> item) =>
      (item['unit'] ?? item['product']?['unit'] ?? 'unit').toString();

  String _itemSupplier(Map<String, dynamic> item) =>
      (item['supplierName'] ?? item['supplier']?['name'] ?? 'Supplier')
          .toString();

  double get _subtotal =>
      _cartItems.fold(0, (s, i) => s + (_itemPrice(i) * _itemQty(i)));

  /// Base delivery fee from API meta, or default £0.00
  double get _baseDeliveryFee =>
      (_cartMeta?['deliveryFee'] as num?)?.toDouble() ?? 0.00;

  /// Number of distinct suppliers in the cart
  int get _storeCount => _grouped.keys.length;

  /// Delivery fee multiplied by number of stores — passed to checkout
  /// after the user confirms the multi-store popup.
  double get _totalDeliveryFee => _baseDeliveryFee * _storeCount;

  /// What we show in the cart summary bar — just the base fee.
  /// The full multiplied fee is revealed in the checkout popup.
  double get _displayDeliveryFee => _baseDeliveryFee;

  double get _displayTotal => _subtotal + _displayDeliveryFee;

  // ── API calls ──────────────────────────────────────────
  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    final result = await AuthService.instance.getCart();
    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;
      List<dynamic> raw = [];
      if (data['items']     is List) raw = data['items']     as List;
      if (data['cartItems'] is List) raw = data['cartItems'] as List;
      setState(() {
        _cartMeta  = data;
        _cartItems = raw.whereType<Map<String, dynamic>>().toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading    = false;
        _errorMessage = result.message ?? 'Failed to load cart.';
      });
    }
  }

  Future<void> _updateQuantity(int index, int newQty) async {
    if (newQty <= 0) {
      await _removeItem(index);
      return;
    }
    final item = _cartItems[index];
    final id   = _itemId(item);
    if (id.isEmpty) return;
    setState(() => _cartItems[index]['quantity'] = newQty);
    final result = await AuthService.instance
        .updateCartItem(cartItemId: id, quantity: newQty);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _cartItems[index]['quantity'] = _itemQty(item));
      _snack(result.message ?? 'Failed to update.', isError: true);
    } else {
      await _loadCart();
    }
  }

  Future<void> _removeItem(int index) async {
    final item = _cartItems[index];
    final id   = _itemId(item);
    if (id.isEmpty) return;
    setState(() => _cartItems.removeAt(index));
    final result = await AuthService.instance.removeCartItem(id);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _cartItems.insert(index, item));
      _snack(result.message ?? 'Failed to remove.', isError: true);
    } else {
      _snack('Item removed from cart');
      await _loadCart();
    }
  }

  Future<void> _clearCart() async {
    setState(() => _isClearing = true);
    final result = await AuthService.instance.clearCartApi();
    if (!mounted) return;
    setState(() => _isClearing = false);
    if (result.success) {
      setState(() {
        _cartItems.clear();
        _cartMeta = null;
      });
      _snack('Cart cleared');
    } else {
      _snack(result.message ?? 'Failed to clear cart.', isError: true);
    }
  }

  /// Shows a dialog warning the user about multiple stores.
  /// Returns true if the user wants to continue, false if they cancel.
  Future<bool> _confirmMultiStore() async {
    if (_storeCount <= 1) return true; // no warning needed

    final storeNames = _grouped.keys.toList();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store_mall_directory_outlined,
                          color: Colors.orange, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Order from $_storeCount Stores',
                      style: const TextStyle(
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                          color:      Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your cart has items from multiple stores',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ]),
                ),

                // Store list
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stores in your order:',
                          style: TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      Colors.black54)),
                      const SizedBox(height: 8),
                      ...storeNames.map((name) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Container(
                                width:  8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontSize:   14,
                                        fontWeight: FontWeight.w500,
                                        color:      Colors.black87)),
                              ),
                            ]),
                          )),
                    ],
                  ),
                ),

                // Delivery fee breakdown — this is where we reveal the full fee
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.shade200, width: 1),
                  ),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Base delivery fee',
                            style: TextStyle(
                                fontSize: 13,
                                color:    Colors.grey.shade700)),
                        Text('£${_baseDeliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color:    Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('× $_storeCount stores',
                            style: TextStyle(
                                fontSize: 13,
                                color:    Colors.grey.shade700)),
                        Text('= £${_totalDeliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.bold,
                                color:      Colors.orange)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total delivery fee',
                            style: TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                                color:      Colors.black87)),
                        Text('£${_totalDeliveryFee.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold,
                                color:      Colors.orange.shade700)),
                      ],
                    ),
                  ]),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Continue to Checkout',
                            style: TextStyle(
                                fontSize:   15,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Review My Cart',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration:        const Duration(seconds: 2),
    ));
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final item in _cartItems) {
      out.putIfAbsent(_itemSupplier(item), () => []).add(item);
    }
    return out;
  }

  IconData _icon(String cat) {
    switch (cat.toLowerCase()) {
      case 'bakery':        return Icons.bakery_dining;
      case 'meat':          return Icons.set_meal;
      case 'dairy':         return Icons.local_drink;
      case 'fruit & veg':
      case 'fruit and veg':
      case 'vegetables':    return Icons.eco;
      case 'frozen':        return Icons.ac_unit;
      case 'dry items':     return Icons.grain;
      default:              return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           Text('Cart (${_cartItems.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          if (_cartItems.isNotEmpty)
            _isClearing
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _clearCart,
                    child: const Text('Clear All',
                        style: TextStyle(color: AppColors.white)),
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _loadCart)
              : _cartItems.isEmpty
                  ? _EmptyCartView(
                      onBrowse: widget.onBrowseTap ?? () {})
                  : Column(children: [
                      // ── Multi-store banner REMOVED ─────
                      // The full delivery fee breakdown is shown
                      // in the checkout popup instead.

                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadCart,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _grouped.length,
                            itemBuilder: (_, i) {
                              final supplier =
                                  _grouped.keys.elementAt(i);
                              final items = _grouped[supplier]!;
                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(
                                        bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.store,
                                          color: AppColors.primary,
                                          size:  20),
                                      const SizedBox(width: 8),
                                      Text(supplier,
                                          style: const TextStyle(
                                              fontSize:   15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary)),
                                    ]),
                                  ),
                                  ...items.map((item) {
                                    final gi = _cartItems.indexOf(item);
                                    return _CartItemCard(
                                      item:       item,
                                      itemName:   _itemName(item),
                                      price:      _itemPrice(item),
                                      quantity:   _itemQty(item),
                                      unit:       _itemUnit(item),
                                      icon:       _icon(_itemCategory(item)),
                                      onIncrease: () => _updateQuantity(
                                          gi, _itemQty(item) + 1),
                                      onDecrease: () => _updateQuantity(
                                          gi, _itemQty(item) - 1),
                                      onRemove:   () => _removeItem(gi),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      _OrderSummaryBar(
                        subtotal:          _subtotal,
                        // Show only the base delivery fee here.
                        // The total (multiplied) fee is shown in
                        // the popup before proceeding to checkout.
                        displayDeliveryFee: _displayDeliveryFee,
                        displayTotal:       _displayTotal,
                        // Pass the real multiplied fee to checkout
                        // after the user confirms the popup.
                        actualDeliveryFee:  _totalDeliveryFee,
                        actualTotal:        _subtotal + _totalDeliveryFee,
                        storeCount:         _storeCount,
                        cartItems:          _cartItems,
                        cartMeta:           _cartMeta,
                        onCheckoutSuccess:  _loadCart,
                        onProceed:          _confirmMultiStore,
                      ),
                    ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Order Summary Bar
//  - displayDeliveryFee / displayTotal  → shown in cart (base fee only)
//  - actualDeliveryFee  / actualTotal   → passed to CheckoutScreen
//    after the user confirms the multi-store popup
// ══════════════════════════════════════════════════════════
class _OrderSummaryBar extends StatelessWidget {
  final double subtotal;
  final double displayDeliveryFee;
  final double displayTotal;
  final double actualDeliveryFee;
  final double actualTotal;
  final int    storeCount;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>?      cartMeta;
  final VoidCallback               onCheckoutSuccess;
  final Future<bool> Function()    onProceed;

  const _OrderSummaryBar({
    required this.subtotal,
    required this.displayDeliveryFee,
    required this.displayTotal,
    required this.actualDeliveryFee,
    required this.actualTotal,
    required this.storeCount,
    required this.cartItems,
    required this.cartMeta,
    required this.onCheckoutSuccess,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset:     const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          _SummaryRow('Subtotal',
              '£${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          // Always show just the base delivery fee in the cart.
          // No store-count multiplier here — that appears in the popup.
          if (storeCount > 1)
            _SummaryRow(
              'Delivery Fee',
              '£${displayDeliveryFee.toStringAsFixed(2)} × $storeCount stores (est.)',
              valueColor: Colors.orange,
            )
else
            _SummaryRow('Delivery Fee',
                '£${displayDeliveryFee.toStringAsFixed(2)} (est.)'),

          const Divider(height: 24),
          _SummaryRow('Total',
              '£${displayTotal.toStringAsFixed(2)}',
              bold: true),
          const SizedBox(height: 16),
          SizedBox(
            width:  double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                // Show multi-store confirmation if needed.
                // Only after user taps "Continue to Checkout" do we
                // proceed with the full (multiplied) delivery fee.
                final proceed = await onProceed();
                if (!proceed || !context.mounted) return;

                final success = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      cartItems:   cartItems,
                      subtotal:    subtotal,
                      // After popup confirmation, use the real fee
                      deliveryFee: actualDeliveryFee,
                      total:       actualTotal,
                      cartMeta:    cartMeta,
                    ),
                  ),
                );
                if (success == true) onCheckoutSuccess();
              },
              child: const Text('Proceed to Checkout'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize:   bold ? 18 : 15,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color:      AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize:   bold ? 20 : 15,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color:      valueColor ??
                      (bold ? AppColors.primary : AppColors.textPrimary))),
        ],
      );
}

// ══════════════════════════════════════════════════════════
//  Empty Cart
// ══════════════════════════════════════════════════════════
class _EmptyCartView extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyCartView({required this.onBrowse});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 100, color: AppColors.textHint),
          const SizedBox(height: 24),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add products to get started',
              style: TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onBrowse,
            icon:  const Icon(Icons.shopping_bag),
            label: const Text('Browse Products'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
//  Error View
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.error_outline,
                size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    color:    AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon:  const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════
//  Cart Item Card
// ══════════════════════════════════════════════════════════
class _CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String   itemName, unit;
  final double   price;
  final int      quantity;
  final IconData icon;
  final VoidCallback onIncrease, onDecrease, onRemove;

  const _CartItemCard({
    required this.item,
    required this.itemName,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.icon,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width:  60,
            height: 60,
            decoration: BoxDecoration(
              color:        AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(itemName,
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('£${price.toStringAsFixed(2)} per $unit',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text('£${(price * quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.primary)),
            ]),
          ),
          Column(children: [
            Row(children: [
              _QtyBtn(
                  icon:   Icons.remove,
                  bg:     AppColors.surface,
                  fg:     AppColors.textPrimary,
                  onTap:  onDecrease,
                  border: true),
              SizedBox(
                width: 40,
                child: Center(
                  child: Text('$quantity',
                      style: const TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.textPrimary)),
                ),
              ),
              _QtyBtn(
                  icon:  Icons.add,
                  bg:    AppColors.primary,
                  fg:    AppColors.white,
                  onTap: onIncrease),
            ]),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                  padding:       EdgeInsets.zero,
                  minimumSize:   const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Remove',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.error)),
            ),
          ]),
        ]),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final Color bg, fg;
  final VoidCallback onTap; final bool border;
  const _QtyBtn({
    required this.icon, required this.bg,
    required this.fg, required this.onTap, this.border = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width:  32, height: 32,
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(8),
            border: border ? Border.all(color: AppColors.border) : null,
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      );
}