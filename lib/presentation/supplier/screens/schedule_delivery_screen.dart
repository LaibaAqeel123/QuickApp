import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class ScheduleDeliveryScreen extends StatefulWidget {
  const ScheduleDeliveryScreen({super.key});

  @override
  State<ScheduleDeliveryScreen> createState() => _ScheduleDeliveryScreenState();
}

class _ScheduleDeliveryScreenState extends State<ScheduleDeliveryScreen> {
  String _selectedSize = 'Medium';
  String _selectedVehicle = 'Van';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final Map<String, Map<String, dynamic>> _deliverySizes = {
    'Small': {
      'icon': Icons.pedal_bike,
      'description': 'Up to 5kg',
      'vehicles': ['Bicycle', 'Scooter'],
      'price': 5.00,
    },
    'Medium': {
      'icon': Icons.directions_car,
      'description': '5kg - 50kg',
      'vehicles': ['Car', 'Van'],
      'price': 12.00,
    },
    'Large': {
      'icon': Icons.local_shipping,
      'description': '50kg - 200kg',
      'vehicles': ['Van', 'Truck'],
      'price': 25.00,
    },
    'Extra Large': {
      'icon': Icons.fire_truck,
      'description': '200kg - 500kg',
      'vehicles': ['Truck', 'Lorry'],
      'price': 45.00,
    },
    'Bulk': {
      'icon': Icons.warehouse,
      'description': 'Over 500kg',
      'vehicles': ['Lorry'],
      'price': 80.00,
    },
  };

  void _scheduleDelivery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery scheduled successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule Delivery'),
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
              // Delivery Size Selection
              const Text(
                'Select Delivery Size',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              ...(_deliverySizes.entries.map((entry) {
                return _DeliverySizeCard(
                  size: entry.key,
                  icon: entry.value['icon'],
                  description: entry.value['description'],
                  price: entry.value['price'],
                  isSelected: _selectedSize == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedSize = entry.key;
                      _selectedVehicle = entry.value['vehicles'][0];
                    });
                  },
                );
              }).toList()),

              const SizedBox(height: 24),

              // Vehicle Selection
              const Text(
                'Select Vehicle Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _deliverySizes[_selectedSize]!['vehicles'].map<Widget>((vehicle) {
                  return _VehicleChip(
                    vehicle: vehicle,
                    isSelected: _selectedVehicle == vehicle,
                    onTap: () {
                      setState(() {
                        _selectedVehicle = vehicle;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Date & Time
              const Text(
                'Pickup Date & Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

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
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
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
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.primary, size: 20),
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

              const SizedBox(height: 24),

              // Delivery Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryItem(title: 'Size', value: _selectedSize),
                    _SummaryItem(title: 'Vehicle', value: _selectedVehicle),
                    _SummaryItem(
                      title: 'Pickup',
                      value: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at ${_selectedTime.format(context)}',
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated Cost',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '£${_deliverySizes[_selectedSize]!['price'].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Schedule Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _scheduleDelivery,
                  child: const Text('Schedule Delivery'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliverySizeCard extends StatelessWidget {
  final String size;
  final IconData icon;
  final String description;
  final double price;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliverySizeCard({
    required this.size,
    required this.icon,
    required this.description,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.white : AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    size,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  final String vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          vehicle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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
      ),
    );
  }
}