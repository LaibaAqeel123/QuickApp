import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/address_bottom_sheet.dart';

/// Full-page address management screen.
/// Pass [selectionMode] = true when navigating from checkout so
/// the user can pick an address and it gets returned as a pop result.
class AddressScreen extends StatefulWidget {
  final bool selectionMode;

  const AddressScreen({super.key, this.selectionMode = false});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  // ── Safe field helpers ─────────────────────────────────
  String _id(Map<String, dynamic> a) =>
      (a['id'] ?? a['addressId'] ?? '').toString();

  String _label(Map<String, dynamic> a) {
    final label = a['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    final type = (a['addressType'] as num?)?.toInt() ?? 0;
    return ['Home', 'Work', 'Other'][type.clamp(0, 2)];
  }

  String _fullAddress(Map<String, dynamic> a) {
    final parts = <String>[
      if ((a['streetAddress'] ?? '').toString().isNotEmpty)
        a['streetAddress'].toString(),
      if ((a['apartment'] ?? '').toString().isNotEmpty)
        a['apartment'].toString(),
      if ((a['city'] ?? '').toString().isNotEmpty) a['city'].toString(),
      if ((a['postalCode'] ?? '').toString().isNotEmpty)
        a['postalCode'].toString(),
      if ((a['country'] ?? '').toString().isNotEmpty) a['country'].toString(),
    ];
    return parts.join(', ');
  }

  bool _isDefault(Map<String, dynamic> a) => a['isDefault'] == true;

  int _addressType(Map<String, dynamic> a) =>
      ((a['addressType'] as num?)?.toInt() ?? 0).clamp(0, 2);

  IconData _typeIcon(int type) {
    switch (type) {
      case 1:  return Icons.work_outline;
      case 2:  return Icons.location_on_outlined;
      default: return Icons.home_outlined;
    }
  }

  // ── Load ───────────────────────────────────────────────
  Future<void> _loadAddresses() async {
    setState(() { _isLoading = true; _error = null; });

    final result = await AuthService.instance.getAddresses();

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _addresses = (result.data ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error     = result.message;
      });
    }
  }

  // ── Add ────────────────────────────────────────────────
  Future<void> _addAddress() async {
    final saved = await AddressBottomSheet.show(context);
    if (saved != null) {
      _showSnackBar('Address saved successfully!');
      await _loadAddresses();
    }
  }

  // ── Edit ───────────────────────────────────────────────
  Future<void> _editAddress(Map<String, dynamic> address) async {
    final saved = await AddressBottomSheet.show(context, existing: address);
    if (saved != null) {
      _showSnackBar('Address updated successfully!');
      await _loadAddresses();
    }
  }

  // ── Delete ─────────────────────────────────────────────
  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final id = _id(address);
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text(
            'Remove "${_label(address)}" from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Optimistic removal
    final idx = _addresses.indexOf(address);
    setState(() => _addresses.removeAt(idx));

    final result = await AuthService.instance.deleteAddress(id);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar('Address deleted.');
    } else {
      // Revert
      setState(() => _addresses.insert(idx, address));
      _showSnackBar(result.message ?? 'Failed to delete address.', isError: true);
    }
  }

  // ── Set default ────────────────────────────────────────
  Future<void> _setDefault(Map<String, dynamic> address) async {
    if (_isDefault(address)) return;
    final id = _id(address);
    if (id.isEmpty) return;

    // Optimistic update — flip all isDefault flags
    setState(() {
      for (final a in _addresses) {
        a['isDefault'] = a == address;
      }
    });

    final result = await AuthService.instance.setDefaultAddress(id);

    if (!mounted) return;

    if (!result.success) {
      // Revert
      await _loadAddresses();
      _showSnackBar(result.message ?? 'Failed to set default.', isError: true);
    } else {
      _showSnackBar('Default address updated.');
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Select Address' : 'My Addresses'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAddress,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon:  const Icon(Icons.add_location_alt),
        label: const Text('Add Address'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadAddresses)
              : _addresses.isEmpty
                  ? _EmptyView(onAdd: _addAddress)
                  : RefreshIndicator(
                      onRefresh: _loadAddresses,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          return _AddressCard(
                            label:       _label(address),
                            fullAddress: _fullAddress(address),
                            isDefault:   _isDefault(address),
                            typeIcon:    _typeIcon(_addressType(address)),
                            selectionMode: widget.selectionMode,
                            onTap: widget.selectionMode
                                ? () => Navigator.of(context).pop(address)
                                : () => _editAddress(address),
                            onEdit:      () => _editAddress(address),
                            onDelete:    () => _deleteAddress(address),
                            onSetDefault: () => _setDefault(address),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ADDRESS CARD
// ══════════════════════════════════════════════════════════
class _AddressCard extends StatelessWidget {
  final String   label;
  final String   fullAddress;
  final bool     isDefault;
  final IconData typeIcon;
  final bool     selectionMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.label,
    required this.fullAddress,
    required this.isDefault,
    required this.typeIcon,
    required this.selectionMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefault ? AppColors.primary : AppColors.border,
            width: isDefault ? 2 : 1,
          ),
          boxShadow: isDefault
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDefault
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon,
                        size: 22,
                        color: isDefault
                            ? AppColors.primary
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Default',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(fullAddress,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),

                  // Chevron for selection mode
                  if (selectionMode)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 4),
                      child: Icon(Icons.arrow_forward_ios,
                          size: 16, color: AppColors.textHint),
                    ),
                ],
              ),
            ),

            // Action bar (only shown outside selection mode)
            if (!selectionMode) ...[
              Divider(height: 1, color: AppColors.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Set default
                    if (!isDefault)
                      _ActionButton(
                        icon:  Icons.check_circle_outline,
                        label: 'Set Default',
                        color: AppColors.primary,
                        onTap: onSetDefault,
                      ),

                    const Spacer(),

                    // Edit
                    _ActionButton(
                      icon:  Icons.edit_outlined,
                      label: 'Edit',
                      color: AppColors.textSecondary,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 4),

                    // Delete
                    _ActionButton(
                      icon:  Icons.delete_outline,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon:  Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      style: TextButton.styleFrom(
        padding:   const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  EMPTY VIEW
// ══════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_outlined,
                  size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('No Saved Addresses',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'Add your delivery addresses to speed up checkout.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon:  const Icon(Icons.add_location_alt),
              label: const Text('Add First Address'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  ERROR VIEW
// ══════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}