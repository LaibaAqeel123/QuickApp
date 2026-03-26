import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DocType {
  final String   apiKey;
  final String   label;
  final String   hint;
  final IconData icon;
  const _DocType({
    required this.apiKey,
    required this.label,
    required this.hint,
    required this.icon,
  });
}

const _docTypes = [
  _DocType(
    apiKey: 'DrivingLicense',
    label:  'Driving Licence',
    hint:   'Front & back of your driving licence',
    icon:   Icons.credit_card,
  ),
  _DocType(
    apiKey: 'Insurance',
    label:  'Vehicle Insurance',
    hint:   'Current insurance certificate',
    icon:   Icons.shield_outlined,
  ),
  _DocType(
    apiKey: 'VehicleRegistration',
    label:  'Vehicle Registration',
    hint:   'V5C logbook or registration document',
    icon:   Icons.directions_car_outlined,
  ),
  _DocType(
    apiKey: 'MOT',
    label:  'MOT Certificate',
    hint:   'Current MOT test certificate',
    icon:   Icons.verified_outlined,
  ),
];


class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String? _driverId;
  bool    _loadingDriverId = true;

  final Set<String> _uploading = {};
  final Set<String> _uploaded  = {};

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDriverIdAndDocuments();
  }

 
  Future<void> _loadDriverIdAndDocuments() async {
    final id = await AuthService.instance.getSavedDriverId();
    if (!mounted) return;

    setState(() { _driverId = id; _loadingDriverId = false; });
    if (id == null || id.isEmpty) return;

    // Step 1: restore from SharedPreferences (instant, offline)
    await _restoreFromPrefs(id);

    // Step 2: fetch from server and update
    await _fetchDocumentStatusFromServer(id);
  }

  // ── Persist uploaded set to SharedPreferences ─────────────────────────
  // Key format: docs_uploaded_{driverId}  →  comma-separated apiKeys
  String _prefsKey(String driverId) => 'docs_uploaded_$driverId';

  Future<void> _restoreFromPrefs(String driverId) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final saved   = prefs.getString(_prefsKey(driverId)) ?? '';
      final apiKeys = saved.isEmpty
          ? <String>[]
          : saved.split(',').where((s) => s.isNotEmpty).toList();
      if (apiKeys.isNotEmpty && mounted) {
        setState(() => _uploaded.addAll(apiKeys));
        debugPrint('[Documents]  Restored from prefs: $apiKeys');
      }
    } catch (e) {
      debugPrint('[Documents] prefs restore error: $e');
    }
  }

  Future<void> _saveToPrefs(String driverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(driverId), _uploaded.join(','));
      debugPrint('[Documents]  Saved to prefs: ${_uploaded.toList()}');
    } catch (e) {
      debugPrint('[Documents] prefs save error: $e');
    }
  }


  Future<void> _fetchDocumentStatusFromServer(String driverId) async {
    try {
      debugPrint('[Documents] 🔄 Fetching driver profile for doc status...');
      final result = await AuthService.instance.getDriverProfile(driverId);

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║  GET DRIVER PROFILE (for doc status)');
      debugPrint('║  success: ${result.success}');
      debugPrint('║  data keys: ${result.data?.keys.toList()}');
      debugPrint('╚══════════════════════════════════════╝');

      if (!result.success || result.data == null) return;

      final profile = result.data!;

      // Map of docType apiKey → list of possible field names in the response
      // Adjust these field names if your API uses different keys
      final fieldMap = <String, List<String>>{
        'DrivingLicense':    [
          'licenseImageUrl', 'license_image_url', 'drivingLicenseUrl',
          'driving_license_url', 'licenseDocument', 'licenseDocumentUrl',
        ],
        'Insurance':         [
          'insuranceImageUrl', 'insurance_image_url', 'insuranceUrl',
          'insurance_url', 'insuranceDocument', 'insuranceDocumentUrl',
        ],
        'VehicleRegistration': [
          'vehicleRegistrationUrl', 'vehicle_registration_url',
          'registrationUrl', 'registration_url', 'registrationDocument',
        ],
        'MOT':               [
          'motUrl', 'mot_url', 'motImageUrl', 'mot_image_url',
          'motDocument', 'motDocumentUrl',
        ],
      };

      // Also check a generic "documents" array if the API returns one
      // e.g. { "documents": [{ "documentType": "DrivingLicense", "url": "..." }] }
      final docsArray = profile['documents'] ?? profile['uploadedDocuments'];
      if (docsArray is List) {
        for (final doc in docsArray) {
          if (doc is Map<String, dynamic>) {
            final type = (doc['documentType'] ?? doc['type'] ?? '').toString();
            final url  = (doc['url'] ?? doc['fileUrl'] ?? doc['documentUrl'] ?? '').toString();
            if (type.isNotEmpty && url.isNotEmpty) {
              // Match to one of our apiKeys (case-insensitive)
              for (final apiKey in fieldMap.keys) {
                if (type.toLowerCase() == apiKey.toLowerCase()) {
                  if (mounted) setState(() => _uploaded.add(apiKey));
                  debugPrint('[Documents]  Found from documents array: $apiKey');
                }
              }
            }
          }
        }
      }

      // Check individual URL fields
      for (final entry in fieldMap.entries) {
        final apiKey = entry.key;
        for (final field in entry.value) {
          final val = profile[field]?.toString() ?? '';
          if (val.isNotEmpty && val != 'null') {
            if (mounted) setState(() => _uploaded.add(apiKey));
            debugPrint('[Documents]  Found from field "$field": $apiKey');
            break;
          }
        }
      }

      // Persist whatever the server told us
      if (_driverId != null) await _saveToPrefs(_driverId!);

    } catch (e) {
      debugPrint('[Documents] server doc status fetch error: $e');
    }
  }

  // ── Photo picker — bytes only, no File() ─────────────────────────────
  Future<Uint8List?> _pickImageBytes(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90,
      );
      if (xfile == null) return null;
      return await xfile.readAsBytes();
    } catch (e) {
      debugPrint('[_pickImageBytes] error: $e');
      if (mounted) _snack('Could not pick image: $e', isError: true);
      return null;
    }
  }

  // ── Source chooser ────────────────────────────────────────────────────
  // IMPORTANT: pick bytes BEFORE calling Navigator.pop so the bytes are
  // returned as the sheet's result. Never pop first then pick.
  Future<Uint8List?> _chooseSource() async {
    return showModalBottomSheet<Uint8List?>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Choose Source',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Use your camera'),
              onTap: () async {
                final bytes = await _pickImageBytes(ImageSource.camera);
                if (ctx.mounted) Navigator.pop(ctx, bytes);
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: AppColors.success),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick an existing photo'),
              onTap: () async {
                final bytes = await _pickImageBytes(ImageSource.gallery);
                if (ctx.mounted) Navigator.pop(ctx, bytes);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  // ── Upload ────────────────────────────────────────────────────────────
  Future<void> _upload(_DocType doc) async {
    if (_driverId == null || _driverId!.isEmpty) {
      _snack('Driver ID not found. Please log out and log back in.', isError: true);
      return;
    }

    final Uint8List? bytes = await _chooseSource();
    if (bytes == null || bytes.isEmpty) return;

    setState(() => _uploading.add(doc.apiKey));

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  UPLOAD DOCUMENT — REQUEST');
    debugPrint('║  driverId    : $_driverId');
    debugPrint('║  documentType: ${doc.apiKey}');
    debugPrint('║  bytes       : ${bytes.length}');
    debugPrint('╚══════════════════════════════════════╝');

    final result = await AuthService.instance.uploadDriverDocument(
      driverId:     _driverId!,
      documentType: doc.apiKey,
      fileBytes:    bytes,
      fileName:     '${doc.apiKey.toLowerCase()}.jpg',
    );

    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  UPLOAD DOCUMENT — RESPONSE');
    debugPrint('║  success: ${result.success}');
    debugPrint('║  message: ${result.message}');
    debugPrint('╚══════════════════════════════════════╝');

    if (!mounted) return;
    setState(() => _uploading.remove(doc.apiKey));

    if (result.success) {
      setState(() => _uploaded.add(doc.apiKey));
      // Persist so it survives re-login (SharedPreferences layer)
      await _saveToPrefs(_driverId!);
      _snack('${doc.label} uploaded successfully');
    } else {
      _snack(result.message ?? 'Upload failed. Please try again.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

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
      body: _loadingDriverId
          ? const Center(child: CircularProgressIndicator())
          : _driverId == null
              ? _NoDriverId(onRetry: _loadDriverIdAndDocuments)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please upload clear, readable photos of your '
                                'documents. Accepted formats: JPG, PNG (max 5 MB each).',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary.withOpacity(0.9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text('Required Documents',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),

                      ..._docTypes.map((doc) => _DocumentCard(
                            doc:         doc,
                            isUploading: _uploading.contains(doc.apiKey),
                            isUploaded:  _uploaded.contains(doc.apiKey),
                            onUpload:    () => _upload(doc),
                          )),

                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Documents are reviewed within 1–2 business days.',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Document Card
// ─────────────────────────────────────────────────────────
class _DocumentCard extends StatelessWidget {
  final _DocType     doc;
  final bool         isUploading;
  final bool         isUploaded;
  final VoidCallback onUpload;

  const _DocumentCard({
    required this.doc,
    required this.isUploading,
    required this.isUploaded,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = isUploaded ? AppColors.success : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded ? AppColors.success.withOpacity(0.5) : AppColors.border,
          width: isUploaded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [

          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isUploaded ? Icons.check_circle : doc.icon,
                color: accent, size: 26),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.label,
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(doc.hint,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (isUploaded) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.check_circle, size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  const Text('Uploaded successfully',
                      style: TextStyle(fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
          ),
          const SizedBox(width: 12),

          isUploading
              ? const SizedBox(width: 36, height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUploaded ? AppColors.success : AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(isUploaded ? 'Replace' : 'Upload',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  No Driver ID fallback
// ─────────────────────────────────────────────────────────
class _NoDriverId extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoDriverId({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Driver profile not found.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Please log out and log back in to refresh your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}