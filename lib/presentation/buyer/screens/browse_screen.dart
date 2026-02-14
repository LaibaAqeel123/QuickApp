import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/category_products_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _allProducts = [
    {'id': 1, 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'price': 3.50, 'supplier': 'Premium Wholesale', 'stock': 150, 'unit': 'kg'},
    {'id': 2, 'name': 'Chicken Breast', 'category': 'Meat', 'price': 8.99, 'supplier': 'Fresh Meat Co.', 'stock': 75, 'unit': 'kg'},
    {'id': 3, 'name': 'Whole Milk', 'category': 'Dairy', 'price': 1.20, 'supplier': 'Dairy Farm', 'stock': 200, 'unit': 'L'},
    {'id': 4, 'name': 'White Bread', 'category': 'Bakery', 'price': 0.99, 'supplier': 'Baker\'s Best', 'stock': 120, 'unit': 'loaf'},
    {'id': 5, 'name': 'Cheddar Cheese', 'category': 'Dairy', 'price': 5.99, 'supplier': 'Dairy Farm', 'stock': 90, 'unit': 'kg'},
    {'id': 6, 'name': 'Carrots', 'category': 'Fruit & Veg', 'price': 2.20, 'supplier': 'Premium Wholesale', 'stock': 180, 'unit': 'kg'},
    {'id': 7, 'name': 'Frozen Pizza', 'category': 'Frozen', 'price': 4.50, 'supplier': 'Frozen Foods Ltd', 'stock': 80, 'unit': 'pc'},
    {'id': 8, 'name': 'Rice 5kg', 'category': 'Dry Items', 'price': 12.99, 'supplier': 'Grain Suppliers', 'stock': 50, 'unit': 'bag'},
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _allProducts;
    }
    return _allProducts.where((product) {
      return product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product['supplier'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Browse Products'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products, suppliers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Results Count
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surfaceLight,
              width: double.infinity,
              child: Text(
                '${_filteredProducts.length} products found',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // Products Grid
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try searching with different keywords',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return _ProductCard(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: Icon(
                _getCategoryIcon(product['category']),
                size: 60,
                color: AppColors.primary,
              ),
            ),

            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.store, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product['supplier'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '£${product['price'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'per ${product['unit']}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart,
                            color: AppColors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}