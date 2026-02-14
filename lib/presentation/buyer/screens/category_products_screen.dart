import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class CategoryProductsScreen extends StatelessWidget {
  final String category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final products = _getProductsByCategory();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(category),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(),
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${products.length} products available',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
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

  IconData _getCategoryIcon() {
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

  List<Map<String, dynamic>> _getProductsByCategory() {
    final allProducts = [
      {'id': 1, 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'price': 3.50, 'supplier': 'Premium Wholesale', 'stock': 150, 'unit': 'kg'},
      {'id': 2, 'name': 'Chicken Breast', 'category': 'Meat', 'price': 8.99, 'supplier': 'Fresh Meat Co.', 'stock': 75, 'unit': 'kg'},
      {'id': 3, 'name': 'Whole Milk', 'category': 'Dairy', 'price': 1.20, 'supplier': 'Dairy Farm', 'stock': 200, 'unit': 'L'},
      {'id': 4, 'name': 'White Bread', 'category': 'Bakery', 'price': 0.99, 'supplier': 'Baker\'s Best', 'stock': 120, 'unit': 'loaf'},
      {'id': 5, 'name': 'Croissants', 'category': 'Bakery', 'price': 2.50, 'supplier': 'Baker\'s Best', 'stock': 80, 'unit': 'pack'},
      {'id': 6, 'name': 'Beef Steak', 'category': 'Meat', 'price': 15.99, 'supplier': 'Fresh Meat Co.', 'stock': 40, 'unit': 'kg'},
      {'id': 7, 'name': 'Cheddar Cheese', 'category': 'Dairy', 'price': 5.99, 'supplier': 'Dairy Farm', 'stock': 90, 'unit': 'kg'},
      {'id': 8, 'name': 'Carrots', 'category': 'Fruit & Veg', 'price': 2.20, 'supplier': 'Premium Wholesale', 'stock': 180, 'unit': 'kg'},
    ];

    return allProducts.where((p) => p['category'] == category).toList();
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
                        const Icon(Icons.store, size: 12, color: AppColors.textHint),
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
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          '${product['stock']} ${product['unit']} available',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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