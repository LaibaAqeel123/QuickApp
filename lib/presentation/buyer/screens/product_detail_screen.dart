import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/supplier_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  /// Pass the product map from the listing screen.
  final Map<String, dynamic> product;

  /// Called when the user taps "VIEW CART" in the snackbar.
  /// Typically: () => Navigator.pop(context) then switchTab(2)
  /// Pass this from wherever you push ProductDetailScreen.
  final VoidCallback? onViewCart;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.onViewCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // ── State ──────────────────────────────────────────────
  late Map<String, dynamic> _product;
  bool    _isLoadingDetail = false;
  bool    _isAddingToCart  = false;
  int     _quantity        = 1;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _fetchFullDetail();
  }

  // ── Safe field helpers ─────────────────────────────────
  String get _productId =>
      (_product['id'] ?? _product['productId'] ?? '').toString();

  String get _name =>
      (_product['name'] ?? _product['productName'] ?? 'Product').toString();

  String get _category =>
      (_product['category'] ?? _product['categoryName'] ??
              _product['category']?['name'] ?? '')
          .toString();

  String get _description =>
      (_product['description'] ?? _product['details'] ?? '').toString();

  double get _price =>
      ((_product['price'] ?? _product['unitPrice'] ?? _product['basePrice'] ?? 0)
              as num)
          .toDouble();

  String get _unit =>
      (_product['unit'] ?? _product['unitOfMeasure'] ?? 'unit').toString();

  int get _stock =>
      ((_product['stock'] ?? _product['stockQuantity'] ??
                  _product['availableStock'] ?? 0)
              as num)
          .toInt();

  double get _rating =>
      ((_product['rating'] ?? _product['averageRating'] ?? 0) as num)
          .toDouble();

  String get _supplierName =>
      (_product['supplierName'] ?? _product['supplier']?['name'] ??
              _product['supplier'] ?? '')
          .toString();

  double get _supplierRating =>
      ((_product['supplier']?['rating'] ??
                  _product['supplierRating'] ?? 4.8)
              as num)
          .toDouble();

  List<dynamic> get _images =>
      (_product['images'] ?? _product['productImages'] ?? []) as List<dynamic>;

  bool get _inStock => _stock > 0;

  // ══════════════════════════════════════════════════════
  //  FETCH FULL DETAIL
  // ══════════════════════════════════════════════════════
  Future<void> _fetchFullDetail() async {
    if (_productId.isEmpty) return;

    setState(() { _isLoadingDetail = true; _detailError = null; });

    final result =
        await AuthService.instance.getCatalogProductById(_productId);

    if (!mounted) return;

    if (result.success && result.data != null && result.data!.isNotEmpty) {
      setState(() {
        _product = {..._product, ...result.data!};
        _isLoadingDetail = false;
      });
    } else {
      setState(() {
        _isLoadingDetail = false;
        _detailError = result.message;
      });
    }
  }

  // ══════════════════════════════════════════════════════
  //  ADD TO CART
  // ══════════════════════════════════════════════════════
  Future<void> _addToCart() async {
    if (_productId.isEmpty) {
      _showSnackBar('Cannot add — missing product ID.', isError: true);
      return;
    }
    if (!_inStock) {
      _showSnackBar('This product is currently out of stock.', isError: true);
      return;
    }

    setState(() => _isAddingToCart = true);

    final result = await AuthService.instance.addCartItem(
      productId: _productId,
      quantity:  _quantity,
    );

    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    if (result.success) {
      // ── Dismiss any existing snackbar first so it never stacks/persists ──
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_name x$_quantity added to cart!'),
          backgroundColor: AppColors.success,
          // Auto-dismiss after 3 seconds
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: AppColors.white,
            onPressed: () {
              // Dismiss the snackbar immediately
              ScaffoldMessenger.of(context).hideCurrentSnackBar();

              if (widget.onViewCart != null) {
                // Use the provided callback (navigates to Cart tab)
                widget.onViewCart!();
              } else {
                // Fallback: just pop this screen
                if (Navigator.canPop(context)) Navigator.pop(context);
              }
            },
          ),
        ),
      );
    } else {
      _showSnackBar(result.message ?? 'Failed to add to cart.', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ICON HELPER
  // ══════════════════════════════════════════════════════
  IconData _categoryIcon([String? cat]) {
    final n = (cat ?? _category).toLowerCase();
    if (n.contains('bakery'))                        return Icons.bakery_dining;
    if (n.contains('meat'))                          return Icons.set_meal;
    if (n.contains('dairy'))                         return Icons.local_drink;
    if (n.contains('fruit') || n.contains('veg'))   return Icons.eco;
    if (n.contains('frozen'))                        return Icons.ac_unit;
    if (n.contains('dry'))                           return Icons.grain;
    if (n.contains('bev') || n.contains('drink'))   return Icons.local_cafe;
    return Icons.shopping_basket;
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share),           onPressed: () {}),
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Product Image ──────────────────────
                Stack(
                  children: [
                    Container(
                      height: 300,
                      color: AppColors.surfaceLight,
                      alignment: Alignment.center,
                      child: _isLoadingDetail
                          ? const CircularProgressIndicator()
                          : Icon(_categoryIcon(), size: 150,
                              color: AppColors.primary),
                    ),
                    if (!_inStock && !_isLoadingDetail)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.45),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('OUT OF STOCK',
                                style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── API detail error (subtle) ────
                      if (_detailError != null && !_isLoadingDetail)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Showing cached product info.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.warning),
                              ),
                            ),
                            GestureDetector(
                              onTap: _fetchFullDetail,
                              child: const Text('Retry',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),

                      // ── Category badge ───────────────
                      if (_category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_categoryIcon(), size: 16,
                                  color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(_category,
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ── Name ────────────────────────
                      Text(_name,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),

                      // ── Price + Rating row ───────────
                      Row(
                        children: [
                          Text('£${_price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          Text(' / $_unit',
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          if (_rating > 0) ...[
                            const Icon(Icons.star,
                                size: 20, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(_rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Supplier card ─────────────────
                      if (_supplierName.isNotEmpty)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierDetailScreen(
                                  supplierName: _supplierName),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.store,
                                      color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Sold by',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(_supplierName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.star,
                                            size: 14,
                                            color: AppColors.warning),
                                        const SizedBox(width: 4),
                                        Text(
                                            _supplierRating.toStringAsFixed(1),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                      ]),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 16, color: AppColors.textHint),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ── Stock status ──────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (_inStock ? AppColors.success : AppColors.error)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: (_inStock
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(
                            _inStock ? Icons.check_circle : Icons.cancel,
                            color:
                                _inStock ? AppColors.success : AppColors.error,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _inStock ? 'In Stock' : 'Out of Stock',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _inStock
                                        ? AppColors.success
                                        : AppColors.error),
                              ),
                              if (_inStock)
                                Text('$_stock $_unit available',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // ── Description ───────────────────
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        _description.isNotEmpty
                            ? _description
                            : 'Premium quality product sourced from trusted '
                                'suppliers. Fresh and delivered on time with '
                                'proper handling.',
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // ── Features ──────────────────────
                      const Text('Product Features',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _FeatureItem(
                          icon: Icons.verified,
                          title: 'Quality Assured',
                          subtitle: 'Certified and inspected'),
                      _FeatureItem(
                          icon: Icons.local_shipping,
                          title: 'Fast Delivery',
                          subtitle: 'Same day delivery available'),
                      _FeatureItem(
                          icon: Icons.ac_unit,
                          title: 'Proper Storage',
                          subtitle: 'Temperature controlled'),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Loading overlay while fetching detail ──
          if (_isLoadingDetail)
            Positioned(
              top: 300,
              left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.surface.withOpacity(0.85),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Loading full details...',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),

      // ── Bottom bar: quantity + add to cart ─────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              // Quantity selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: const Icon(Icons.remove),
                      color: AppColors.textPrimary,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_quantity',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Add to cart button
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isAddingToCart || !_inStock || _isLoadingDetail)
                            ? null
                            : _addToCart,
                    icon: _isAddingToCart
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2.5))
                        : const Icon(Icons.shopping_cart),
                    label: Text(
                      _isAddingToCart
                          ? 'Adding...'
                          : !_inStock
                              ? 'Out of Stock'
                              : 'Add to Cart  —  £${(_price * _quantity).toStringAsFixed(2)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _inStock ? AppColors.primary : AppColors.border,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FEATURE ITEM
// ══════════════════════════════════════════════════════════════
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}