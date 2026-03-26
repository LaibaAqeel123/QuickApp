import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';

class DisputeFormScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const DisputeFormScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<DisputeFormScreen> createState() => _DisputeFormScreenState();
}

class _DisputeFormScreenState extends State<DisputeFormScreen> {
  final _reasonCtrl = TextEditingController();
  int _disputeType = 1;
  bool _isSubmitting = false;
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  static const _types = [
    (1, 'Payment Issue',  Icons.payment),
    (2, 'Delivery Issue', Icons.local_shipping),
    (3, 'Product Issue',  Icons.inventory_2),
    (4, 'Other',          Icons.help_outline),
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(
        imageQuality: 80, maxWidth: 1200, maxHeight: 1200);
    if (picked.isNotEmpty) {
      setState(() {
        // cap at 5 images total
        final remaining = 5 - _photos.length;
        _photos.addAll(picked.take(remaining));
      });
    }
  }

  Future<void> _pickCamera() async {
    final p = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200);
    if (p != null && _photos.length < 5) {
      setState(() => _photos.add(p));
    }
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      _snack('Please enter a reason for your dispute.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);

    final photoBytesList = <List<int>>[];
    final photoNames = <String>[];
    for (final p in _photos) {
      photoBytesList.add(await p.readAsBytes());
      photoNames.add(p.name);
    }

    final result = await AuthService.instance.raiseDispute(
      orderId:      widget.orderId,
      disputeType:  _disputeType,
      reason:       _reasonCtrl.text.trim(),
      photoBytes:   photoBytesList,
      photoNames:   photoNames,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _snack('Dispute submitted successfully.');
      Navigator.pop(context, true); // true = submitted
    } else {
      _snack(result.message ?? 'Failed to submit dispute.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Raise Dispute'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Order reference banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Order: ${widget.orderNumber}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // Dispute Type
          const Text('Dispute Type *',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ..._types.map((t) {
            final selected = _disputeType == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _disputeType = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                      width: selected ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(t.$3,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22),
                  const SizedBox(width: 12),
                  Text(t.$2,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary)),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 20),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Reason
          const Text('Reason *',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines:   5,
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail...',
              hintStyle: const TextStyle(color: AppColors.textHint),
              filled:    true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),

          // Evidence Photos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Evidence Photos (optional)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text('${_photos.length}/5',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),

          // Photo grid
          if (_photos.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photos[i].path),
                          width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_photos.length < 5)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon:  const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon:  const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          const SizedBox(height: 28),

          // Submit
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit Dispute',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Our team will review your dispute within 2-3 business days.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}