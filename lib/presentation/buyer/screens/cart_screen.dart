import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [
    {
      'id': 1,
      'name': 'Fresh Tomatoes',
      'category': 'Fruit & Veg',
      'price': 3.50,
      'quantity': 10,
      'unit': 'kg',
      'supplier': 'Premium Wholesale',
    },
    {
      'id': 2,
      'name': 'Chicken Breast',
      'category': 'Meat',
      'price': 8.99,
      'quantity': 5,
      'unit': 'kg',
      'supplier': 'Fresh Meat Co.',
    },
    {
      'id': 3,
      'name': 'Whole Milk',
      'category': 'Dairy',
      'price': 1.20,
      'quantity': 20,
      'unit': 'L',
      'supplier': 'Premium Wholesale',
    },
    {
      'id': 4,
      'name': 'White Bread',
      'category': 'Bakery',
      'price': 0.99,
      'quantity': 15,
      'unit': 'loaf',
      'supplier': 'Baker\'s Best',
    },
  ];

  double get _subtotal {
    return _cartItems.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  double get _deliveryFee {
    return 8.50;
  }

  double get _total {
    return _subtotal + _deliveryFee;
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _cartItems[index]['quantity'] = newQuantity;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removed from cart'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> get _groupedBySupplier {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _cartItems) {
      String supplier = item['supplier'];
      if (!grouped.containsKey(supplier)) {
        grouped[supplier] = [];
      }
      grouped[supplier]!.add(item);
    }
    return grouped;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bakery':
        return Icons.bakery_dining;
      case 'Meat':
        return Icons.set_meal;
      case 'Dairy':
        return Icons.local_drink;
      case 'Fruit & Veg':
        return Icons.eco;
      case 'Frozen':
        return Icons.ac_unit;
      case 'Dry Items':
        return Icons.grain;
      default:
        return Icons.shopping_basket;
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
            TextButton(
              onPressed: () {
                setState(() {
                  _cartItems.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cart cleared'),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppColors.white),
              ),
            ),
        ],
      ),
      body: _cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products to get started',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to browse
              },
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Browse Products'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Cart Items (Grouped by Supplier)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groupedBySupplier.length,
              itemBuilder: (context, index) {
                final supplier = _groupedBySupplier.keys.elementAt(index);
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
                          const Icon(
                            Icons.store,
                            color: AppColors.primary,
                            size: 20,
                          ),
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
                    ...items.asMap().entries.map((entry) {
                      final itemIndex = _cartItems.indexOf(entry.value);
                      final item = entry.value;
                      return _CartItemCard(
                        item: item,
                        icon: _getCategoryIcon(item['category']),
                        onIncrease: () => _updateQuantity(itemIndex, item['quantity'] + 1),
                        onDecrease: () => _updateQuantity(itemIndex, item['quantity'] - 1),
                        onRemove: () => _removeItem(itemIndex),
                      );
                    }).toList(),

                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),

          // Order Summary
          Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '£${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery Fee',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '£${_deliveryFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '£${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
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
                            builder: (context) => CheckoutScreen(
                              cartItems: _cartItems,
                              subtotal: _subtotal,
                              deliveryFee: _deliveryFee,
                              total: _total,
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
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final IconData icon;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
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
            child: Icon(
              icon,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '£${item['price'].toStringAsFixed(2)} per ${item['unit']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '£${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Quantity Controls
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: onDecrease,
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${item['quantity']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add, size: 18, color: AppColors.white),
                      onPressed: onIncrease,
                    ),
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
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}