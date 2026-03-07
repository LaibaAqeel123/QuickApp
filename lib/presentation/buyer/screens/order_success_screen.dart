import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const OrderSuccessScreen({super.key, this.orderData});

  String get _orderId =>
      (orderData?['id'] ?? orderData?['orderId'] ?? orderData?['orderNumber'] ?? '#ORD00000').toString();

  String get _estimatedDelivery {
    final raw = orderData?['estimatedDelivery'] ??
        orderData?['estimatedDeliveryTime'] ?? orderData?['deliveryTime'];
    if (raw == null) return 'Tomorrow, 10:00 AM';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h  = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month]}, $h:$m $ap';
    } catch (_) { return raw.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Use a simple scrollable layout — fixes ALL overflow on small screens
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [

            // Success icon
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 90, color: AppColors.success),
            ),
            const SizedBox(height: 28),

            const Text('Order Placed Successfully!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Your order has been placed and will be delivered soon.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),

            // Order details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Order Number', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  Flexible(child: Text(_orderId, textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary))),
                ]),
                const Divider(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Est. Delivery', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_estimatedDelivery,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis)),
                  ])),
                ]),
              ]),
            ),
            const SizedBox(height: 40),

            // Track Order button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: orderData != null ? () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: orderData!))) : null,
                icon: const Icon(Icons.location_on),
                label: const Text('Track Order'),
              ),
            ),
            const SizedBox(height: 12),

            // Back to Home button
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const BuyerMainScreen()), (r) => false),
                icon: const Icon(Icons.home),
                label: const Text('Back to Home'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}