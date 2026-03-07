import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Each item shape comes from the API — we store the raw map and parse safely
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _cartMeta; // top-level cart data (id, totals, etc.)
  bool _isLoading    = true;
  bool _isClearing   = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  // ── Helpers to safely read API fields ─────────────────
  String _itemId(Map<String, dynamic> item) =>
      (item['id'] ?? item['cartItemId'] ?? '').toString();

  String _productId(Map<String, dynamic> item) =>
      (item['productId'] ?? item['product']?['id'] ?? '').toString();

  String _itemName(Map<String, dynamic> item) =>
      (item['productName'] ?? item['product']?['name'] ?? 'Product').toString();

  String _itemCategory(Map<String, dynamic> item) =>
      (item['category'] ?? item['product']?['category'] ?? '').toString();

  double _itemPrice(Map<String, dynamic> item) {
    final raw = item['unitPrice'] ?? item['price'] ?? item['product']?['price'] ?? 0;
    return (raw as num).toDouble();
  }

  int _itemQty(Map<String, dynamic> item) {
    final raw = item['quantity'] ?? 0;
    return (raw as num).toInt();
  }

  String _itemUnit(Map<String, dynamic> item) =>
      (item['unit'] ?? item['product']?['unit'] ?? 'unit').toString();

  String _itemSupplier(Map<String, dynamic> item) =>
      (item['supplierName'] ?? item['supplier']?['name'] ?? 'Supplier').toString();

  double get _subtotal {
    return _cartItems.fold(
        0, (sum, item) => sum + (_itemPrice(item) * _itemQty(item)));
  }

  double get _deliveryFee => (_cartMeta?['deliveryFee'] as num?)?.toDouble() ?? 8.50;
  double get _total       => (_cartMeta?['total'] as num?)?.toDouble() ?? (_subtotal + _deliveryFee);

  // ── Load Cart from API ──────────────────────────────────
  Future<void> _loadCart() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await AuthService.instance.getCart();

    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;
      // Items may be at data['items'] or data['cartItems'] or the list itself
      List<dynamic> rawItems = [];
      if (data['items'] is List)     rawItems = data['items'] as List;
      if (data['cartItems'] is List) rawItems = data['cartItems'] as List;

      setState(() {
        _cartMeta  = data;
        _cartItems = rawItems
            .whereType<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading    = false;
        _errorMessage = result.message ?? 'Failed to load cart.';
      });
    }
  }

  // ── Update Quantity via API ─────────────────────────────
  Future<void> _updateQuantity(int index, int newQuantity) async {
    if (newQuantity <= 0) {
      await _removeItem(index);
      return;
    }

    final item       = _cartItems[index];
    final cartItemId = _itemId(item);
    if (cartItemId.isEmpty) return;

    // Optimistic UI update
    setState(() => _cartItems[index]['quantity'] = newQuantity);

    final result = await AuthService.instance.updateCartItem(
      cartItemId: cartItemId,
      quantity:   newQuantity,
    );

    if (!mounted) return;

    if (!result.success) {
      // Revert on failure
      setState(() => _cartItems[index]['quantity'] = _itemQty(item));
      _showSnackBar(result.message ?? 'Failed to update quantity.', isError: true);
    } else {
      // Refresh cart to get accurate totals from server
      await _loadCart();
    }
  }

  // ── Remove Item via API ─────────────────────────────────
  Future<void> _removeItem(int index) async {
    final item       = _cartItems[index];
    final cartItemId = _itemId(item);
    if (cartItemId.isEmpty) return;

    // Optimistic removal
    setState(() => _cartItems.removeAt(index));

    final result = await AuthService.instance.removeCartItem(cartItemId);

    if (!mounted) return;

    if (!result.success) {
      // Revert
      setState(() => _cartItems.insert(index, item));
      _showSnackBar(result.message ?? 'Failed to remove item.', isError: true);
    } else {
      _showSnackBar('Item removed from cart');
      await _loadCart();
    }
  }

  // ── Clear Entire Cart via API ───────────────────────────
  Future<void> _clearCart() async {
    setState(() => _isClearing = true);

    final result = await AuthService.instance.clearCart();

    if (!mounted) return;

    setState(() => _isClearing = false);

    if (result.success) {
      setState(() { _cartItems.clear(); _cartMeta = null; });
      _showSnackBar('Cart cleared');
    } else {
      _showSnackBar(result.message ?? 'Failed to clear cart.', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> get _groupedBySupplier {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _cartItems) {
      final supplier = _itemSupplier(item);
      grouped.putIfAbsent(supplier, () => []).add(item);
    }
    return grouped;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bakery':    return Icons.bakery_dining;
      case 'meat':      return Icons.set_meal;
      case 'dairy':     return Icons.local_drink;
      case 'fruit & veg':
      case 'fruit and veg':
      case 'vegetables': return Icons.eco;
      case 'frozen':    return Icons.ac_unit;
      case 'dry items': return Icons.grain;
      default:          return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Cart (${_cartItems.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          if (_cartItems.isNotEmpty)
            _isClearing
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
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
              ? _ErrorView(
                  message: _errorMessage!,
                  onRetry: _loadCart,
                )
              : _cartItems.isEmpty
                  ? _EmptyCartView(onBrowse: () => Navigator.pop(context))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadCart,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _groupedBySupplier.length,
                              itemBuilder: (context, index) {
                                final supplier =
                                    _groupedBySupplier.keys.elementAt(index);
                                final items = _groupedBySupplier[supplier]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Supplier Header
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.store,
                                              color: AppColors.primary, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            supplier,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Items from this supplier
                                    ...items.map((item) {
                                      final globalIndex = _cartItems.indexOf(item);
                                      return _CartItemCard(
                                        item:        item,
                                        itemName:    _itemName(item),
                                        price:       _itemPrice(item),
                                        quantity:    _itemQty(item),
                                        unit:        _itemUnit(item),
                                        icon:        _getCategoryIcon(_itemCategory(item)),
                                        onIncrease:  () => _updateQuantity(
                                            globalIndex, _itemQty(item) + 1),
                                        onDecrease:  () => _updateQuantity(
                                            globalIndex, _itemQty(item) - 1),
                                        onRemove:    () => _removeItem(globalIndex),
                                      );
                                    }).toList(),

                                    const SizedBox(height: 16),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Order Summary
                        _OrderSummaryBar(
                          subtotal:    _subtotal,
                          deliveryFee: _deliveryFee,
                          total:       _total,
                          cartItems:   _cartItems,
                          cartMeta:    _cartMeta,
                        ),
                      ],
                    ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ORDER SUMMARY BAR
// ══════════════════════════════════════════════════════════
class _OrderSummaryBar extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double total;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? cartMeta;

  const _OrderSummaryBar({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.cartItems,
    required this.cartMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _SummaryRow(label: 'Subtotal',     value: '£${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Delivery Fee', value: '£${deliveryFee.toStringAsFixed(2)}'),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Total',
              value: '£${total.toStringAsFixed(2)}',
              isBold: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutScreen(
                        cartItems:   cartItems,
                        subtotal:    subtotal,
                        deliveryFee: deliveryFee,
                        total:       total,
                        cartMeta:    cartMeta,
                      ),
                    ),
                  );
                },
                child: const Text('Proceed to Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize:   isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color:      AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize:   isBold ? 20 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color:      isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EMPTY CART VIEW
// ══════════════════════════════════════════════════════════
class _EmptyCartView extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyCartView({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 100, color: AppColors.textHint),
          const SizedBox(height: 24),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Add products to get started',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onBrowse,
            icon:  const Icon(Icons.shopping_bag),
            label: const Text('Browse Products'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CART ITEM CARD
// ══════════════════════════════════════════════════════════
class _CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String   itemName;
  final double   price;
  final int      quantity;
  final String   unit;
  final IconData icon;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Product Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('£${price.toStringAsFixed(2)} per $unit',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('£${(price * quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
          ),

          // Quantity Controls
          Column(
            children: [
              Row(
                children: [
                  _QtyButton(
                    icon:    Icons.remove,
                    bgColor: AppColors.surface,
                    iconColor: AppColors.textPrimary,
                    onTap:   onDecrease,
                    hasBorder: true,
                  ),
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text('$quantity',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                  _QtyButton(
                    icon:    Icons.add,
                    bgColor: AppColors.primary,
                    iconColor: AppColors.white,
                    onTap:   onIncrease,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove',
                    style: TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Color    bgColor;
  final Color    iconColor;
  final VoidCallback onTap;
  final bool hasBorder;

  const _QtyButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: hasBorder ? Border.all(color: AppColors.border) : null,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}