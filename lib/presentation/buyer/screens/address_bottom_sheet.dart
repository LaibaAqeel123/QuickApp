import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

/// Shows a bottom sheet for creating or editing an address.
/// Returns the saved address map on success, null on cancel.
///
/// Usage:
///   final result = await AddressBottomSheet.show(context);
///   final result = await AddressBottomSheet.show(context, existing: addressMap);
class AddressBottomSheet extends StatefulWidget {
  /// If provided, the form pre-fills with this address for editing.
  final Map<String, dynamic>? existing;

  const AddressBottomSheet({super.key, this.existing});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? existing,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressBottomSheet(existing: existing),
    );
  }

  @override
  State<AddressBottomSheet> createState() => _AddressBottomSheetState();
}

class _AddressBottomSheetState extends State<AddressBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _streetController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _countryController;

  bool _isDefault  = false;
  int  _addressType = 0; // 0 = Home, 1 = Work, 2 = Other
  bool _isSaving   = false;

  bool get _isEditing => widget.existing != null;

  String? get _existingId =>
      (widget.existing?['id'] ?? widget.existing?['addressId'])?.toString();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelController      = TextEditingController(text: e?['label']?.toString()         ?? '');
    _streetController     = TextEditingController(text: e?['streetAddress']?.toString() ?? '');
    _apartmentController  = TextEditingController(text: e?['apartment']?.toString()     ?? '');
    _cityController       = TextEditingController(text: e?['city']?.toString()          ?? '');
    _stateController      = TextEditingController(text: e?['state']?.toString()         ?? '');
    _postalCodeController = TextEditingController(text: e?['postalCode']?.toString()    ?? '');
    _countryController    = TextEditingController(
        text: e?['country']?.toString().isNotEmpty == true
            ? e!['country'].toString()
            : 'UK');
    _isDefault   = e?['isDefault'] == true;
    _addressType = (e?['addressType'] as num?)?.toInt() ?? 0;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  String? _req(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    ApiResult<Map<String, dynamic>> result;

    if (_isEditing && _existingId != null) {
// Get real GPS coordinates
      double? lat, lng;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {}

      result = await AuthService.instance.updateAddress(
        addressId:     _existingId!,
        streetAddress: _streetController.text.trim(),
        apartment:     _apartmentController.text.trim(),
        city:          _cityController.text.trim(),
        state:         _stateController.text.trim(),
        postalCode:    _postalCodeController.text.trim(),
        country:       _countryController.text.trim(),
        addressType:   _addressType,
        isDefault:     _isDefault,
        label:         _labelController.text.trim(),
        latitude:      lat,
        longitude:     lng,
      );    } else {
      // Get real GPS coordinates
      double? lat, lng;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {}

      result = await AuthService.instance.createAddress(
        streetAddress: _streetController.text.trim(),
        apartment:     _apartmentController.text.trim(),
        city:          _cityController.text.trim(),
        state:         _stateController.text.trim(),
        postalCode:    _postalCodeController.text.trim(),
        country:       _countryController.text.trim(),
        addressType:   _addressType,
        isDefault:     _isDefault,
        label:         _labelController.text.trim(),
        latitude:      lat,
        longitude:     lng,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      // Return whatever the API gave back, or a local map if empty
      final saved = result.data?.isNotEmpty == true
          ? result.data!
          : {
              'id':            _existingId ?? '',
              'label':         _labelController.text.trim(),
              'streetAddress': _streetController.text.trim(),
              'apartment':     _apartmentController.text.trim(),
              'city':          _cityController.text.trim(),
              'state':         _stateController.text.trim(),
              'postalCode':    _postalCodeController.text.trim(),
              'country':       _countryController.text.trim(),
              'addressType':   _addressType,
              'isDefault':     _isDefault,
            };
      Navigator.of(context).pop(saved);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(result.message ?? 'Failed to save address.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                _isEditing ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Form (scrollable for small screens) ──────
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Address Type chips
                    _sectionLabel('Address Type'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TypeChip(
                          label: 'Home',
                          icon:  Icons.home_outlined,
                          selected: _addressType == 0,
                          onTap: () => setState(() => _addressType = 0),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(
                          label: 'Work',
                          icon:  Icons.work_outline,
                          selected: _addressType == 1,
                          onTap: () => setState(() => _addressType = 1),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(
                          label: 'Other',
                          icon:  Icons.location_on_outlined,
                          selected: _addressType == 2,
                          onTap: () => setState(() => _addressType = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Label
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText:  'Label (optional)',
                        hintText:   'e.g. The Restaurant, Office',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Street Address
                    TextFormField(
                      controller: _streetController,
                      validator: (v) => _req(v, 'Street address'),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText:  'Street Address *',
                        hintText:   '123 Main Street',
                        prefixIcon: Icon(Icons.edit_road_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Apartment
                    TextFormField(
                      controller: _apartmentController,
                      decoration: const InputDecoration(
                        labelText:  'Apartment / Suite (optional)',
                        hintText:   'Apt 4B, Floor 2',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // City + State row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cityController,
                            validator: (v) => _req(v, 'City'),
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText:  'City *',
                              hintText:   'London',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _stateController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'County',
                              hintText:  'Essex',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Postcode + Country row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _postalCodeController,
                            validator: (v) => _req(v, 'Postcode'),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText:  'Postcode *',
                              hintText:   'SW1A 1AA',
                              prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _countryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Country',
                              hintText:  'UK',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Set as default toggle
                    GestureDetector(
                      onTap: () => setState(() => _isDefault = !_isDefault),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isDefault
                              ? AppColors.primary.withOpacity(0.08)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isDefault
                                ? AppColors.primary
                                : AppColors.border,
                            width: _isDefault ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isDefault
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _isDefault
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Set as default address',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _isDefault
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Used automatically at checkout',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: AppColors.white, strokeWidth: 2.5),
                              )
                            : Text(_isEditing ? 'Update Address' : 'Save Address'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      );
}

// ── Address Type Chip ──────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}