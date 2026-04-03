import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/core/widgets/auth_image.dart';
import 'package:food_delivery_app/presentation/buyer/screens/category_products_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/product_detail_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  final void Function({String? searchQuery}) onBrowseTap;
  final VoidCallback? onViewCart;
  const BuyerHomeScreen({super.key, required this.onBrowseTap, this.onViewCart});
  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  String _businessName  = '';
  bool   _profileLoaded = false;
  List<Map<String, dynamic>> _categories        = [];
  bool                       _categoriesLoading = true;
  List<Map<String, dynamic>> _featured          = [];
  bool                       _featuredLoading   = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 [BuyerHomeScreen] initState');
    _loadProfile();
    _loadCategories();
    _loadFeatured();
  }

  Future<void> _loadProfile() async {
    debugPrint('👤 [BuyerHomeScreen] Loading profile...');
    final r = await AuthService.instance.getProfile();
    if (!mounted || !r.success || r.data == null) return;
    final d        = r.data!;
    final business = d['businessName']?.toString() ?? '';
    final first    = d['firstName']?.toString()    ?? '';
    final last     = d['lastName']?.toString()     ?? '';
    debugPrint('✅ [BuyerHomeScreen] Profile loaded — business: "$business"');
    setState(() {
      _businessName = business.isNotEmpty
          ? business
          : '$first $last'.trim().isNotEmpty
              ? '$first $last'.trim()
              : 'My Account';
      _profileLoaded = true;
    });
  }

  Future<void> _loadCategories() async {
    debugPrint('📂 [BuyerHomeScreen] Loading categories...');
    setState(() => _categoriesLoading = true);
    final r = await AuthService.instance.getCategories();
    if (!mounted) return;
    if (r.success && r.data != null) {
      final cats = r.data!.whereType<Map<String, dynamic>>().toList();
      debugPrint('✅ [BuyerHomeScreen] Categories loaded — count: ${cats.length}');
      for (int i = 0; i < cats.length && i < 4; i++) {
        final cat = cats[i];
        debugPrint('  📂 Category[$i]: name="${cat['name']}" imageUrl="${cat['imageUrl'] ?? cat['image']}"');
      }
      setState(() { _categories = cats; _categoriesLoading = false; });
    } else {
      debugPrint('⚠️  [BuyerHomeScreen] Categories failed, using fallback');
      setState(() { _categories = _fallback; _categoriesLoading = false; });
    }
  }

  static const List<Map<String, dynamic>> _fallback = [
    {'categoryId': null, 'id': null, 'name': 'Bakery'},
    {'categoryId': null, 'id': null, 'name': 'Meat'},
    {'categoryId': null, 'id': null, 'name': 'Dairy'},
    {'categoryId': null, 'id': null, 'name': 'Fruit & Veg'},
    {'categoryId': null, 'id': null, 'name': 'Frozen'},
    {'categoryId': null, 'id': null, 'name': 'Dry Items'},
    {'categoryId': null, 'id': null, 'name': 'Beverages'},
    {'categoryId': null, 'id': null, 'name': 'More'},
  ];

  Future<void> _loadFeatured() async {
    debugPrint('⭐ [BuyerHomeScreen] Loading featured products...');
    setState(() => _featuredLoading = true);
    final r = await AuthService.instance.getCatalogProducts(page: 1, pageSize: 4);
    if (!mounted) return;
    if (r.success && r.data != null) {
      final data = r.data!;
      List<dynamic> raw = [];
      if      (data['items']    is List) raw = data['items'];
      else if (data['data']     is List) raw = data['data'];
      else if (data['products'] is List) raw = data['products'];
      else if (data['results']  is List) raw = data['results'];
      final items = raw.whereType<Map<String, dynamic>>().take(4).toList();

      // ── Debug: check image data for each featured product ──
      debugPrint('✅ [BuyerHomeScreen] Featured products loaded — count: ${items.length}');
      for (int i = 0; i < items.length; i++) {
        final p      = items[i];
        final name   = p['name'] ?? p['productName'] ?? '?';
        final images = p['images'];
        final topUrl = p['imageUrl'] ?? p['image'];
        debugPrint('  ⭐ Featured[$i] "$name":');
        debugPrint('     images type: ${images.runtimeType}');
        if (images is List) {
          debugPrint('     images count: ${images.length}');
          for (final img in images.take(2)) {
            debugPrint('     img: $img');
          }
        }
        debugPrint('     top-level imageUrl: $topUrl');
      }

      setState(() { _featured = items; _featuredLoading = false; });
    } else {
      debugPrint('⚠️  [BuyerHomeScreen] Featured products failed: ${r.message}');
      setState(() => _featuredLoading = false);
    }
  }

  int? _extractCategoryId(Map<String, dynamic> cat) {
    for (final key in ['categoryId', 'id', 'category_id', 'CategoryId', 'Id']) {
      final v = cat[key];
      if (v is int)    return v;
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  void _openCategory(Map<String, dynamic> cat) {
    final name  = cat['name']?.toString() ?? '';
    final intId = _extractCategoryId(cat);
    debugPrint('📂 [BuyerHomeScreen] Opening category "$name" id=$intId');
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryProductsScreen(
        category:   name,
        categoryId: intId,
        onViewCart: widget.onViewCart,
      ),
    ));
  }

  String _pName(Map p)     => (p['name'] ?? p['productName'] ?? 'Product').toString();
  double _pPrice(Map p)    => ((p['price'] ?? p['unitPrice'] ?? p['basePrice'] ?? 0) as num).toDouble();
  String _pSupplier(Map p) => (p['supplierName'] ?? p['supplier']?['name'] ?? '').toString();
  String _pCategory(Map p) => (p['category'] ?? p['categoryName'] ?? '').toString();

  /// Extract primary image URL from a product map (same logic as browse/cart)
  String? _pImageUrl(Map<String, dynamic> p) {
    final name   = p['name'] ?? '?';
    final images = p['images'];
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
          debugPrint('🖼️  [HomeScreen] "$name" → image from array: $url');
          return url;
        }
      }
    }
    final fallback = ( p['primaryImageUrl'] ?? p['imageUrl'] ?? p['image'])?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('🖼️  [HomeScreen] "$name" → image from top-level: $fallback');
      return fallback;
    }
    debugPrint('⚠️  [HomeScreen] "$name" → NO image found. Keys: ${p.keys.toList()}');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              Future.wait([_loadProfile(), _loadCategories(), _loadFeatured()]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20), color: AppColors.primary,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Welcome back ',
                          style: TextStyle(fontSize: 14, color: AppColors.white)),
                      const SizedBox(height: 4),
                      Text(
                        _profileLoaded && _businessName.isNotEmpty
                            ? _businessName : 'My Restaurant',
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.bold, color: AppColors.white),
                      ),
                    ]),
                    IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        color: AppColors.white, onPressed: () {}),
                  ]),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => widget.onBrowseTap(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [
                        Icon(Icons.search, color: AppColors.textHint),
                        SizedBox(width: 12),
                        Expanded(child: Text('Search products, suppliers...',
                            style: TextStyle(color: AppColors.textHint, fontSize: 15))),
                        Icon(Icons.tune, color: AppColors.textHint, size: 20),
                      ]),
                    ),
                  ),
                ]),
              ),

              // ── Quick search chips ─────────────────────
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: ['Bakery', 'Chicken', 'Dairy', 'Fresh Veg', 'Rice']
                      .map((q) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => widget.onBrowseTap(searchQuery: q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Text(q, style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

              // ── Categories ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Categories', style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (_categoriesLoading)
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      TextButton(
                          onPressed: () => widget.onBrowseTap(),
                          child: const Text('View All')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _categoriesLoading
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, mainAxisSpacing: 12,
                            crossAxisSpacing: 12, childAspectRatio: 0.85),
                        itemCount: 8,
                        itemBuilder: (_, __) => Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, mainAxisSpacing: 12,
                            crossAxisSpacing: 12, childAspectRatio: 0.85),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          return _CategoryCard(
                            label:    cat['name']?.toString() ?? '',
                            imageUrl: cat['imageUrl']?.toString() ??
                                      cat['image']?.toString(),
                            onTap:    () => _openCategory(cat),
                          );
                        },
                      ),
              ),

              // ── Featured Products ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Featured Products', style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (_featuredLoading)
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      TextButton(
                          onPressed: () => widget.onBrowseTap(),
                          child: const Text('View All')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_featuredLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12,
                        mainAxisSpacing: 12, childAspectRatio: 0.72),
                    itemCount: 4,
                    itemBuilder: (_, __) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12,
                        mainAxisSpacing: 12, childAspectRatio: 0.72),
                    itemCount: _featured.isEmpty ? 4 : _featured.length,
                    itemBuilder: (_, i) {
                      if (_featured.isNotEmpty) {
                        final p = _featured[i];
                        return _ProductCard(
                          name:     _pName(p),
                          price:    _pPrice(p),
                          supplier: _pSupplier(p),
                          category: _pCategory(p),
                          imageUrl: _pImageUrl(p),
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ProductDetailScreen(
                              product: p, onViewCart: widget.onViewCart))),
                        );
                      }
                      // Fallback static cards (no image)
                      const fb = [
                        {'name': 'Fresh Tomatoes', 'price': 3.50, 'supplier': 'Premium Wholesale', 'category': 'Fruit & Veg'},
                        {'name': 'Chicken Breast', 'price': 8.99, 'supplier': 'Fresh Meat Co.',    'category': 'Meat'},
                        {'name': 'Whole Milk',     'price': 1.20, 'supplier': 'Dairy Farm',        'category': 'Dairy'},
                        {'name': 'White Bread',    'price': 0.99, 'supplier': "Baker's Best",      'category': 'Bakery'},
                      ];
                      final f = fb[i];
                      return _ProductCard(
                        name:     f['name']     as String,
                        price:    (f['price']   as num).toDouble(),
                        supplier: f['supplier'] as String,
                        category: f['category'] as String,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  CATEGORY CARD
// ══════════════════════════════════════════════════════════
class _CategoryCard extends StatelessWidget {
  final String  label;
  final String? imageUrl;
  final VoidCallback onTap;
  const _CategoryCard({required this.label, required this.onTap, this.imageUrl});

  IconData _icon() {
    switch (label.toLowerCase()) {
      case 'bakery':                      return Icons.bakery_dining;
      case 'meat':                        return Icons.set_meal;
      case 'dairy':                       return Icons.local_drink;
      case 'fruit & veg':
      case 'fruit and veg':
      case 'vegetables':                  return Icons.eco;
      case 'frozen':                      return Icons.ac_unit;
      case 'dry items': case 'dry goods': return Icons.grain;
      case 'beverages': case 'drinks':    return Icons.local_cafe;
      case 'more':                        return Icons.apps;
      default:                            return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    if (hasImage) {
      debugPrint('🖼️  [_CategoryCard] "$label" → using AuthImage: $imageUrl');
    } else {
      debugPrint('⚠️  [_CategoryCard] "$label" → no image, using icon');
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AuthImage(
                      url: imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: Center(
                          child: Icon(_icon(), size: 26, color: AppColors.primary)),
                      errorWidget: Center(
                          child: Icon(_icon(), size: 26, color: AppColors.primary)),
                    ),
                  )
                : Center(child: Icon(_icon(), size: 26, color: AppColors.primary)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Center(child: Text(label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis)),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  FEATURED PRODUCT CARD
// ══════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final String   name, supplier, category;
  final double   price;
  final String?  imageUrl;
  final VoidCallback? onTap;
  const _ProductCard({required this.name, required this.price,
      required this.supplier, required this.category,
      this.imageUrl, this.onTap});

  IconData _icon() {
    final n = category.toLowerCase();
    if (n.contains('bakery'))                        return Icons.bakery_dining;
    if (n.contains('meat'))                          return Icons.set_meal;
    if (n.contains('dairy'))                         return Icons.local_drink;
    if (n.contains('fruit') || n.contains('veg'))   return Icons.eco;
    if (n.contains('frozen'))                        return Icons.ac_unit;
    if (n.contains('dry'))                           return Icons.grain;
    if (n.contains('bev') || n.contains('drink'))   return Icons.local_cafe;
    final nm = name.toLowerCase();
    if (nm.contains('tomato') || nm.contains('carrot')) return Icons.eco;
    if (nm.contains('chicken') || nm.contains('beef'))  return Icons.set_meal;
    if (nm.contains('milk') || nm.contains('cheese'))   return Icons.local_drink;
    if (nm.contains('bread'))                           return Icons.bakery_dining;
    return Icons.shopping_basket;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image area ──────────────────────────────
          SizedBox(
            height: 110,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: hasImage
                  ? AuthImage(
                      url: imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 110,
                      placeholder: Container(
                        color: AppColors.surfaceLight,
                        child: Center(
                            child: Icon(_icon(), size: 55, color: AppColors.primary)),
                      ),
                      errorWidget: Container(
                        color: AppColors.surfaceLight,
                        child: Center(
                            child: Icon(_icon(), size: 55, color: AppColors.primary)),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceLight,
                      child: Center(
                          child: Icon(_icon(), size: 55, color: AppColors.primary)),
                    ),
            ),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (supplier.isNotEmpty)
                Text(supplier, style: const TextStyle(fontSize: 11,
                    color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('£${price.toStringAsFixed(2)}', style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: onTap != null ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: AppColors.white, size: 16),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}