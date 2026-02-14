import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert for expiring documents
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your driver\'s license expires in 30 days. Please update it soon.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Required Documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Driver's License
              _DocumentCard(
                icon: Icons.card_membership,
                title: 'Driver\'s License',
                status: 'Verified',
                expiryDate: 'Expires: Mar 15, 2025',
                statusColor: AppColors.warning,
                onUpload: () {
                  _showUploadDialog(context, 'Driver\'s License');
                },
                onView: () {},
              ),

              // Vehicle Insurance
              _DocumentCard(
                icon: Icons.verified_user,
                title: 'Vehicle Insurance',
                status: 'Verified',
                expiryDate: 'Expires: Dec 20, 2026',
                statusColor: AppColors.success,
                onUpload: () {
                  _showUploadDialog(context, 'Vehicle Insurance');
                },
                onView: () {},
              ),

              // Vehicle Registration
              _DocumentCard(
                icon: Icons.description,
                title: 'Vehicle Registration',
                status: 'Verified',
                expiryDate: 'Valid',
                statusColor: AppColors.success,
                onUpload: () {
                  _showUploadDialog(context, 'Vehicle Registration');
                },
                onView: () {},
              ),

              // MOT Certificate
              _DocumentCard(
                icon: Icons.check_circle,
                title: 'MOT Certificate',
                status: 'Verified',
                expiryDate: 'Expires: Aug 10, 2025',
                statusColor: AppColors.success,
                onUpload: () {
                  _showUploadDialog(context, 'MOT Certificate');
                },
                onView: () {},
              ),

              // Right to Work
              _DocumentCard(
                icon: Icons.work,
                title: 'Right to Work',
                status: 'Verified',
                expiryDate: 'Valid',
                statusColor: AppColors.success,
                onUpload: () {
                  _showUploadDialog(context, 'Right to Work Document');
                },
                onView: () {},
              ),

              // Profile Photo
              _DocumentCard(
                icon: Icons.person,
                title: 'Profile Photo',
                status: 'Uploaded',
                expiryDate: '',
                statusColor: AppColors.success,
                onUpload: () {
                  _showUploadDialog(context, 'Profile Photo');
                },
                onView: () {},
              ),

              const SizedBox(height: 24),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Document Requirements',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• All documents must be clear and readable\n'
                          '• Upload current, valid documents only\n'
                          '• Documents are verified within 24-48 hours\n'
                          '• You\'ll receive notifications before expiry',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context, String documentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload $documentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening camera for $documentName...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening gallery for $documentName...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final String expiryDate;
  final Color statusColor;
  final VoidCallback onUpload;
  final VoidCallback onView;

  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.expiryDate,
    required this.statusColor,
    required this.onUpload,
    required this.onView,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (expiryDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        expiryDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.upload, size: 20),
                        const SizedBox(width: 12),
                        const Text('Upload New'),
                      ],
                    ),
                    onTap: onUpload,
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, size: 20),
                        const SizedBox(width: 12),
                        const Text('View Document'),
                      ],
                    ),
                    onTap: onView,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}