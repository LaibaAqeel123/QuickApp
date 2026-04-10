import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/core/widgets/auth_image.dart';
import 'package:food_delivery_app/presentation/buyer/screens/supplier_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
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
  late Map<String, dynamic> _product;
  bool    _isLoadingDetail = false;
  bool    _isAddingToCart  = false;
  int     _quantity        = 1;
  String? _detailError;

  // ── Active image index for the gallery ───────────────
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _fetchFullDetail();
  }

  // ══════════════════════════════════════════════════════
  //  FIELD HELPERS
  // ══════════════════════════════════════════════════════
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
      ((_product['supplier']?['rating'] ?? _product['supplierRating'] ?? 4.8)
              as num)
          .toDouble();

  bool get _inStock => _stock > 0;

  /// Extracts all image URLs from the product data.
  /// The API returns images as a list: [{ "imageUrl": "...", "isPrimary": true, "id": 1 }, ...]
  /// Falls back to top-level imageUrl / image fields.
  List<String> get _imageUrls {
    final List<String> urls = [];

    // 1. Check the images array (from API)
    final images = _product['images'];
    if (images is List && images.isNotEmpty) {
      // Sort so isPrimary comes first
      final sorted = List<Map<String, dynamic>>.from(
        images.whereType<Map<String, dynamic>>(),
      )..sort((a, b) {
          final aP = a['isPrimary'] == true ? 0 : 1;
          final bP = b['isPrimary'] == true ? 0 : 1;
          return aP.compareTo(bP);
        });

      for (final img in sorted) {
        final url = (img['imageUrl'] ?? img['url'] ?? img['path'] ?? '')
            .toString()
            .trim();
        if (url.isNotEmpty) urls.add(url);
      }
    }

    // 2. Fallback: top-level imageUrl or image field
    if (urls.isEmpty) {
      final fallback =
          (_product['imageUrl'] ?? _product['image'])?.toString().trim();
      if (fallback != null && fallback.isNotEmpty) urls.add(fallback);
    }

    return urls;
  }

  /// The single primary image URL (for use in list cards etc.)
  String? get _primaryImageUrl =>
      _imageUrls.isNotEmpty ? _imageUrls.first : null;

  // ══════════════════════════════════════════════════════
  //  FETCH
  // ══════════════════════════════════════════════════════
  Future<void> _fetchFullDetail() async {
    if (_productId.isEmpty) return;
    setState(() { _isLoadingDetail = true; _detailError = null; });
    final result = await AuthService.instance.getCatalogProductById(_productId);
    if (!mounted) return;
    if (result.success && result.data != null && result.data!.isNotEmpty) {
      setState(() {
        _product = {..._product, ...result.data!};
        _isLoadingDetail = false;
        _activeImageIndex = 0; // reset gallery on fresh data
      });
    } else {
      setState(() { _isLoadingDetail = false; _detailError = result.message; });
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
    final result = await AuthService.instance
        .addCartItem(productId: _productId, quantity: _quantity);
    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    if (result.success) {
      _clearAllSnackBars();
      _showAddedToCartDialog();
    } else {
      _showSnackBar(result.message ?? 'Failed to add to cart.', isError: true);
    }
  }

  void _clearAllSnackBars() {
    try { ScaffoldMessenger.of(context).clearSnackBars(); } catch (_) {}
  }

  void _showAddedToCartDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 3), () {
          if (dialogContext.mounted) {
            try { Navigator.of(dialogContext).pop(); } catch (_) {}
          }
        });

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2),
                        blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('$_name x$_quantity added to cart!',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: () {
                      try { Navigator.of(dialogContext).pop(); } catch (_) {}
                      _goToCart();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('VIEW CART',
                          style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  void _goToCart() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onViewCart?.call();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    _clearAllSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

  IconData _categoryIcon([String? cat]) {
    final n = (cat ?? _category).toLowerCase();
    if (n.contains('bakery'))                      return Icons.bakery_dining;
    if (n.contains('meat'))                        return Icons.set_meal;
    if (n.contains('dairy'))                       return Icons.local_drink;
    if (n.contains('fruit') || n.contains('veg')) return Icons.eco;
    if (n.contains('frozen'))                      return Icons.ac_unit;
    if (n.contains('dry'))                         return Icons.grain;
    if (n.contains('bev') || n.contains('drink')) return Icons.local_cafe;
    return Icons.shopping_basket;
  }

  // ══════════════════════════════════════════════════════
  //  IMAGE WIDGET
  // ══════════════════════════════════════════════════════
  Widget _buildImageSection() {
    final imgs = _imageUrls;

    return Stack(children: [
      // ── Main image / placeholder ─────────────────────
      Container(
        height: 300,
        color: AppColors.surfaceLight,
        width: double.infinity,
        child: _isLoadingDetail
            ? const Center(child: CircularProgressIndicator())
            : imgs.isEmpty
                ? Center(
                    child: Icon(_categoryIcon(), size: 150,
                        color: AppColors.primary))
                : AuthImage(
                    url: imgs[_activeImageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: Center(
                      child: Icon(_categoryIcon(), size: 150, color: AppColors.primary),
                    ),
                  ),
      ),

      // ── Out of stock overlay ─────────────────────────
      if (!_inStock && !_isLoadingDetail)
        Positioned.fill(child: Container(
          color: Colors.black.withOpacity(0.45),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8)),
            child: const Text('OUT OF STOCK',
                style: TextStyle(color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18, letterSpacing: 1.5)),
          ),
        )),

      // ── Thumbnail strip (only when >1 image) ─────────
      if (imgs.length > 1)
        Positioned(
          bottom: 12, left: 0, right: 0,
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: imgs.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _activeImageIndex = i),
                child: Container(
                  width: 60, height: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeImageIndex == i
                          ? AppColors.primary : Colors.white,
                      width: _activeImageIndex == i ? 2.5 : 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: AuthImage(
                      url: imgs[i],
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      errorWidget: Container(
                          color: AppColors.surfaceLight,
                          child: Icon(_categoryIcon(), size: 24, color: AppColors.primary)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

      // ── Dot indicators (only when >1 image, no thumbs) ─
      if (imgs.length > 1 && imgs.length <= 3)
        Positioned(
          bottom: 80, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(imgs.length, (i) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeImageIndex == i
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.7),
              ),
            )),
          ),
        ),
    ]);
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
        
      ),
      body: Stack(children: [
        SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

            // ── Image gallery ──────────────────────────
            _buildImageSection(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Error banner
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
                      const Icon(Icons.info_outline, size: 16,
                          color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Showing cached product info.',
                          style: TextStyle(fontSize: 12,
                              color: AppColors.warning))),
                      GestureDetector(
                        onTap: _fetchFullDetail,
                        child: const Text('Retry',
                            style: TextStyle(fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),

                // Category badge
                if (_category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_categoryIcon(), size: 16,
                          color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_category, style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                const SizedBox(height: 16),

                // Name
                Text(_name, style: const TextStyle(fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 8),

                // Price + Rating
                Row(children: [
                  Text('£${_price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  Text(' / $_unit', style: const TextStyle(
                      fontSize: 16, color: AppColors.textSecondary)),
                  const Spacer(),
                  if (_rating > 0) ...[
                    const Icon(Icons.star, size: 20,
                        color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(_rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ]),
                const SizedBox(height: 24),

                // Supplier card
                if (_supplierName.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            SupplierDetailScreen(
                                supplierName: _supplierName))),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
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
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Sold by', style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(_supplierName, style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.star, size: 14,
                                color: AppColors.warning),
                            const SizedBox(width: 4),
                            Text(_supplierRating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ]),
                        ])),
                        const Icon(Icons.arrow_forward_ios, size: 16,
                            color: AppColors.textHint),
                      ]),
                    ),
                  ),
                const SizedBox(height: 24),

               
                
              ]),
            ),
          ]),
        ),

        // ── Loading overlay ────────────────────────────
        if (_isLoadingDetail)
          Positioned(
            top: 300, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppColors.surface.withOpacity(0.85),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Loading full details...',
                      style: TextStyle(fontSize: 13,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
      ]),

      // ── Bottom bar ─────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                  color: AppColors.textPrimary,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_quantity', style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add),
                  color: AppColors.textPrimary,
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isAddingToCart || !_inStock ||
                          _isLoadingDetail)
                      ? null : _addToCart,
                  icon: _isAddingToCart
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2.5))
                      : const Icon(Icons.shopping_cart),
                  label: Text(
                    _isAddingToCart ? 'Adding...'
                        : !_inStock   ? 'Out of Stock'
                        : 'Add to Cart  —  '
                          '£${(_price * _quantity).toStringAsFixed(2)}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inStock
                        ? AppColors.primary : AppColors.border,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FEATURE ITEM
// ══════════════════════════════════════════════════════════
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _FeatureItem(
      {required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 13,
                color: AppColors.textSecondary)),
          ])),
        ]),
      );
}