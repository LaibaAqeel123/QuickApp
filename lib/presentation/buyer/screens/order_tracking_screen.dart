import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order['id']),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Placeholder
            Container(
              height: 250,
              color: AppColors.surfaceLight,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          size: 80,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tracking your delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Driver Info Card
            if (order['status'] == 'Out for Delivery')
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'John Driver',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,  // Add this
                            overflow: TextOverflow.ellipsis,  // Add this
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: AppColors.warning),
                              SizedBox(width: 4),
                              Text(
                                '4.9 (250 deliveries)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Van • ABC 1234',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: AppColors.primary),
                      onPressed: () {},
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),

            // Tracking Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TrackingStep(
                    title: 'Order Placed',
                    subtitle: '${order['date']} • ${order['time']}',
                    isCompleted: true,
                    isActive: false,
                    icon: Icons.check_circle,
                  ),
                  _TrackingStep(
                    title: 'Order Confirmed',
                    subtitle: 'Your order has been confirmed',
                    isCompleted: true,
                    isActive: false,
                    icon: Icons.verified,
                  ),
                  _TrackingStep(
                    title: order['status'] == 'Processing' ? 'Preparing Order' : 'Order Prepared',
                    subtitle: 'Your order is being prepared',
                    isCompleted: order['status'] != 'Processing',
                    isActive: order['status'] == 'Processing',
                    icon: Icons.inventory_2,
                  ),
                  _TrackingStep(
                    title: 'Out for Delivery',
                    subtitle: 'Driver is on the way',
                    isCompleted: order['status'] == 'Delivered',
                    isActive: order['status'] == 'Out for Delivery',
                    icon: Icons.local_shipping,
                  ),
                  _TrackingStep(
                    title: 'Delivered',
                    subtitle: 'Order has been delivered',
                    isCompleted: order['status'] == 'Delivered',
                    isActive: false,
                    icon: Icons.check_circle,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order Details
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
                    'Order Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.receipt,
                    label: 'Order ID',
                    value: order['id'],
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.store,
                    label: 'Supplier',
                    value: order['supplier'],
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.shopping_basket,
                    label: 'Items',
                    value: '${order['items']} items',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.attach_money,
                    label: 'Total Amount',
                    value: '£${order['total'].toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final IconData icon;
  final bool isLast;

  const _TrackingStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.textHint;
    if (isCompleted) color = AppColors.success;
    if (isActive) color = AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted || isActive ? color.withOpacity(0.1) : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: isCompleted ? AppColors.success : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isActive || isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
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