import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Plan
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: AppColors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Premium Plan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '£299.99 / Year',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Renews on February 9, 2026',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Features
              const Text(
                'Premium Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _FeatureItem(
                icon: Icons.check_circle,
                title: 'Unlimited Products',
                subtitle: 'Add unlimited products to your catalog',
              ),
              _FeatureItem(
                icon: Icons.check_circle,
                title: 'Priority Support',
                subtitle: '24/7 customer support with priority response',
              ),
              _FeatureItem(
                icon: Icons.check_circle,
                title: 'Advanced Analytics',
                subtitle: 'Detailed reports and insights',
              ),
              _FeatureItem(
                icon: Icons.check_circle,
                title: 'Multiple Locations',
                subtitle: 'Manage multiple warehouse locations',
              ),
              _FeatureItem(
                icon: Icons.check_circle,
                title: 'API Access',
                subtitle: 'Integrate with your existing systems',
              ),
              _FeatureItem(
                icon: Icons.check_circle,
                title: 'Reduced Fees',
                subtitle: 'Lower transaction fees on all orders',
              ),

              const SizedBox(height: 24),

              // Payment History
              const Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _PaymentHistoryCard(
                date: 'Feb 9, 2025',
                amount: '£299.99',
                status: 'Paid',
                method: 'Visa •••• 4242',
              ),
              _PaymentHistoryCard(
                date: 'Feb 9, 2024',
                amount: '£299.99',
                status: 'Paid',
                method: 'Visa •••• 4242',
              ),

              const SizedBox(height: 24),

              // Manage Buttons
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Update Payment Method'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCancelDialog(context);
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your Premium subscription? '
              'You will lose access to all premium features at the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription cancelled successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final String date;
  final String amount;
  final String status;
  final String method;

  const _PaymentHistoryCard({
    required this.date,
    required this.amount,
    required this.status,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  method,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}