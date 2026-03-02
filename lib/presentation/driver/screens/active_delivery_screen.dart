import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  String _currentStep = 'Heading to Pickup'; // Heading to Pickup, Picked Up, Heading to Delivery, Delivered

  @override
  Widget build(BuildContext context) {
    // Check if there's an active delivery
    final bool hasActiveDelivery = true; // Change to false to show "No active delivery"

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Active Delivery'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Placeholder
            Container(
              height: 300,
              color: AppColors.surfaceLight,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.navigation,
                          size: 80,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Navigation Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '2.5 km away • 8 mins',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: () {},
                      backgroundColor: AppColors.white,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            // Current Status
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                children: [
                  Text(
                    _currentStep,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'JOB1001',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Delivery Steps
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _DeliveryStep(
                    icon: Icons.store,
                    title: 'Pickup from Premium Wholesale',
                    address: '123 Market Street, London',
                    phone: '+44 20 1234 5678',
                    isCompleted: _currentStep != 'Heading to Pickup',
                    isActive: _currentStep == 'Heading to Pickup',
                    buttonText: 'Mark as Picked Up',
                    onButtonPressed: () {
                      setState(() {
                        _currentStep = 'Heading to Delivery';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Items picked up! Heading to delivery location.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _DeliveryStep(
                    icon: Icons.location_on,
                    title: 'Deliver to The Italian Restaurant',
                    address: '456 High Street, London',
                    phone: '+44 20 8765 4321',
                    isCompleted: _currentStep == 'Delivered',
                    isActive: _currentStep == 'Heading to Delivery',
                    buttonText: 'Complete Delivery',
                    onButtonPressed: () {
                      _showCompleteDeliveryDialog();
                    },
                  ),
                ],
              ),
            ),

            // Delivery Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(icon: Icons.scale, label: 'Size', value: 'Medium (Van)'),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.shopping_basket, label: 'Items', value: '5 items'),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.attach_money, label: 'Payment', value: '£12.50'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showCompleteDeliveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Have you delivered all items successfully?'),
            const SizedBox(height: 16),
            const Text(
              'Proof of Delivery',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Open camera for photo
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Get signature
              },
              icon: const Icon(Icons.draw),
              label: const Text('Get Signature'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
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
              Navigator.pop(context); // Close dialog
              setState(() {
                _currentStep = 'Delivered';
              });

              // Show success and navigate
              Future.delayed(const Duration(milliseconds: 500), () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            size: 60,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Delivery Completed!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '£12.50 earned',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close success dialog
                            },
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String address;
  final String phone;
  final bool isCompleted;
  final bool isActive;
  final String buttonText;
  final VoidCallback? onButtonPressed;

  const _DeliveryStep({
    required this.icon,
    required this.title,
    required this.address,
    required this.phone,
    required this.isCompleted,
    required this.isActive,
    required this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.textHint;
    if (isCompleted) statusColor = AppColors.success;
    if (isActive) statusColor = AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : icon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.primary),
                onPressed: () {
                  // TODO: Call phone number
                },
              ),
            ],
          ),
          if (isActive && onButtonPressed != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
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