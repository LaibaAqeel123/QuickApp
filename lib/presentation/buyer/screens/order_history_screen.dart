import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'ORD12345',
      'date': '2024-02-10',
      'time': '10:30 AM',
      'status': 'Delivered',
      'items': 5,
      'total': 145.50,
      'supplier': 'Premium Wholesale',
    },
    {
      'id': 'ORD12346',
      'date': '2024-02-11',
      'time': '02:15 PM',
      'status': 'Out for Delivery',
      'items': 3,
      'total': 89.99,
      'supplier': 'Fresh Meat Co.',
    },
    {
      'id': 'ORD12347',
      'date': '2024-02-12',
      'time': '09:00 AM',
      'status': 'Processing',
      'items': 8,
      'total': 234.00,
      'supplier': 'Dairy Farm',
    },
    {
      'id': 'ORD12348',
      'date': '2024-02-09',
      'time': '11:45 AM',
      'status': 'Delivered',
      'items': 4,
      'total': 112.50,
      'supplier': 'Baker\'s Best',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getOrdersByStatus(String status) {
    if (status == 'All') return _orders;
    return _orders.where((order) => order['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(['Processing', 'Out for Delivery']),
          _buildOrderList(['Delivered']),
          _buildOrderList(['All']),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<String> statuses) {
    List<Map<String, dynamic>> filteredOrders = _orders;
    if (!statuses.contains('All')) {
      filteredOrders = _orders.where((order) => statuses.contains(order['status'])).toList();
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            const Text(
              'No orders found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _OrderCard(
          order: order,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(order: order),
              ),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Processing':
        return AppColors.warning;
      case 'Out for Delivery':
        return AppColors.info;
      case 'Delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Processing':
        return Icons.autorenew;
      case 'Out for Delivery':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order['status']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(order['status']),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Order Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['id'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.store, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order['supplier'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${order['date']} • ${order['time']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Price & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${order['total'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_basket, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${order['items']} items',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (order['status'] != 'Delivered') ...[
                      const Text(
                        'Track Order',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}