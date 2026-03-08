import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String category;
  /// The integer categoryId from the API — MUST be non-null for correct filtering.
  /// If null, ALL products will be returned (no category filter applied).
  final int? categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.categoryId,
  });

  @override
  State<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Map<String, dynamic>> _products       = [];
  Map<String, dynamic>?      _categoryInfo;
  bool    _isLoading     = true;
  bool    _isLoadingMore = false;
  String? _error;

  int  _currentPage = 1;
  int  _totalItems  = 0;
  bool _hasMore     = false;
  static const int _pageSize = 10;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  double  _minPrice         = 0;
  double  _maxPrice         = 1000;
  double  _selectedMinPrice = 0;
  double  _selectedMaxPrice = 1000;
  double? _minRating;

  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    // Guard: warn loudly in debug if categoryId is missing
    assert(
      widget.categoryId != null,
      '[CategoryProductsScreen] categoryId is NULL for "${widget.category}". '
      'Products will NOT be filtered to this category. '
      'Fix: ensure _extractCategoryId() in BuyerHomeScreen returns a valid int.',
    );
    _loadFilters();
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final result = await AuthService.instance.getCatalogFilters();
    if (!mounted || !result.success || result.data == null) return;
    final data = result.data!;
    final min  = (data['minPrice'] ?? data['priceRange']?['min'] ?? 0);
    final max  = (data['maxPrice'] ?? data['priceRange']?['max'] ?? 1000);
    setState(() {
      _minPrice         = (min as num).toDouble();
      _maxPrice         = (max as num).toDouble();
      _selectedMinPrice = _minPrice;
      _selectedMaxPrice = _maxPrice;
    });
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading   = true;
        _error       = null;
        _currentPage = 1;
        _products    = [];
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    // ── THE CRITICAL CALL ─────────────────────────────────
    // widget.categoryId is passed directly. If it's null (bug in caller),
    // the API returns all products — which is the symptom you reported.
    // The assert above catches this in debug mode.
    final result = await AuthService.instance.getCatalogProducts(
      categoryId: widget.categoryId,          // ← filters to this category
      search:     _searchQuery.isEmpty ? null : _searchQuery,
      minPrice:   _selectedMinPrice > _minPrice ? _selectedMinPrice : null,
      maxPrice:   _selectedMaxPrice < _maxPrice ? _selectedMaxPrice : null,
      minRating:  _minRating,
      page:       _currentPage,
      pageSize:   _pageSize,
    );

    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;

      List<dynamic> rawItems = [];
      if      (data['items']    is List) rawItems = data['items'];
      else if (data['data']     is List) rawItems = data['data'];
      else if (data['products'] is List) rawItems = data['products'];
      else if (data['results']  is List) rawItems = data['results'];

      final items = rawItems.whereType<Map<String, dynamic>>().toList();
      _applySort(items);

      final total = (data['total'] ?? data['totalCount'] ??
          data['totalItems'] ?? rawItems.length) as num;

      setState(() {
        if (reset) _products = items; else _products.addAll(items);
        _totalItems    = total.toInt();
        _hasMore       = _products.length < _totalItems;
        _isLoading     = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoading     = false;
        _isLoadingMore = false;
        _error         = result.message ?? 'Failed to load products.';
      });
    }
  }

  void _applySort(List<Map<String, dynamic>> items) {
    switch (_sortBy) {
      case 'price_asc':  items.sort((a, b) => _price(a).compareTo(_price(b))); break;
      case 'price_desc': items.sort((a, b) => _price(b).compareTo(_price(a))); break;
      case 'rating':     items.sort((a, b) => _rating(b).compareTo(_rating(a))); break;
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = _productId(product);
    if (productId.isEmpty) {
      _showSnackBar('Cannot add — missing product ID.', isError: true);
      return;
    }
    final result = await AuthService.instance.addCartItem(
        productId: productId, quantity: 1);
    if (!mounted) return;
    if (result.success) {
      _showSnackBar('${_name(product)} added to cart!');
    } else {
      _showSnackBar(result.message ?? 'Failed to add to cart.', isError: true);
    }
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value.trim() && mounted) _loadProducts(reset: true);
    });
  }

  void _openFilters() {
    double  tempMin    = _selectedMinPrice;
    double  tempMax    = _selectedMaxPrice;
    double? tempRating = _minRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              )),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Filter Products', style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                TextButton(
                  onPressed: () => setM(() {
                    tempMin    = _minPrice;
                    tempMax    = _maxPrice;
                    tempRating = null;
                  }),
                  child: const Text('Reset'),
                ),
              ]),
              const SizedBox(height: 20),
              const Text('Price Range', style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('£${tempMin.toStringAsFixed(0)}', style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                Text('£${tempMax.toStringAsFixed(0)}', style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
              RangeSlider(
                values: RangeValues(tempMin, tempMax),
                min: _minPrice, max: _maxPrice, divisions: 20,
                activeColor: AppColors.primary,
                onChanged: (v) => setM(() { tempMin = v.start; tempMax = v.end; }),
              ),
              const SizedBox(height: 20),
              const Text('Minimum Rating', style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(children: [null, 3.0, 3.5, 4.0, 4.5].map((r) {
                final sel   = tempRating == r;
                final label = r == null ? 'Any' : '${r}★+';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setM(() => tempRating = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(label, style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? AppColors.white : AppColors.textPrimary)),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMinPrice = tempMin;
                      _selectedMaxPrice = tempMax;
                      _minRating        = tempRating;
                    });
                    Navigator.pop(context);
                    _loadProducts(reset: true);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          )),
          const Text('Sort By', style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...[
            ('default',    'Default',            Icons.sort),
            ('price_asc',  'Price: Low to High', Icons.arrow_upward),
            ('price_desc', 'Price: High to Low', Icons.arrow_downward),
            ('rating',     'Highest Rated',      Icons.star),
          ].map((opt) {
            final sel = _sortBy == opt.$1;
            return ListTile(
              leading: Icon(opt.$3,
                  color: sel ? AppColors.primary : AppColors.textSecondary),
              title: Text(opt.$2, style: TextStyle(
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  color: sel ? AppColors.primary : AppColors.textPrimary)),
              trailing: sel
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _sortBy = opt.$1);
                Navigator.pop(context);
                _loadProducts(reset: true);
              },
            );
          }),
        ]),
      ),
    );
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    _currentPage++;
    _loadProducts();
  }

  // ── Field helpers ──────────────────────────────────────
  String _productId(Map<String, dynamic> p) =>
      (p['id'] ?? p['productId'] ?? '').toString();

  String _name(Map<String, dynamic> p) =>
      (p['name'] ?? p['productName'] ?? 'Product').toString();

  String _supplierName(Map<String, dynamic> p) =>
      (p['supplierName'] ?? p['supplier']?['name'] ?? p['supplier'] ?? '')
          .toString();

  double _price(Map<String, dynamic> p) =>
      ((p['price'] ?? p['unitPrice'] ?? p['basePrice'] ?? 0) as num).toDouble();

  double _rating(Map<String, dynamic> p) =>
      ((p['rating'] ?? p['averageRating'] ?? 0) as num).toDouble();

  int _stock(Map<String, dynamic> p) =>
      ((p['stock'] ?? p['stockQuantity'] ?? p['availableStock'] ?? 0) as num)
          .toInt();

  String _unit(Map<String, dynamic> p) =>
      (p['unit'] ?? p['unitOfMeasure'] ?? 'unit').toString();

  bool get _hasActiveFilters =>
      _selectedMinPrice > _minPrice ||
      _selectedMaxPrice < _maxPrice ||
      _minRating != null;

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration:        const Duration(seconds: 2),
    ));
  }

  String get _displayName =>
      (_categoryInfo?['name'] ?? widget.category).toString();

  IconData _categoryIcon() {
    final n = widget.category.toLowerCase();
    if (n.contains('bakery'))                        return Icons.bakery_dining;
    if (n.contains('meat'))                          return Icons.set_meal;
    if (n.contains('dairy'))                         return Icons.local_drink;
    if (n.contains('fruit') || n.contains('veg'))   return Icons.eco;
    if (n.contains('frozen'))                        return Icons.ac_unit;
    if (n.contains('dry'))                           return Icons.grain;
    if (n.contains('bev') || n.contains('drink'))   return Icons.local_cafe;
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
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Sort', onPressed: _openSort,
          ),
          Stack(alignment: Alignment.topRight, children: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filter', onPressed: _openFilters,
            ),
            if (_hasActiveFilters) Positioned(
              top: 8, right: 8,
              child: Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle)),
            ),
          ]),
        ],
      ),
      body: Column(children: [

        // Category header — shows warning banner if ID is missing
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_categoryIcon(), size: 40, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayName, style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '$_totalItems product${_totalItems == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              )),
            ]),
            // ── Debug banner: shown only when categoryId is null ──
            if (widget.categoryId == null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(children: const [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    'Category ID missing — showing all products. '
                    'Please report this to the dev team.',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  )),
                ]),
              ),
          ]),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged:  _onSearchChanged,
            decoration: InputDecoration(
              hintText:   'Search in $_displayName...',
              hintStyle:  const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textHint),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      })
                  : null,
              filled:     true, fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),

        // Active filter chips
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (_selectedMinPrice > _minPrice || _selectedMaxPrice < _maxPrice)
                  _FilterChip(
                    label: '£${_selectedMinPrice.toStringAsFixed(0)} – '
                           '£${_selectedMaxPrice.toStringAsFixed(0)}',
                    onRemove: () {
                      setState(() {
                        _selectedMinPrice = _minPrice;
                        _selectedMaxPrice = _maxPrice;
                      });
                      _loadProducts(reset: true);
                    },
                  ),
                if (_minRating != null)
                  _FilterChip(
                    label: '${_minRating}★+',
                    onRemove: () {
                      setState(() => _minRating = null);
                      _loadProducts(reset: true);
                    },
                  ),
              ]),
            ),
          ),

        const SizedBox(height: 8),

        // Products grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(
                      message: _error!,
                      onRetry: () => _loadProducts(reset: true))
                  : _products.isEmpty
                      ? _EmptyView(
                          hasFilters:
                              _hasActiveFilters || _searchQuery.isNotEmpty,
                          onClear: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery      = '';
                              _selectedMinPrice = _minPrice;
                              _selectedMaxPrice = _maxPrice;
                              _minRating        = null;
                            });
                            _loadProducts(reset: true);
                          })
                      : RefreshIndicator(
                          onRefresh: () => _loadProducts(reset: true),
                          child: GridView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:   2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing:  12,
                              childAspectRatio: 0.62,
                            ),
                            itemCount:
                                _products.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _products.length) {
                                _loadMore();
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator()));
                              }
                              final product = _products[index];
                              return _ProductCard(
                                product:    product,
                                icon:       _categoryIcon(),
                                name:       _name(product),
                                supplier:   _supplierName(product),
                                price:      _price(product),
                                stock:      _stock(product),
                                unit:       _unit(product),
                                rating:     _rating(product),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailScreen(product: product),
                                  ),
                                ),
                                onAddToCart: () => _addToCart(product),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FILTER CHIP
// ══════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: AppColors.primary)),
      const SizedBox(width: 6),
      GestureDetector(onTap: onRemove,
          child: const Icon(Icons.close, size: 14, color: AppColors.primary)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final IconData     icon;
  final String       name, supplier, unit;
  final double       price, rating;
  final int          stock;
  final VoidCallback onTap, onAddToCart;

  const _ProductCard({
    required this.product, required this.icon,
    required this.name,    required this.supplier,
    required this.price,   required this.stock,
    required this.unit,    required this.rating,
    required this.onTap,   required this.onAddToCart,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isAdding = false;

  Future<void> _handleAdd() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    widget.onAddToCart();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = (widget.product['imageUrl'] ?? widget.product['image'])
        ?.toString();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(
              height: 110,
              decoration: const BoxDecoration(color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              alignment: Alignment.center,
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Image.network(imgUrl, fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity,
                        errorBuilder: (_, __, ___) => Icon(
                            widget.icon, size: 55, color: AppColors.primary)),
                    )
                  : Icon(widget.icon, size: 55, color: AppColors.primary),
            ),
            Positioned(top: 8, right: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: widget.stock > 0
                    ? AppColors.success.withOpacity(0.9)
                    : AppColors.error.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.stock > 0 ? 'In Stock' : 'Out of Stock',
                style: const TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: AppColors.white),
              ),
            )),
          ]),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.name, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (widget.supplier.isNotEmpty)
                Row(children: [
                  const Icon(Icons.store, size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Expanded(child: Text(widget.supplier, style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              if (widget.rating > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star, size: 12, color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(widget.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ]),
              ],
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('£${widget.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('per ${widget.unit}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ]),
                GestureDetector(
                  onTap: widget.stock > 0 ? _handleAdd : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.stock > 0
                          ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isAdding
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2))
                        : const Icon(Icons.add_shopping_cart,
                            color: AppColors.white, size: 16),
                  ),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EMPTY VIEW
// ══════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyView({required this.hasFilters, required this.onClear});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(hasFilters ? Icons.filter_list_off : Icons.inventory_2_outlined,
            size: 64, color: AppColors.textHint),
        const SizedBox(height: 16),
        Text(
          hasFilters ? 'No products match your filters' : 'No products available',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Try adjusting your search or filters.'
              : 'Check back later for new products.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (hasFilters) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: onClear,
              icon: const Icon(Icons.clear_all), label: const Text('Clear Filters')),
        ],
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 60, color: AppColors.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(
            fontSize: 16, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: onRetry,
            icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]),
    ),
  );
}