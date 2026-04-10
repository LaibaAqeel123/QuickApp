import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';
import 'package:food_delivery_app/core/widgets/auth_image.dart';

class BrowseScreen extends StatefulWidget {
  final String? initialSearch;
  final VoidCallback? onViewCart;

  const BrowseScreen({super.key, this.initialSearch, this.onViewCart});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  List<Map<String, dynamic>> _products      = [];
  bool    _isLoading     = false;
  bool    _isLoadingMore = false;
  String? _error;

  int  _page    = 1;
  int  _total   = 0;
  bool _hasMore = false;
  static const int _pageSize = 20;

  double  _minPrice         = 0;
  double  _maxPrice         = 1000;
  double  _selectedMinPrice = 0;
  double  _selectedMaxPrice = 1000;
  double? _minRating;
  int?    _selectedCategoryId;
  String  _selectedCategoryName = '';

  List<Map<String, dynamic>> _categories = [];
  String _sortBy = 'default';

  @override
  void initState() {
    super.initState();
    debugPrint('🛒 [BrowseScreen] initState');
    _searchQuery      = widget.initialSearch?.trim() ?? '';
    _searchController = TextEditingController(text: _searchQuery);
    _loadFiltersAndCategories();
    _loadProducts(reset: true);
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _loadFiltersAndCategories() async {
    debugPrint('🔍 [BrowseScreen] Loading filters and categories...');
    final fr = await AuthService.instance.getCatalogFilters();
    if (mounted && fr.success && fr.data != null) {
      final d   = fr.data!;
      final min = ((d['minPrice'] ?? d['priceRange']?['min'] ?? 0) as num).toDouble();
      final max = ((d['maxPrice'] ?? d['priceRange']?['max'] ?? 1000) as num).toDouble();
      debugPrint('✅ [BrowseScreen] Filters loaded — min: $min, max: $max');
      setState(() {
        _minPrice = min; _maxPrice = max;
        _selectedMinPrice = min; _selectedMaxPrice = max;
      });
    }
    final cr = await AuthService.instance.getCategories();
    if (mounted && cr.success) {
      final cats = (cr.data ?? []).whereType<Map<String, dynamic>>().toList();
      debugPrint('✅ [BrowseScreen] Categories loaded — count: ${cats.length}');
      setState(() { _categories = cats; });
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    debugPrint('📦 [BrowseScreen] _loadProducts(reset: $reset, page: $_page)');
    if (reset) {
      setState(() { _isLoading = true; _error = null; _page = 1; _products = []; });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final result = await AuthService.instance.getCatalogProducts(
      search:     _searchQuery.isEmpty ? null : _searchQuery,
      categoryId: _selectedCategoryId,
      minPrice:   _selectedMinPrice > _minPrice ? _selectedMinPrice : null,
      maxPrice:   _selectedMaxPrice < _maxPrice ? _selectedMaxPrice : null,
      minRating:  _minRating,
      page:       _page,
      pageSize:   _pageSize,
    );

    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;
      List<dynamic> raw = [];
      if      (data['items']    is List) raw = data['items'];
      else if (data['data']     is List) raw = data['data'];
      else if (data['products'] is List) raw = data['products'];
      else if (data['results']  is List) raw = data['results'];
      final items = raw.whereType<Map<String, dynamic>>().toList();
      _applySort(items);
      final total = ((data['total'] ?? data['totalCount'] ??
          data['totalItems'] ?? raw.length) as num).toInt();

      // ── Debug: log image data for first few products ──────────
      debugPrint('✅ [BrowseScreen] Products loaded — count: ${items.length}, total: $total');
      for (int i = 0; i < items.length && i < 3; i++) {
        final p = items[i];
        final name = p['name'] ?? p['productName'] ?? '?';
        final images = p['images'];
        final topLevelUrl = p['imageUrl'] ?? p['image'];
        debugPrint('  📸 Product[$i] "$name":');
        debugPrint('     images field type: ${images.runtimeType}');
        if (images is List) {
          debugPrint('     images count: ${images.length}');
          for (final img in images.take(2)) {
            debugPrint('     img entry: $img');
          }
        }
        debugPrint('     top-level imageUrl: $topLevelUrl');
      }

      setState(() {
        if (reset) _products = items; else _products.addAll(items);
        _total = total;
        _hasMore = _products.length < _total;
        _isLoading = false; _isLoadingMore = false;
      });
    } else {
      debugPrint('❌ [BrowseScreen] Failed to load products: ${result.message}');
      setState(() {
        _isLoading = false; _isLoadingMore = false;
        _error = result.message ?? 'Failed to load products.';
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

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == value.trim() && mounted) _loadProducts(reset: true);
    });
  }

  void _loadMore() {
    if (_isLoadingMore || !_hasMore) return;
    _page++;
    _loadProducts();
  }

  void _openFilters() {
    double  tempMin    = _selectedMinPrice;
    double  tempMax    = _selectedMaxPrice;
    double? tempRating = _minRating;
    int?    tempCatId  = _selectedCategoryId;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setM) => Container(
        decoration: const BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Filters', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              TextButton(
                onPressed: () => setM(() {
                  tempMin = _minPrice; tempMax = _maxPrice;
                  tempRating = null; tempCatId = null;
                }),
                child: const Text('Reset All'),
              ),
            ]),
            const SizedBox(height: 16),

            if (_categories.isNotEmpty) ...[
              const Text('Category', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _FChip(label: 'All', isSelected: tempCatId == null,
                    onTap: () => setM(() => tempCatId = null)),
                ..._categories.map((cat) {
                  final id = cat['categoryId'] is int
                      ? cat['categoryId'] as int
                      : cat['id'] is int
                          ? cat['id'] as int
                          : int.tryParse(
                                  (cat['id'] ?? cat['categoryId']).toString()) ??
                              0;
                  return _FChip(
                    label: cat['name']?.toString() ?? '',
                    isSelected: tempCatId == id,
                    onTap: () => setM(() => tempCatId = id),
                  );
                }),
              ]),
              const SizedBox(height: 20),
            ],

            const Text('Price Range', style: TextStyle(fontSize: 13,
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
            
            SizedBox(height: 52, child: ElevatedButton(
              onPressed: () {
                String catName = '';
                if (tempCatId != null) {
                  final found = _categories.firstWhere((c) {
                    final id = c['categoryId'] is int
                        ? c['categoryId'] as int
                        : c['id'] is int
                            ? c['id'] as int
                            : int.tryParse(
                                    (c['id'] ?? c['categoryId']).toString()) ??
                                0;
                    return id == tempCatId;
                  }, orElse: () => {});
                  catName = found['name']?.toString() ?? '';
                }
                setState(() {
                  _selectedMinPrice     = tempMin;
                  _selectedMaxPrice     = tempMax;
                  _minRating            = tempRating;
                  _selectedCategoryId   = tempCatId;
                  _selectedCategoryName = catName;
                });
                Navigator.pop(context);
                _loadProducts(reset: true);
              },
              child: const Text('Apply Filters'),
            )),
          ],
        )),
      )),
    );
  }

  void _openSort() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border,
                borderRadius: BorderRadius.circular(2)))),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Sort By', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary))),
          const SizedBox(height: 8),
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

  double _price(Map<String, dynamic> p) =>
      ((p['basePrice'] ?? p['price'] ?? p['unitPrice'] ?? 0) as num).toDouble();

  double _rating(Map<String, dynamic> p) =>
      ((p['rating'] ?? p['averageRating'] ?? 0) as num).toDouble();

  bool get _hasActiveFilters =>
      _selectedMinPrice > _minPrice ||
      _selectedMaxPrice < _maxPrice ||
      _minRating != null ||
      _selectedCategoryId != null;

  void _openProduct(Map<String, dynamic> p) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: p, onViewCart: widget.onViewCart)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Browse Products'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.swap_vert),
              tooltip: 'Sort', onPressed: _openSort),
          Stack(alignment: Alignment.topRight, children: [
            IconButton(icon: const Icon(Icons.tune),
                tooltip: 'Filter', onPressed: _openFilters),
            if (_hasActiveFilters)
              Positioned(top: 8, right: 8,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle))),
          ]),
        ],
      ),
      body: Column(children: [

        // ── Search bar ───────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: TextField(
            controller:  _searchController,
            onChanged:   _onSearchChanged,
            autofocus:   widget.initialSearch != null &&
                         widget.initialSearch!.isNotEmpty,
            decoration: InputDecoration(
              hintText:   'Search products, suppliers...',
              hintStyle:  const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textHint),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      })
                  : null,
              filled: true, fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        // ── Active filter chips ──────────────────────────
        if (_hasActiveFilters)
          Container(
            color: AppColors.surfaceLight,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (_selectedCategoryName.isNotEmpty)
                  _AChip(label: _selectedCategoryName,
                      onRemove: () {
                        setState(() {
                          _selectedCategoryId   = null;
                          _selectedCategoryName = '';
                        });
                        _loadProducts(reset: true);
                      }),
                if (_selectedMinPrice > _minPrice ||
                    _selectedMaxPrice < _maxPrice)
                  _AChip(
                    label:
                        '£${_selectedMinPrice.toStringAsFixed(0)}'
                        '–£${_selectedMaxPrice.toStringAsFixed(0)}',
                    onRemove: () {
                      setState(() {
                        _selectedMinPrice = _minPrice;
                        _selectedMaxPrice = _maxPrice;
                      });
                      _loadProducts(reset: true);
                    },
                  ),
                if (_minRating != null)
                  _AChip(label: '${_minRating}★+',
                      onRemove: () {
                        setState(() => _minRating = null);
                        _loadProducts(reset: true);
                      }),
              ]),
            ),
          ),

        // ── Result count ─────────────────────────────────
        if (!_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: AppColors.surfaceLight,
            width: double.infinity,
            child: Text(
              '$_total product${_total == 1 ? '' : 's'}'
              '${_searchQuery.isNotEmpty
                  ? ' for "$_searchQuery"' : ''}',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ),

        // ── Products grid ─────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrView(message: _error!,
                      onRetry: () => _loadProducts(reset: true))
                  : _products.isEmpty
                      ? _EmptyView(
                          hasFilters: _hasActiveFilters ||
                              _searchQuery.isNotEmpty,
                          onClear: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery          = '';
                              _selectedMinPrice     = _minPrice;
                              _selectedMaxPrice     = _maxPrice;
                              _minRating            = null;
                              _selectedCategoryId   = null;
                              _selectedCategoryName = '';
                            });
                            _loadProducts(reset: true);
                          })
                      : RefreshIndicator(
                          onRefresh: () => _loadProducts(reset: true),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:   2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing:  12,
                              childAspectRatio: 0.62,
                            ),
                            itemCount:
                                _products.length + (_hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _products.length) {
                                _loadMore();
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator()));
                              }
                              return _PCard(
                                product: _products[i],
                                onTap: () => _openProduct(_products[i]),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FILTER CHIP
// ══════════════════════════════════════════════════════════════
class _FChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FChip({required this.label, required this.isSelected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.white : AppColors.textPrimary)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ACTIVE FILTER CHIP
// ══════════════════════════════════════════════════════════════
class _AChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _AChip({required this.label, required this.onRemove});
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
          child: const Icon(Icons.close, size: 14,
              color: AppColors.primary)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ══════════════════════════════════════════════════════════════
class _PCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  const _PCard({required this.product, required this.onTap});

  IconData _icon() {
    final n = (product['category'] ?? product['categoryName'] ?? '')
        .toString().toLowerCase();
    if (n.contains('bakery'))                       return Icons.bakery_dining;
    if (n.contains('meat'))                         return Icons.set_meal;
    if (n.contains('dairy'))                        return Icons.local_drink;
    if (n.contains('fruit') || n.contains('veg'))  return Icons.eco;
    if (n.contains('frozen'))                       return Icons.ac_unit;
    if (n.contains('dry'))                          return Icons.grain;
    if (n.contains('bev') || n.contains('drink'))  return Icons.local_cafe;
    return Icons.shopping_basket;
  }

  String? _primaryImageUrl() {
    final name = product['name'] ?? '?';

    // Check images array first
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final typed = images.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) {
          final aP = a['isPrimary'] == true ? 0 : 1;
          final bP = b['isPrimary'] == true ? 0 : 1;
          return aP.compareTo(bP);
        });
      for (final img in typed) {
        final url = (img['imageUrl'] ?? img['url'] ?? img['path'] ?? '')
            .toString().trim();
        if (url.isNotEmpty) {
          debugPrint('🖼️  [_PCard] "$name" → image from array: $url');
          return url;
        }
      }
    }

    // Fallback to top-level fields
    final fallback = (product['primaryImageUrl'] ?? product['imageUrl'] ?? product['image'])?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('🖼️  [_PCard] "$name" → image from top-level: $fallback');
      return fallback;
    }

    debugPrint('⚠️  [_PCard] "$name" → NO image found. Keys: ${product.keys.toList()}');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name     = (product['name'] ?? 'Product').toString();
    final supplier = (product['supplierName'] ??
                      product['supplier']?['name'] ?? '').toString();
    final price    = ((product['basePrice'] ?? product['price'] ??
                       product['unitPrice'] ?? 0) as num).toDouble();
    final unit     = (product['unit'] ?? 'unit').toString();
    final stock    = ((product['stock'] ??
                       product['stockQuantity'] ?? 0) as num).toInt();
    final rating   = ((product['rating'] ??
                       product['averageRating'] ?? 0) as num).toDouble();
    final imgUrl   = _primaryImageUrl();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          // ── Image area ────────────────────────────────
          Stack(children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: imgUrl != null
                    ? AuthImage(
                        url: imgUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 140,
                        placeholder: Container(
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: AppColors.surfaceLight,
                          child: Center(
                              child: Icon(_icon(), size: 64,
                                  color: AppColors.primary)),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        child: Center(
                            child: Icon(_icon(), size: 64,
                                color: AppColors.primary)),
                      ),
              ),
            ),
            if (stock <= 0)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Out of Stock',
                          style: TextStyle(color: AppColors.white,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
          ]),

          // ── Product info ─────────────────────────────
          Expanded(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (supplier.isNotEmpty)
                Row(children: [
                  const Icon(Icons.store, size: 11,
                      color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(child: Text(supplier,
                      style: const TextStyle(fontSize: 11,
                          color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              if (rating > 0) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.star, size: 12,
                      color: AppColors.warning),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ]),
              ],
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('£${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  Text('per $unit', style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint)),
                ]),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: stock > 0
                        ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_shopping_cart,
                      color: AppColors.white, size: 15),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EMPTY VIEW
// ══════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyView({required this.hasFilters, required this.onClear});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Icon(hasFilters ? Icons.filter_list_off : Icons.search_off,
            size: 80, color: AppColors.textHint),
        const SizedBox(height: 16),
        Text(hasFilters
            ? 'No products match filters' : 'No products found',
            style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(hasFilters
            ? 'Try adjusting your filters or search.'
            : 'Try different keywords.',
            style: const TextStyle(fontSize: 14,
                color: AppColors.textHint),
            textAlign: TextAlign.center),
        if (hasFilters) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All')),
        ],
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════════
class _ErrView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        const Icon(Icons.error_outline, size: 60, color: AppColors.error),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16,
                color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry')),
      ]),
    ),
  );
}