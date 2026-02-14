import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<Map<String, dynamic>> _inventory = [
    {'id': 1, 'name': 'Fresh Tomatoes', 'category': 'Fruit & Veg', 'stock': 150, 'unit': 'kg', 'minStock': 50, 'image': '🍅'},
    {'id': 2, 'name': 'Chicken Breast', 'category': 'Meat', 'stock': 75, 'unit': 'kg', 'minStock': 30, 'image': '🍗'},
    {'id': 3, 'name': 'Whole Milk', 'category': 'Dairy', 'stock': 200, 'unit': 'L', 'minStock': 100, 'image': '🥛'},
    {'id': 4, 'name': 'White Bread', 'category': 'Bakery', 'stock': 35, 'unit': 'loaf', 'minStock': 50, 'image': '🍞'},
    {'id': 5, 'name': 'Frozen Pizza', 'category': 'Frozen', 'stock': 15, 'unit': 'pc', 'minStock': 30, 'image': '🍕'},
    {'id': 6, 'name': 'Rice 5kg', 'category': 'Dry Items', 'stock': 50, 'unit': 'bag', 'minStock': 20, 'image': '🍚'},
    {'id': 7, 'name': 'Cheddar Cheese', 'category': 'Dairy', 'stock': 90, 'unit': 'kg', 'minStock': 40, 'image': '🧀'},
    {'id': 8, 'name': 'Carrots', 'category': 'Fruit & Veg', 'stock': 25, 'unit': 'kg', 'minStock': 40, 'image': '🥕'},
  ];

  String _filter = 'All';

  List<Map<String, dynamic>> get _filteredInventory {
    if (_filter == 'Low Stock') {
      return _inventory.where((item) => item['stock'] < item['minStock']).toList();
    } else if (_filter == 'In Stock') {
      return _inventory.where((item) => item['stock'] >= item['minStock']).toList();
    }
    return _inventory;
  }

  int get _lowStockCount {
    return _inventory.where((item) => item['stock'] < item['minStock']).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Items',
                        value: '${_inventory.length}',
                        icon: Icons.inventory_2,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Low Stock',
                        value: '$_lowStockCount',
                        icon: Icons.warning,
                        color: _lowStockCount > 0 ? AppColors.warning : AppColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filter == 'All',
                  onTap: () => setState(() => _filter = 'All'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Low Stock',
                  isSelected: _filter == 'Low Stock',
                  onTap: () => setState(() => _filter = 'Low Stock'),
                  count: _lowStockCount,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'In Stock',
                  isSelected: _filter == 'In Stock',
                  onTap: () => setState(() => _filter = 'In Stock'),
                ),
              ],
            ),
          ),

          // Inventory List
          Expanded(
            child: _filteredInventory.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items found',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredInventory.length,
              itemBuilder: (context, index) {
                final item = _filteredInventory[index];
                return _InventoryCard(
                  item: item,
                  onAdjust: () => _showAdjustStockDialog(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockDialog(Map<String, dynamic> item) {
    final controller = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust Stock - ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add Stock'),
                      selected: isAdding,
                      onSelected: (selected) {
                        setDialogState(() => isAdding = true);
                      },
                      selectedColor: AppColors.success,
                      labelStyle: TextStyle(
                        color: isAdding ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Remove Stock'),
                      selected: !isAdding,
                      onSelected: (selected) {
                        setDialogState(() => isAdding = false);
                      },
                      selectedColor: AppColors.error,
                      labelStyle: TextStyle(
                        color: !isAdding ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity (${item['unit']})',
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Current Stock:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${item['stock']} ${item['unit']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final quantity = int.tryParse(controller.text) ?? 0;
                  setState(() {
                    if (isAdding) {
                      item['stock'] += quantity;
                    } else {
                      item['stock'] = (item['stock'] - quantity).clamp(0, double.infinity).toInt();
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock ${isAdding ? 'added' : 'removed'} successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.white : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAdjust;

  const _InventoryCard({required this.item, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final isLowStock = item['stock'] < item['minStock'];
    final stockPercentage = (item['stock'] / item['minStock']).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock ? AppColors.error.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item['image'],
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['category'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${item['stock']} ${item['unit']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isLowStock ? AppColors.error : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '/ ${item['minStock']} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Adjust Button
              IconButton(
                onPressed: onAdjust,
                icon: const Icon(Icons.edit),
                color: AppColors.primary,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stock Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stockPercentage,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation(
                isLowStock ? AppColors.error : AppColors.success,
              ),
              minHeight: 6,
            ),
          ),

          // Low Stock Warning
          if (isLowStock) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  const Text(
                    'Low Stock Alert',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}