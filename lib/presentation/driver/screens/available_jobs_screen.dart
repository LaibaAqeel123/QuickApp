import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/presentation/driver/screens/job_detail_screen.dart';

class AvailableJobsScreen extends StatefulWidget {
  const AvailableJobsScreen({super.key});

  @override
  State<AvailableJobsScreen> createState() => _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends State<AvailableJobsScreen> {
  String _selectedSize = 'All';
  String _selectedArea = 'All Areas';

  final List<String> _sizes = ['All', 'Small', 'Medium', 'Large', 'Extra Large', 'Bulk'];
  final List<String> _areas = ['All Areas', 'Central London', 'North London', 'South London', 'East London', 'West London'];

  final List<Map<String, dynamic>> _jobs = [
    {
      'id': 'JOB1001',
      'pickup': 'Premium Wholesale',
      'pickupAddress': '123 Market St, London',
      'delivery': 'The Italian Restaurant',
      'deliveryAddress': '456 High St, London',
      'distance': 3.5,
      'payment': 12.50,
      'size': 'Medium',
      'time': '10:30 AM',
      'area': 'Central London',
      'items': 5,
    },
    {
      'id': 'JOB1002',
      'pickup': 'Fresh Meat Co.',
      'pickupAddress': '789 Meat Lane, London',
      'delivery': 'Burger House',
      'deliveryAddress': '321 Food Ave, London',
      'distance': 5.2,
      'payment': 15.00,
      'size': 'Large',
      'time': '11:00 AM',
      'area': 'North London',
      'items': 8,
    },
    {
      'id': 'JOB1003',
      'pickup': 'Baker\'s Best',
      'pickupAddress': '555 Bakery Rd, London',
      'delivery': 'Cafe Delight',
      'deliveryAddress': '888 Coffee St, London',
      'distance': 2.1,
      'payment': 8.50,
      'size': 'Small',
      'time': '09:45 AM',
      'area': 'South London',
      'items': 3,
    },
    {
      'id': 'JOB1004',
      'pickup': 'Dairy Farm Supplies',
      'pickupAddress': '999 Milk Way, London',
      'delivery': 'Pizza Corner',
      'deliveryAddress': '111 Pizza Plaza, London',
      'distance': 7.8,
      'payment': 18.00,
      'size': 'Extra Large',
      'time': '12:15 PM',
      'area': 'East London',
      'items': 12,
    },
    {
      'id': 'JOB1005',
      'pickup': 'Wholesale Hub',
      'pickupAddress': '222 Bulk St, London',
      'delivery': 'SuperMart Chain',
      'deliveryAddress': '333 Retail Rd, London',
      'distance': 15.5,
      'payment': 45.00,
      'size': 'Bulk',
      'time': 'Tomorrow 8:00 AM',
      'area': 'West London',
      'items': 25,
    },
  ];

  List<Map<String, dynamic>> get _filteredJobs {
    return _jobs.where((job) {
      bool sizeMatch = _selectedSize == 'All' || job['size'] == _selectedSize;
      bool areaMatch = _selectedArea == 'All Areas' || job['area'] == _selectedArea;
      return sizeMatch && areaMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Available Jobs'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSize,
                        decoration: const InputDecoration(
                          labelText: 'Size',  // FIXED: Shortened from 'Delivery Size'
                          prefixIcon: Icon(Icons.scale),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,  // FIXED: Added to reduce height
                        ),
                        isExpanded: true,  // FIXED: Added to prevent overflow
                        items: _sizes.map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text(
                              size,
                              overflow: TextOverflow.ellipsis,  // FIXED: Added overflow handling
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSize = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedArea,
                        decoration: const InputDecoration(
                          labelText: 'Area',
                          prefixIcon: Icon(Icons.location_on),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,  // FIXED: Added to reduce height
                        ),
                        isExpanded: true,  // FIXED: Added to prevent overflow
                        items: _areas.map((area) {
                          return DropdownMenuItem(
                            value: area,
                            child: Text(
                              area,
                              overflow: TextOverflow.ellipsis,  // FIXED: Added overflow handling
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedArea = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surfaceLight,
            width: double.infinity,
            child: Text(
              '${_filteredJobs.length} jobs available',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Jobs List
          Expanded(
            child: _filteredJobs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_off,
                    size: 80,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No jobs available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try changing your filters',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredJobs.length,
              itemBuilder: (context, index) {
                final job = _filteredJobs[index];
                return _JobCard(
                  job: job,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailScreen(
                          jobId: job['id'] as String,  // FIXED: Added cast
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.onTap});

  Color _getSizeColor(String size) {
    switch (size) {
      case 'Small':
        return AppColors.success;
      case 'Medium':
        return AppColors.info;
      case 'Large':
        return AppColors.warning;
      case 'Extra Large':
        return AppColors.error;
      case 'Bulk':
        return AppColors.primaryDark;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: Colors.black.withValues(alpha: 0.05),  // FIXED: withValues
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job['id'] as String,  // FIXED: Added cast
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSizeColor(job['size'] as String).withValues(alpha: 0.1),  // FIXED: withValues and cast
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job['size'] as String,  // FIXED: Added cast
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getSizeColor(job['size'] as String),  // FIXED: Added cast
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pickup
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),  // FIXED: withValues
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.store, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        job['pickup'] as String,  // FIXED: Added cast
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,  // FIXED: Added
                        overflow: TextOverflow.ellipsis,  // FIXED: Added
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Delivery
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),  // FIXED: withValues
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.location_on, size: 16, color: AppColors.success),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        job['delivery'] as String,  // FIXED: Added cast
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,  // FIXED: Added
                        overflow: TextOverflow.ellipsis,  // FIXED: Added
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Bottom Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(  // FIXED: Wrapped with Flexible
                  child: Row(
                    children: [
                      const Icon(Icons.route, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '${job['distance']} km',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Flexible(  // FIXED: Wrapped with Flexible
                        child: Text(
                          job['time'] as String,  // FIXED: Added cast
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,  // FIXED: Added
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),  // FIXED: Added spacing
                Text(
                  '£${(job['payment'] as num).toStringAsFixed(2)}',  // FIXED: Added cast
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}