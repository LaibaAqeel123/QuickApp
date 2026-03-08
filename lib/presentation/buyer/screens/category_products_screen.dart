import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
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
  // ── Products state ─────────────────────────────────────
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>?      _categoryInfo;
  bool    _isLoading    = true;
  bool    _isLoadingMore = false;
  String? _error;

  // ── Pagination ─────────────────────────────────────────
  int  _currentPage = 1;
  int  _totalItems  = 0;
  bool _hasMore     = false;
  static const int _pageSize = 10;

  // ── Search ─────────────────────────────────────────────
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Filters (from /api/catalog/filters) ───────────────
  Map<String, dynamic>? _filtersData;
  double  _minPrice   = 0;
  double  _maxPrice   = 1000;
  double  _selectedMinPrice = 0;
  double  _selectedMaxPrice = 1000;
  double? _minRating;

  // ── Sort ───────────────────────────────────────────────
  String _sortBy = 'default'; // default, price_asc, price_desc, rating

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD FILTERS — GET /api/catalog/filters
  // ══════════════════════════════════════════════════════
  Future<void> _loadFilters() async {
    final result = await AuthService.instance.getCatalogFilters();
    if (!mounted || !result.success || result.data == null) return;

    final data = result.data!;
    setState(() {
      _filtersData = data;
      // Extract price range from filters if available
      final min = (data['minPrice'] ?? data['priceRange']?['min'] ?? 0);
      final max = (data['maxPrice'] ?? data['priceRange']?['max'] ?? 1000);
      _minPrice         = (min as num).toDouble();
      _maxPrice         = (max as num).toDouble();
      _selectedMinPrice = _minPrice;
      _selectedMaxPrice = _maxPrice;
    });
  }

  // ══════════════════════════════════════════════════════
  //  LOAD PRODUCTS — GET /api/catalog/products
  // ══════════════════════════════════════════════════════
  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading    = true;
        _error        = null;
        _currentPage  = 1;
        _products     = [];
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final result = await AuthService.instance.getCatalogProducts(
      categoryId: widget.categoryId,
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

      // Extract items — handle multiple possible response shapes
      List<dynamic> rawItems = [];
      if (data['items'] is List)    rawItems = data['items'];
      else if (data['data'] is List) rawItems = data['data'];
      else if (data['products'] is List) rawItems = data['products'];
      else if (data['results'] is List)  rawItems = data['results'];

      // Apply client-side sort if needed
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .toList();
      _applySort(items);

      // Total count for pagination
      final total = (data['total'] ?? data['totalCount'] ??
              data['totalItems'] ?? rawItems.length) as num;

      setState(() {
        if (reset) {
          _products = items;
        } else {
          _products.addAll(items);
        }
        _totalItems  = total.toInt();
        _hasMore     = _products.length < _totalItems;
        _isLoading   = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoading   = false;
        _isLoadingMore = false;
        _error = result.message ?? 'Failed to load products.';
      });
    }
  }

  void _applySort(List<Map<String, dynamic>> items) {
    switch (_sortBy) {
      case 'price_asc':
        items.sort((a, b) => _price(a).compareTo(_price(b)));
        break;
      case 'price_desc':
        items.sort((a, b) => _price(b).compareTo(_price(a)));
        break;
      case 'rating':
        items.sort((a, b) => _rating(b).compareTo(_rating(a)));
        break;
    }
  }

  // ══════════════════════════════════════════════════════
  //  ADD TO CART — POST /api/cart/items
  // ══════════════════════════════════════════════════════
  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = _productId(product);
    if (productId.isEmpty) {
      _showSnackBar('Cannot add — missing product ID.', isError: true);
      return;
    }

    final result = await AuthService.instance.addCartItem(
      productId: productId,
      quantity:  1,
    );

    if (!mounted) return;

    if (result.success) {
      _showSnackBar('${_name(product)} added to cart!');
    } else {
      _showSnackBar(result.message ?? 'Failed to add to cart.', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  SEARCH
  // ══════════════════════════════════════════════════════
  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    // Debounce — wait briefly then reload
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value.trim() && mounted) {
        _loadProducts(reset: true);
      }
    });
  }

  // ══════════════════════════════════════════════════════
  //  FILTER BOTTOM SHEET
  // ══════════════════════════════════════════════════════
  void _openFilters() {
    double tempMin    = _selectedMinPrice;
    double tempMax    = _selectedMaxPrice;
    double? tempRating = _minRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Products',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        tempMin    = _minPrice;
                        tempMax    = _maxPrice;
                        tempRating = null;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Price range
              const Text('Price Range',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('£${tempMin.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Text('£${tempMax.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
              RangeSlider(
                values:   RangeValues(tempMin, tempMax),
                min:      _minPrice,
                max:      _maxPrice,
                divisions: 20,
                activeColor: AppColors.primary,
                onChanged: (v) => setModalState(() {
                  tempMin = v.start;
                  tempMax = v.end;
                }),
              ),
              const SizedBox(height: 20),

              // Min rating
              const Text('Minimum Rating',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [null, 3.0, 3.5, 4.0, 4.5].map((r) {
                  final isSelected = tempRating == r;
                  final label = r == null ? 'Any' : '${r}★+';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setModalState(() => tempRating = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Apply
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

  // ══════════════════════════════════════════════════════
  //  SORT BOTTOM SHEET
  // ══════════════════════════════════════════════════════
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Sort By',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            ...[
              ('default',    'Default',           Icons.sort),
              ('price_asc',  'Price: Low to High', Icons.arrow_upward),
              ('price_desc', 'Price: High to Low', Icons.arrow_downward),
              ('rating',     'Highest Rated',      Icons.star),
            ].map((opt) {
              final isSelected = _sortBy == opt.$1;
              return ListTile(
                leading: Icon(opt.$3,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary),
                title: Text(opt.$2,
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = opt.$1);
                  Navigator.pop(context);
                  _loadProducts(reset: true);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  LOAD MORE (pagination)
  // ══════════════════════════════════════════════════════
  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    _currentPage++;
    _loadProducts();
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════
  String _productId(Map<String, dynamic> p) =>
      (p['id'] ?? p['productId'] ?? '').toString();

  String _name(Map<String, dynamic> p) =>
      (p['name'] ?? p['productName'] ?? 'Product').toString();

  String _supplierName(Map<String, dynamic> p) =>
      (p['supplierName'] ?? p['supplier']?['name'] ??
              p['supplier'] ?? '')
          .toString();

  double _price(Map<String, dynamic> p) =>
      ((p['price'] ?? p['unitPrice'] ?? p['basePrice'] ?? 0) as num)
          .toDouble();

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration:        const Duration(seconds: 2),
      ),
    );
  }

  String get _displayName =>
      (_categoryInfo?['name'] ?? widget.category).toString();

  IconData _categoryIcon([String? cat]) {
    final n = (cat ?? widget.category).toLowerCase();
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
  //  BUILD
  // ══════════════════════════════════════════════════════
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
          // Sort button
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Sort',
            onPressed: _openSort,
          ),
          // Filter button — badge shows when filters are active
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filter',
                onPressed: _openFilters,
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category header ───────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Icon(_categoryIcon(), size: 40, color: AppColors.primary),
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
                        _isLoading
                            ? 'Loading...'
                            : '$_totalItems product${_totalItems == 1 ? '' : 's'} found',
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

          // ── Search bar ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged:  _onSearchChanged,
              decoration: InputDecoration(
                hintText:    'Search in $_displayName...',
                hintStyle:   const TextStyle(color: AppColors.textHint),
                prefixIcon:  const Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled:      true,
                fillColor:   AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Active filter chips ───────────────────────
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedMinPrice > _minPrice ||
                        _selectedMaxPrice < _maxPrice)
                      _FilterChip(
                        label:
                            '£${_selectedMinPrice.toStringAsFixed(0)} – £${_selectedMaxPrice.toStringAsFixed(0)}',
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
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Products grid ─────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(
                        message: _error!, onRetry: () => _loadProducts(reset: true))
                    : _products.isEmpty
                        ? _EmptyView(
                            hasFilters: _hasActiveFilters ||
                                _searchQuery.isNotEmpty,
                            onClear: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery      = '';
                                _selectedMinPrice = _minPrice;
                                _selectedMaxPrice = _maxPrice;
                                _minRating        = null;
                              });
                              _loadProducts(reset: true);
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadProducts(reset: true),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 16),
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
                                // Load more trigger
                                if (index == _products.length) {
                                  _loadMore();
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
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
                                      builder: (_) => ProductDetailScreen(
                                          product: product),
                                    ),
                                  ),
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
//  FILTER CHIP
// ══════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String       label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final IconData     icon;
  final String       name;
  final String       supplier;
  final double       price;
  final int          stock;
  final String       unit;
  final double       rating;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.icon,
    required this.name,
    required this.supplier,
    required this.price,
    required this.stock,
    required this.unit,
    required this.rating,
    required this.onTap,
    required this.onAddToCart,
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
            // ── Image placeholder ──────────────────────
            Stack(
              children: [
                Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, size: 55, color: AppColors.primary),
                ),
                // Stock badge
                if (widget.stock > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('In Stock',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white)),
                    ),
                  )
                else
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Out of Stock',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white)),
                    ),
                  ),
              ],
            ),

            // ── Info ──────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),

                    if (widget.supplier.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.store,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(widget.supplier,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),

                    if (widget.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.star,
                            size: 12, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(widget.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                    ],

                    const Spacer(),

                    // Price + Add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('£${widget.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            Text('per ${widget.unit}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint)),
                          ],
                        ),
                        GestureDetector(
                          onTap: widget.stock > 0 ? _handleAdd : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.stock > 0
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _isAdding
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: AppColors.white,
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_shopping_cart,
                                    color: AppColors.white, size: 16),
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

// ══════════════════════════════════════════════════════════
//  EMPTY VIEW
// ══════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final bool         hasFilters;
  final VoidCallback onClear;
  const _EmptyView({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters
                  ? Icons.filter_list_off
                  : Icons.inventory_2_outlined,
              size: 64, color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No products match your filters'
                  : 'No products available',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters.'
                  : 'Check back later for new products.',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onClear,
                icon:  const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String       message;
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