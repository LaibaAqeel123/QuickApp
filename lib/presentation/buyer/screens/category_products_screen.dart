import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  /// Category name is used for display; categoryId is used for API calls.
  /// Pass categoryId as null if only a name is available (will do name-based
  /// filtering from the categories list instead).
  final String category;
  final int?   categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.categoryId,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Map<String, dynamic>> _products    = [];
  Map<String, dynamic>?      _categoryInfo;
  bool   _isLoading   = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  // ── Load category detail then its products ─────────────
  Future<void> _loadCategoryData() async {
    setState(() { _isLoading = true; _error = null; });

    // If we have a category ID, fetch its detail from the API
    if (widget.categoryId != null) {
      final catResult =
          await AuthService.instance.getCategoryById(widget.categoryId!);

      if (!mounted) return;

      if (catResult.success && catResult.data != null) {
        setState(() => _categoryInfo = catResult.data);
      }
    }

    // Load products for this category.
    // NOTE: The provided API spec only has a categories endpoint, not a
    // /products endpoint. Uncomment and wire up a products API call here when
    // you add product endpoints. For now we use the existing mock product list
    // that was already in the original screen, filtered by category name.
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    // TODO: Replace with real products API call when available.
    // Example:
    //   final result = await AuthService.instance.getProducts(
    //       categoryId: widget.categoryId);
    //   if (result.success) setState(() => _products = result.data);

    // ── Fallback: mock product data filtered by category ──
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final allProducts = <Map<String, dynamic>>[
      {'id': '1', 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'price': 3.50, 'supplier': 'Premium Wholesale', 'stock': 150, 'unit': 'kg'},
      {'id': '2', 'name': 'Chicken Breast', 'category': 'Meat', 'price': 8.99, 'supplier': 'Fresh Meat Co.', 'stock': 75, 'unit': 'kg'},
      {'id': '3', 'name': 'Whole Milk', 'category': 'Dairy', 'price': 1.20, 'supplier': 'Dairy Farm', 'stock': 200, 'unit': 'L'},
      {'id': '4', 'name': 'White Bread', 'category': 'Bakery', 'price': 0.99, 'supplier': "Baker's Best", 'stock': 120, 'unit': 'loaf'},
      {'id': '5', 'name': 'Croissants', 'category': 'Bakery', 'price': 2.50, 'supplier': "Baker's Best", 'stock': 80, 'unit': 'pack'},
      {'id': '6', 'name': 'Beef Steak', 'category': 'Meat', 'price': 15.99, 'supplier': 'Fresh Meat Co.', 'stock': 40, 'unit': 'kg'},
      {'id': '7', 'name': 'Cheddar Cheese', 'category': 'Dairy', 'price': 5.99, 'supplier': 'Dairy Farm', 'stock': 90, 'unit': 'kg'},
      {'id': '8', 'name': 'Carrots', 'category': 'Fruit & Veg', 'price': 2.20, 'supplier': 'Premium Wholesale', 'stock': 180, 'unit': 'kg'},
    ];

    setState(() {
      _products = allProducts
          .where((p) =>
              p['category'].toString().toLowerCase() ==
              widget.category.toLowerCase())
          .toList();
      _isLoading = false;
    });
  }

  // ── Add to Cart via API ─────────────────────────────────
  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    if (productId.isEmpty) {
      _showSnackBar('Cannot add this product — missing ID.', isError: true);
      return;
    }

    final result = await AuthService.instance.addCartItem(
      productId: productId,
      quantity:  1,
    );

    if (!mounted) return;

    if (result.success) {
      _showSnackBar('${product['name']} added to cart!');
    } else {
      _showSnackBar(result.message ?? 'Failed to add to cart.', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 2),
      ),
    );
  }

  // ── Category display helpers ────────────────────────────
  String get _displayName =>
      (_categoryInfo?['name'] ?? widget.category).toString();

  String get _displayDescription =>
      (_categoryInfo?['description'] ?? '').toString();

  IconData _getCategoryIcon([String? cat]) {
    final name = (cat ?? widget.category).toLowerCase();
    if (name.contains('bakery'))           return Icons.bakery_dining;
    if (name.contains('meat'))             return Icons.set_meal;
    if (name.contains('dairy'))            return Icons.local_drink;
    if (name.contains('fruit') || name.contains('veg')) return Icons.eco;
    if (name.contains('frozen'))           return Icons.ac_unit;
    if (name.contains('dry'))              return Icons.grain;
    return Icons.shopping_basket;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_displayName),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadCategoryData)
              : Column(
                  children: [
                    // ── Category Header ──────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.primary.withOpacity(0.1),
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(),
                              size: 40, color: AppColors.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_displayName,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(
                                  _displayDescription.isNotEmpty
                                      ? _displayDescription
                                      : '${_products.length} products available',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Products Grid ────────────────────
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadCategoryData,
                        child: _products.isEmpty
                            ? const Center(
                                child: Text('No products available.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textSecondary)),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:   2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing:  12,
                                  childAspectRatio: 0.65,
                                ),
                                itemCount: _products.length,
                                itemBuilder: (context, index) {
                                  final product = _products[index];
                                  return _ProductCard(
                                    product:    product,
                                    icon:       _getCategoryIcon(
                                        product['category']?.toString()),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailScreen(
                                              product: product),
                                        ),
                                      );
                                    },
                                    onAddToCart: () => _addToCart(product),
                                  );
                                },
                              ),
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
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.icon,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isAdding = false;

  Future<void> _handleAdd() async {
    setState(() => _isAdding = true);
    widget.onAddToCart();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final name    = product['name']?.toString()     ?? 'Product';
    final supplier = product['supplier']?.toString() ?? '';
    final stock   = product['stock'];
    final unit    = product['unit']?.toString()     ?? 'unit';
    final price   = (product['price'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            Container(
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 60, color: AppColors.primary),
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
                    if (supplier.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.store,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(supplier,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    const Spacer(),
                    if (stock != null)
                      Row(children: [
                        const Icon(Icons.check_circle,
                            size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('$stock $unit available',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.success)),
                      ]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('£${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            Text('per $unit',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textHint)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _isAdding ? null : _handleAdd,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isAdding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: AppColors.white,
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_shopping_cart,
                                    color: AppColors.white, size: 18),
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