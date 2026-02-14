import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/supplier/screens/add_product_screen.dart';
import 'package:food_delivery_app/presentation/supplier/screens/product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Bakery', 'Meat', 'Dairy', 'Fruit & Veg', 'Frozen', 'Dry Items'];

  final List<Map<String, dynamic>> _products = [
    {'id': 1, 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'price': 3.50, 'stock': 150, 'unit': 'kg', 'image': '🍅'},
    {'id': 2, 'name': 'Chicken Breast', 'category': 'Meat', 'price': 8.99, 'stock': 75, 'unit': 'kg', 'image': '🍗'},
    {'id': 3, 'name': 'Whole Milk', 'category': 'Dairy', 'price': 1.20, 'stock': 200, 'unit': 'L', 'image': '🥛'},
    {'id': 4, 'name': 'White Bread', 'category': 'Bakery', 'price': 0.99, 'stock': 120, 'unit': 'loaf', 'image': '🍞'},
    {'id': 5, 'name': 'Frozen Pizza', 'category': 'Frozen', 'price': 4.50, 'stock': 80, 'unit': 'pc', 'image': '🍕'},
    {'id': 6, 'name': 'Rice 5kg', 'category': 'Dry Items', 'price': 12.99, 'stock': 50, 'unit': 'bag', 'image': '🍚'},
    {'id': 7, 'name': 'Cheddar Cheese', 'category': 'Dairy', 'price': 5.99, 'stock': 90, 'unit': 'kg', 'image': '🧀'},
    {'id': 8, 'name': 'Carrots', 'category': 'Fruit & Veg', 'price': 2.20, 'stock': 180, 'unit': 'kg', 'image': '🥕'},
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategory == 'All') {
      return _products;
    }
    return _products.where((p) => p['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories
          Container(
            height: 50,
            color: AppColors.surface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
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
                childAspectRatio: 0.75,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProductScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isLowStock = product['stock'] < 50;

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
              child: Text(
                product['image'],
                style: const TextStyle(fontSize: 60),
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
                    Text(
                      product['category'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '£${product['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLowStock ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product['stock']} ${product['unit']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isLowStock ? AppColors.error : AppColors.success,
                            ),
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