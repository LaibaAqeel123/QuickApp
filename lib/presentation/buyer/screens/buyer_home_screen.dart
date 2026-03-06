import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/category_products_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/supplier_detail_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  // ── State ──────────────────────────────────────────────
  List<Map<String, dynamic>> _categories     = [];
  bool                       _categoriesLoading = true;

  String _businessName = '';
  bool   _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCategories();
  }

  // ── Load profile for header name ───────────────────────
  Future<void> _loadProfile() async {
    final result = await AuthService.instance.getProfile();
    if (!mounted) return;

    if (result.success && result.data != null) {
      final data     = result.data!;
      final business = data['businessName']?.toString() ?? '';
      final first    = data['firstName']?.toString()    ?? '';
      final last     = data['lastName']?.toString()     ?? '';

      setState(() {
        _businessName = business.isNotEmpty
            ? business
            : '$first $last'.trim().isNotEmpty
                ? '$first $last'.trim()
                : 'My Account';
        _profileLoaded = true;
      });
    }
  }

  // ── Load categories from API ───────────────────────────
  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);

    final result = await AuthService.instance.getCategories();
    if (!mounted) return;

    if (result.success && result.data != null) {
      final list = result.data!
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _categories        = list;
        _categoriesLoading = false;
      });
    } else {
      // Fall back to static list so the screen is never empty
      setState(() {
        _categories        = _fallbackCategories;
        _categoriesLoading = false;
      });
    }
  }

  // ── Fallback static categories (used if API fails) ─────
  static const List<Map<String, dynamic>> _fallbackCategories = [
    {'id': null, 'name': 'Bakery'},
    {'id': null, 'name': 'Meat'},
    {'id': null, 'name': 'Dairy'},
    {'id': null, 'name': 'Fruit & Veg'},
    {'id': null, 'name': 'Frozen'},
    {'id': null, 'name': 'Dry Items'},
    {'id': null, 'name': 'Beverages'},
    {'id': null, 'name': 'More'},
  ];

  // ── Navigate to category products ─────────────────────
  void _openCategory(Map<String, dynamic> cat) {
    final name = cat['name']?.toString() ?? '';
    final id   = cat['id'];
    final intId = id is int
        ? id
        : id != null
            ? int.tryParse(id.toString())
            : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          category:   name,
          categoryId: intId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back 👋',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profileLoaded && _businessName.isNotEmpty
                                  ? _businessName
                                  : 'My Restaurant',
                              style: const TextStyle(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                                  color: AppColors.textHint, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Categories ─────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_categoriesLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Show shimmer placeholders while loading,
                    // then the real grid
                    _categoriesLoading
                        ? _CategoriesShimmer()
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:  4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: _categories.length > 8
                                ? 8
                                : _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return _CategoryCard(
                                label: cat['name']?.toString() ?? '',
                                onTap: () => _openCategory(cat),
                              );
                            },
                          ),
                  ],
                ),
              ),

              // ── Nearby Suppliers ───────────────────────
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
                      name:     'Premium Wholesale ${index + 1}',
                      distance: '${(index + 1) * 0.5} km',
                      rating:   4.5 + (index * 0.1),
                      products: '250+',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierDetailScreen(
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

              // ── Featured Products ──────────────────────
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:  2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing:  12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  const names = [
                    'Fresh Tomatoes',
                    'Chicken Breast',
                    'Whole Milk',
                    'White Bread',
                  ];
                  return _ProductCard(
                    name:     names[index],
                    price:    5.99 + index,
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

// ══════════════════════════════════════════════════════════
//  CATEGORIES SHIMMER (loading placeholder)
// ══════════════════════════════════════════════════════════
class _CategoriesShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   4,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CATEGORY CARD
// ══════════════════════════════════════════════════════════
class _CategoryCard extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;

  const _CategoryCard({required this.label, required this.onTap});

  IconData _getCategoryIcon() {
    switch (label.toLowerCase()) {
      case 'bakery':                       return Icons.bakery_dining;
      case 'meat':                         return Icons.set_meal;
      case 'dairy':                        return Icons.local_drink;
      case 'fruit & veg':
      case 'fruit and veg':
      case 'vegetables':                   return Icons.eco;
      case 'frozen':                       return Icons.ac_unit;
      case 'dry items':
      case 'dry goods':                    return Icons.grain;
      case 'beverages':
      case 'drinks':                       return Icons.local_cafe;
      case 'more':                         return Icons.apps;
      default:                             return Icons.shopping_basket;
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
            Icon(_getCategoryIcon(), size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
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
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  SUPPLIER CARD
// ══════════════════════════════════════════════════════════
class _SupplierCard extends StatelessWidget {
  final String       name;
  final String       distance;
  final double       rating;
  final String       products;
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
            // Image placeholder
            Container(
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.store, size: 50, color: AppColors.primary),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on,
                          size: 16, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(distance,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$products Products',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
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

// ══════════════════════════════════════════════════════════
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════
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
    final n = name.toLowerCase();
    if (n.contains('tomato') || n.contains('carrot') || n.contains('veg')) {
      return Icons.eco;
    }
    if (n.contains('chicken') || n.contains('meat') || n.contains('beef')) {
      return Icons.set_meal;
    }
    if (n.contains('milk') || n.contains('cheese') || n.contains('dairy')) {
      return Icons.local_drink;
    }
    if (n.contains('bread') || n.contains('bakery')) {
      return Icons.bakery_dining;
    }
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
          // Image placeholder
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            alignment: Alignment.center,
            child: Icon(_getProductIcon(),
                size: 60, color: AppColors.primary),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(supplier,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('£${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.white, size: 18),
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