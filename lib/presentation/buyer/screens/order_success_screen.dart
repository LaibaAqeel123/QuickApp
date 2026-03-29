import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/buyer_main_screen.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_tracking_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const OrderSuccessScreen({super.key, this.orderData});

  // Check if multiple orders
  bool get _isMultiOrder {
    final orders = orderData?['orders'];
    return orders is List && (orders as List).length > 1;
  }

  List<Map<String, dynamic>> get _orders {
    final orders = orderData?['orders'];
    if (orders is List) {
      return orders.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  String get _orderId =>
      (orderData?['id'] ?? orderData?['orderId'] ??
          orderData?['orderNumber'] ?? '#ORD00000').toString();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [

            //  Success Icon
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 90,
                  color: AppColors.success),
            ),
            const SizedBox(height: 28),

            Text(
              _isMultiOrder
                  ? '${_orders.length} Orders Placed!'
                  : 'Order Placed Successfully!',
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isMultiOrder
                  ? 'Your items were from ${_orders.length} suppliers. ${_orders.length} separate orders have been created.'
                  : 'Your order has been placed and will be delivered soon.',
              style: const TextStyle(fontSize: 15,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            //  Multiple orders — show each one
            if (_isMultiOrder) ...[
              ..._orders.map((order) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier name
                    Row(children: [
                      const Icon(Icons.store, size: 18,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        order['supplierName']?.toString() ?? 'Store',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      )),
                    ]),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order #',
                            style: TextStyle(fontSize: 13,
                                color: AppColors.textSecondary)),
                        Text(
                          order['orderNumber']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 13,
                                color: AppColors.textSecondary)),
                        Text(
                          '£${((order['totalAmount'] ?? 0) as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee',
                            style: TextStyle(fontSize: 13,
                                color: AppColors.textSecondary)),
                        Text(
                          '£${((order['deliveryFee'] ?? 2.99) as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              )),

              //  Grand Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(
                      '£${((orderData?['grandTotal'] ?? 0) as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ]

            //  Single order — original design
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Number',
                          style: TextStyle(fontSize: 14,
                              color: AppColors.textSecondary)),
                      Flexible(child: Text(
                        _orders.isNotEmpty
                            ? _orders.first['orderNumber']?.toString() ?? _orderId
                            : _orderId,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      )),
                    ],
                  ),
                  
                ]),
              ),
            ],

            const SizedBox(height: 40),

            //  Track Order — only for single order
            if (!_isMultiOrder)
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
    onPressed: () {

    final orders = orderData?['orders'] as List?;
    final firstOrder = orders?.isNotEmpty == true
    ? orders!.first as Map<String, dynamic>
        : orderData ?? {};
    Navigator.push(context,
    MaterialPageRoute(builder: (_) =>
    OrderTrackingScreen(order: firstOrder)));
    },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Track Order'),
                ),
              ),

            if (!_isMultiOrder) const SizedBox(height: 12),

            //  Back to Home
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const BuyerMainScreen()),
                        (r) => false),
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