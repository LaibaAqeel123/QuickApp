import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/buyer/screens/order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _deliveryType = 'Standard';
  String _paymentMethod = 'Card';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  void _placeOrder() {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OrderSuccessScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
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
              // Delivery Address
              _SectionCard(
                title: 'Delivery Address',
                icon: Icons.location_on,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The Italian Restaurant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '123 Main Street, London, SW1A 1AA',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '+44 20 1234 5678',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Change Address'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Schedule
              _SectionCard(
                title: 'Delivery Schedule',
                icon: Icons.access_time,
                child: Column(
                  children: [
                    // Delivery Type
                    Row(
                      children: [
                        Expanded(
                          child: _DeliveryTypeButton(
                            label: 'Standard',
                            subtitle: 'Next day',
                            icon: Icons.local_shipping,
                            isSelected: _deliveryType == 'Standard',
                            onTap: () => setState(() => _deliveryType = 'Standard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DeliveryTypeButton(
                            label: 'Express',
                            subtitle: 'Same day',
                            icon: Icons.bolt,
                            isSelected: _deliveryType == 'Express',
                            onTap: () => setState(() => _deliveryType = 'Express'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (date != null) {
                                setState(() => _selectedDate = date);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                              );
                              if (time != null) {
                                setState(() => _selectedTime = time);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              _SectionCard(
                title: 'Payment Method',
                icon: Icons.payment,
                child: Column(
                  children: [
                    _PaymentMethodTile(
                      icon: Icons.credit_card,
                      title: 'Credit/Debit Card',
                      subtitle: 'Visa, Mastercard, Amex',
                      value: 'Card',
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodTile(
                      icon: Icons.account_balance,
                      title: 'Bank Transfer',
                      subtitle: 'Direct bank transfer',
                      value: 'Bank',
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                    const SizedBox(height: 12),
                    _PaymentMethodTile(
                      icon: Icons.money,
                      title: 'Cash on Delivery',
                      subtitle: 'Pay when you receive',
                      value: 'Cash',
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Order Summary
              _SectionCard(
                title: 'Order Summary',
                icon: Icons.receipt,
                child: Column(
                  children: [
                    _SummaryRow(title: 'Subtotal', value: '£${widget.subtotal.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _SummaryRow(title: 'Delivery Fee', value: '£${widget.deliveryFee.toStringAsFixed(2)}'),
                    const Divider(height: 24),
                    _SummaryRow(
                      title: 'Total',
                      value: '£${widget.total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Place Order Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _placeOrder,
                  child: const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DeliveryTypeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryTypeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
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