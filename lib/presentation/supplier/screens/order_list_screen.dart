import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/supplier/screens/order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'ORD1234',
      'customer': 'The Italian Restaurant',
      'items': 5,
      'total': 145.50,
      'status': 'Pending',
      'date': '2024-02-09',
      'time': '10:30 AM',
      'deliveryType': 'Standard',
    },
    {
      'id': 'ORD1235',
      'customer': 'Burger House',
      'items': 3,
      'total': 89.99,
      'status': 'Processing',
      'date': '2024-02-09',
      'time': '11:15 AM',
      'deliveryType': 'Express',
    },
    {
      'id': 'ORD1236',
      'customer': 'Sushi Palace',
      'items': 8,
      'total': 234.00,
      'status': 'Out for Delivery',
      'date': '2024-02-09',
      'time': '09:45 AM',
      'deliveryType': 'Standard',
    },
    {
      'id': 'ORD1237',
      'customer': 'Pizza Corner',
      'items': 4,
      'total': 112.50,
      'status': 'Delivered',
      'date': '2024-02-08',
      'time': '03:20 PM',
      'deliveryType': 'Express',
    },
    {
      'id': 'ORD1238',
      'customer': 'Cafe Delight',
      'items': 6,
      'total': 167.80,
      'status': 'Delivered',
      'date': '2024-02-08',
      'time': '02:10 PM',
      'deliveryType': 'Standard',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Delivering'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('Pending'),
          _buildOrderList('Processing'),
          _buildOrderList('Out for Delivery'),
          _buildOrderList('Delivered'),
        ],
      ),
    );
  }

  Widget _buildOrderList(String status) {
    final orders = _getOrdersByStatus(status);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No $status Orders',
              style: const TextStyle(
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
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(order: order),
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
      case 'Pending':
        return AppColors.warning;
      case 'Processing':
        return AppColors.info;
      case 'Out for Delivery':
        return AppColors.secondary;
      case 'Delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.schedule;
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                      Text(
                        order['customer'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '${order['date']} • ${order['time']}',
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

                // Price
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
                    const SizedBox(height: 4),
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

            // Divider
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),

            // Order Details Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_basket, size: 16, color: AppColors.textSecondary),
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
                    Icon(
                      order['deliveryType'] == 'Express'
                          ? Icons.bolt
                          : Icons.local_shipping_outlined,
                      size: 16,
                      color: order['deliveryType'] == 'Express'
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order['deliveryType'],
                      style: TextStyle(
                        fontSize: 13,
                        color: order['deliveryType'] == 'Express'
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontWeight: order['deliveryType'] == 'Express'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}