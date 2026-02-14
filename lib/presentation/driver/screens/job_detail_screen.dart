import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/driver/screens/active_delivery_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    // Dummy job data
    final job = {
      'id': jobId,
      'pickup': 'Premium Wholesale',
      'pickupAddress': '123 Market Street, London, E1 6AN',
      'pickupPhone': '+44 20 1234 5678',
      'delivery': 'The Italian Restaurant',
      'deliveryAddress': '456 High Street, London, SW1A 1AA',
      'deliveryPhone': '+44 20 8765 4321',
      'distance': 3.5,
      'payment': 12.50,
      'size': 'Medium',
      'vehicle': 'Van',
      'scheduledTime': '10:30 AM',
      'items': 5,
      'itemsList': ['Fresh Tomatoes - 10kg', 'Chicken Breast - 5kg', 'Whole Milk - 20L', 'White Bread - 15 loaves', 'Cheese - 3kg'],
      'specialInstructions': 'Please handle with care. Temperature sensitive items included.',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(job['id'] as String),  // FIXED: Cast to String
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Payment & Size Header
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                children: [
                  const Text(
                    'Delivery Payment',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '£${(job['payment'] as num).toStringAsFixed(2)}',  // FIXED: Cast to num
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route, size: 16, color: AppColors.white.withValues(alpha: 0.8)),  // FIXED: withValues
                      const SizedBox(width: 4),
                      Text(
                        '${job['distance']} km',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withValues(alpha: 0.8),  // FIXED: withValues
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: AppColors.white.withValues(alpha: 0.8)),  // FIXED: withValues
                      const SizedBox(width: 4),
                      Text(
                        job['scheduledTime'] as String,  // FIXED: Cast to String
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withValues(alpha: 0.8),  // FIXED: withValues
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delivery Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Size
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),  // FIXED: withValues
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.scale, color: AppColors.info, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Size',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${job['size']} - ${job['vehicle']} Required',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pickup Location
                  const Text(
                    'Pickup Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.store, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              job['pickup'] as String,  // FIXED: Cast to String
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          job['pickupAddress'] as String,  // FIXED: Cast to String
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(
                              job['pickupPhone'] as String,  // FIXED: Cast to String
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Location
                  const Text(
                    'Delivery Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              job['delivery'] as String,  // FIXED: Cast to String
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          job['deliveryAddress'] as String,  // FIXED: Cast to String
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(
                              job['deliveryPhone'] as String,  // FIXED: Cast to String
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items List
                  Text(
                    'Items (${job['items']})',  // FIXED: Use job['items'] instead of hardcoded 5
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: (job['itemsList'] as List).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item as String,  // FIXED: Cast to String
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Special Instructions
                  const Text(
                    'Special Instructions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),  // FIXED: withValues
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),  // FIXED: withValues
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outlined, color: AppColors.warning),  // FIXED: Changed from info_outline
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            job['specialInstructions'] as String,  // FIXED: Cast to String
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80), // Space for buttons
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),  // FIXED: withValues
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Reject Button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      _showRejectDialog(context, job['id'] as String);  // FIXED: Cast to String
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Accept Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      _showAcceptDialog(context, job);
                    },
                    child: const Text(
                      'Accept Job',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Job'),
        content: Text('Are you sure you want to reject $jobId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to jobs list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Job $jobId rejected'),
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

  void _showAcceptDialog(BuildContext context, Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accept ${job['id']}?'),
            const SizedBox(height: 12),
            Text(
              'Payment: £${(job['payment'] as num).toStringAsFixed(2)}',  // FIXED: Cast to num
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 4),
            Text('Distance: ${job['distance']} km'),
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
              Navigator.pop(context); // Go back
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActiveDeliveryScreen(),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Job ${job['id']} accepted! Navigate to pickup location.'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Accept & Start'),
          ),
        ],
      ),
    );
  }
}