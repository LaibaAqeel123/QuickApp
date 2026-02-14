import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/supplier/screens/schedule_delivery_screen.dart';
class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order['id']),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(order['status']),
                    size: 60,
                    color: AppColors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order['status'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${order['date']} • ${order['time']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Customer Info
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['customer'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '123 Main Street, London, SW1A 1AA',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '+44 20 1234 5678',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Order Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OrderItem(
                    name: 'Fresh Tomatoes',
                    quantity: '10 kg',
                    price: 35.00,
                  ),
                  const Divider(height: 24),
                  _OrderItem(
                    name: 'Chicken Breast',
                    quantity: '5 kg',
                    price: 44.95,
                  ),
                  const Divider(height: 24),
                  _OrderItem(
                    name: 'Whole Milk',
                    quantity: '20 L',
                    price: 24.00,
                  ),
                  const Divider(height: 24),
                  _OrderItem(
                    name: 'White Bread',
                    quantity: '15 loaves',
                    price: 14.85,
                  ),
                  const Divider(height: 24),
                  _OrderItem(
                    name: 'Cheddar Cheese',
                    quantity: '3 kg',
                    price: 17.97,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order Summary
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _SummaryRow(title: 'Subtotal', value: '£136.77'),
                  const SizedBox(height: 8),
                  _SummaryRow(title: 'Delivery Fee', value: '£8.73'),
                  const SizedBox(height: 8),
                  Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    title: 'Total',
                    value: '£${order['total'].toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delivery Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.local_shipping,
                    title: 'Delivery Type',
                    value: order['deliveryType'],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.scale,
                    title: 'Delivery Size',
                    value: 'Medium',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.directions_car,
                    title: 'Vehicle',
                    value: 'Van',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (order['status'] == 'Pending')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showRejectDialog(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showAcceptDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept Order'),
                      ),
                    ),
                  ],
                ),
              ),

            if (order['status'] == 'Processing')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScheduleDeliveryScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Schedule Delivery'),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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

  void _showAcceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Text('Accept order ${order['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order accepted successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Text('Are you sure you want to reject order ${order['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order rejected'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItem extends StatelessWidget {
  final String name;
  final String quantity;
  final double price;

  const _OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.shopping_basket,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                quantity,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          '£${price.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}