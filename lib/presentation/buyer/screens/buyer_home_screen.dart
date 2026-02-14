import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/category_products_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/supplier_detail_screen.dart';

class BuyerHomeScreen extends StatelessWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'The Italian Restaurant',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          color: AppColors.white,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Bar
                    GestureDetector(
                      onTap: () {
                        // Navigate to search screen
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: AppColors.textHint),
                            const SizedBox(width: 12),
                            Text(
                              'Search products, suppliers...',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _CategoryCard(
                          label: 'Bakery',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoryProductsScreen(category: 'Bakery'),
                              ),
                            );
                          },
                        ),
                        _CategoryCard(
                          label: 'Meat',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoryProductsScreen(category: 'Meat'),
                              ),
                            );
                          },
                        ),
                        _CategoryCard(
                          label: 'Dairy',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoryProductsScreen(category: 'Dairy'),
                              ),
                            );
                          },
                        ),
                        _CategoryCard(
                          label: 'Fruit & Veg',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CategoryProductsScreen(category: 'Fruit & Veg'),
                              ),
                            );
                          },
                        ),
                        _CategoryCard(
                          label: 'Frozen',
                          onTap: () {},
                        ),
                        _CategoryCard(
                          label: 'Dry Items',
                          onTap: () {},
                        ),
                        _CategoryCard(
                          label: 'Beverages',
                          onTap: () {},
                        ),
                        _CategoryCard(
                          label: 'More',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Nearby Suppliers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nearby Suppliers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return _SupplierCard(
                      name: 'Premium Wholesale ${index + 1}',
                      distance: '${(index + 1) * 0.5} km',
                      rating: 4.5 + (index * 0.1),
                      products: '250+',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SupplierDetailScreen(
                              supplierName: 'Premium Wholesale ${index + 1}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Featured Products
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return _ProductCard(
                    name: index == 0 ? 'Fresh Tomatoes' : index == 1 ? 'Chicken Breast' : index == 2 ? 'Whole Milk' : 'White Bread',
                    price: 5.99 + index,
                    supplier: 'Supplier ${index + 1}',
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Category Card Widget - WITH ICONS
class _CategoryCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.onTap,
  });

  IconData _getCategoryIcon() {
    switch (label) {
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
      case 'Beverages':
        return Icons.local_cafe;
      case 'More':
        return Icons.apps;
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(),
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Supplier Card Widget
class _SupplierCard extends StatelessWidget {
  final String name;
  final String distance;
  final double rating;
  final String products;
  final VoidCallback onTap;

  const _SupplierCard({
    required this.name,
    required this.distance,
    required this.rating,
    required this.products,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12, left: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(
                  Icons.store,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$products Products',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Product Card Widget - WITH ICONS
class _ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final String supplier;

  const _ProductCard({
    required this.name,
    required this.price,
    required this.supplier,
  });

  IconData _getProductIcon() {
    if (name.contains('Tomato') || name.contains('Carrot')) return Icons.eco;
    if (name.contains('Chicken') || name.contains('Meat')) return Icons.set_meal;
    if (name.contains('Milk') || name.contains('Cheese')) return Icons.local_drink;
    if (name.contains('Bread')) return Icons.bakery_dining;
    return Icons.shopping_basket;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            alignment: Alignment.center,
            child: Icon(
              _getProductIcon(),
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
                    name,
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
                    supplier,
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
                        '£${price.toStringAsFixed(2)}',
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
    );
  }
}