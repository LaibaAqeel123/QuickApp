import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class SupplierDetailScreen extends StatelessWidget {
  final String supplierName;

  const SupplierDetailScreen({super.key, required this.supplierName});

  @override
  Widget build(BuildContext context) {
    final products = _getSupplierProducts();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Supplier Info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      supplierName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, size: 18, color: AppColors.warning),
                        const SizedBox(width: 4),
                        const Text(
                          '4.8',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on, size: 18, color: AppColors.white),
                        const SizedBox(width: 4),
                        const Text(
                          '2.5 km',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Info Cards
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.inventory_2,
                      value: '${products.length}+',
                      label: 'Products',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.local_shipping,
                      value: 'Same Day',
                      label: 'Delivery',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.verified,
                      value: 'Certified',
                      label: 'Verified',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // About Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Premium wholesale supplier providing high-quality products to restaurants and businesses across the region. Trusted by over 500+ businesses.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        '+44 20 1234 5678',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Mon-Sat: 6:00 AM - 8:00 PM',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Products Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('Filter'),
                  ),
                ],
              ),
            ),
          ),

          // Products Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                childCount: products.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSupplierProducts() {
    return [
      {'id': 1, 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'price': 3.50, 'supplier': supplierName, 'stock': 150, 'unit': 'kg'},
      {'id': 2, 'name': 'Carrots', 'category': 'Fruit & Veg', 'price': 2.20, 'supplier': supplierName, 'stock': 180, 'unit': 'kg'},
      {'id': 3, 'name': 'Potatoes', 'category': 'Fruit & Veg', 'price': 1.80, 'supplier': supplierName, 'stock': 200, 'unit': 'kg'},
      {'id': 4, 'name': 'Onions', 'category': 'Fruit & Veg', 'price': 1.50, 'supplier': supplierName, 'stock': 120, 'unit': 'kg'},
      {'id': 5, 'name': 'Bell Peppers', 'category': 'Fruit & Veg', 'price': 4.20, 'supplier': supplierName, 'stock': 90, 'unit': 'kg'},
      {'id': 6, 'name': 'Lettuce', 'category': 'Fruit & Veg', 'price': 2.50, 'supplier': supplierName, 'stock': 80, 'unit': 'kg'},
    ];
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
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