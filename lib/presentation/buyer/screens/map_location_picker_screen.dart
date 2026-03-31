import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Polygon;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ══════════════════════════════════════════════════════════
//  MapLocationPickerScreen
// ══════════════════════════════════════════════════════════
class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({super.key});

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  LatLng _pickedLocation = const LatLng(51.5074, -0.1278);

  Map<String, dynamic>? _geocodeResult;
  bool _isGeocoding = false;
  bool _isLocating  = false;
  bool _mapReady    = false;
  bool _isDragging  = false;

  DateTime? _lastGeocode;

  @override
  void initState() {
    super.initState();
    _acquireInitialLocation();
  }

  Future<void> _acquireInitialLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await _getGpsPosition();
      if (pos != null && mounted) {
        setState(() {
          _pickedLocation = LatLng(pos.latitude, pos.longitude);
          _isLocating     = false;
        });
        if (_mapReady) _mapController.move(_pickedLocation, 16);
        await _reverseGeocode(_pickedLocation);
      } else {
        if (mounted) setState(() => _isLocating = false);
        await _reverseGeocode(_pickedLocation);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
      await _reverseGeocode(_pickedLocation);
    }
  }

  Future<Position?> _getGpsPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Location request timed out'),
    );
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await _getGpsPosition();
      if (pos != null && mounted) {
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _pickedLocation = ll;
          _isLocating     = false;
        });
        _mapController.move(ll, 17);
        await _reverseGeocode(ll);
      } else {
        if (mounted) setState(() => _isLocating = false);
        _showSnack('Could not get your location. Check GPS settings.');
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
      _showSnack('Location error: ${e.toString()}');
    }
  }

  Future<void> _reverseGeocode(LatLng ll) async {
    final now = DateTime.now();
    if (_lastGeocode != null &&
        now.difference(_lastGeocode!).inMilliseconds < 600) return;
    _lastGeocode = now;
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${ll.latitude}&lon=${ll.longitude}'
        '&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent':      'FoodDeliveryApp/1.0 (contact@yourdomain.com)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _geocodeResult = data;
          _isGeocoding   = false;
        });
      } else {
        setState(() => _isGeocoding = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Map<String, dynamic> _buildAddressMap() {
    final addr =
        (_geocodeResult?['address'] as Map?)?.cast<String, dynamic>() ??
            {};
    final display = _geocodeResult?['display_name']?.toString() ?? '';

    final road    = addr['road']        ?? addr['pedestrian'] ??
                    addr['path']        ?? addr['footway']    ?? '';
    final houseNo = addr['house_number'] ?? '';
    final street  = houseNo.isNotEmpty
        ? '$houseNo $road'.trim()
        : road.toString().trim();
    final suburb  = addr['suburb']       ?? addr['neighbourhood'] ??
                    addr['hamlet']       ?? addr['quarter']       ?? '';
    final streetAddress = street.isNotEmpty
        ? street
        : suburb.isNotEmpty
            ? suburb.toString()
            : display.split(',').first.trim();

    final city     = (addr['city']    ?? addr['town']    ??
                      addr['village'] ?? addr['county']  ??
                      addr['state_district'] ?? '').toString();
    final postcode = (addr['postcode'] ?? '').toString();
    final state    = (addr['state']    ?? '').toString();
    final country  = (addr['country']  ?? 'UK').toString();

    return {
      'streetAddress': streetAddress,
      'apartment':     '',
      'city':          city,
      'state':         state,
      'postalCode':    postcode,
      'country':       country,
      'label':         'Current Location',
      'addressType':   2,
      'isDefault':     false,
      'latitude':      _pickedLocation.latitude,
      'longitude':     _pickedLocation.longitude,
      '_displayName':  display,
      '_isMapPicked':  true,
    };
  }

  String get _shortAddress {
    if (_isGeocoding) return 'Finding address…';
    if (_geocodeResult == null) return 'Move the pin to pick a location';
    final addr  = _buildAddressMap();
    final parts = <String>[
      if ((addr['streetAddress'] as String).isNotEmpty)
        addr['streetAddress'] as String,
      if ((addr['city']         as String).isNotEmpty)
        addr['city']          as String,
      if ((addr['postalCode']   as String).isNotEmpty)
        addr['postalCode']    as String,
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'Unknown address';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Safe area top inset so we can position the FAB just below
    // the AppBar without hard-coding pixel values.
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: IconButton(
            icon:      const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: const Text(
            'Pick Location',
            style: TextStyle(
                color:      Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize:   16),
          ),
        ),
        centerTitle: true,
        // ── The "my location" FAB lives inside actions so it stays
        //    in the AppBar row, right-aligned, always visible above
        //    the map — no Positioned needed at all.
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: _LocationFab(
              isLocating: _isLocating,
              onTap:      _goToMyLocation,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom:   15,
              onMapReady: () {
                setState(() => _mapReady = true);
                if (!_isLocating) {
                  _mapController.move(_pickedLocation, 16);
                }
              },
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (hasGesture && position.center != null) {
                  setState(() {
                    _pickedLocation = position.center!;
                    _isDragging     = true;
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  setState(() => _isDragging = false);
                  _reverseGeocode(_pickedLocation);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.food_delivery_app',
                maxZoom: 19,
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),

          // ── Fixed centre pin ────────────────────────────
          _CentrePin(isDragging: _isDragging),

          // ── Locating overlay ────────────────────────────
          if (_isLocating)
            const Positioned.fill(child: _LocatingOverlay()),

          // ── Bottom address card ─────────────────────────
          Positioned(
            left:   0,
            right:  0,
            bottom: 0,
            child: _BottomCard(
              address:     _shortAddress,
              isGeocoding: _isGeocoding,
              onConfirm:   _geocodeResult == null
                  ? null
                  : () => Navigator.pop(context, _buildAddressMap()),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Centre pin
// ══════════════════════════════════════════════════════════
class _CentrePin extends StatelessWidget {
  final bool isDragging;
  const _CentrePin({required this.isDragging});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform:
                Matrix4.translationValues(0, isDragging ? -12 : 0, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  isDragging ? 52 : 44,
                  height: isDragging ? 52 : 44,
                  decoration: BoxDecoration(
                    color:  const Color(0xFFE53935),
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color:       const Color(0xFFE53935).withOpacity(0.4),
                        blurRadius:  isDragging ? 20 : 10,
                        spreadRadius: isDragging ? 4  : 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 24),
                ),
                CustomPaint(
                  size: const Size(16, 10),
                  painter: _PinTailPainter(),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:  isDragging ? 16 : 8,
            height: isDragging ? 8  : 4,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color:        Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, Size size) {
    final paint = ui.Paint()
      ..color = const Color(0xFFE53935)
      ..style = ui.PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter old) => false;
}

// ══════════════════════════════════════════════════════════
//  Location FAB  (compact — used inside AppBar actions)
// ══════════════════════════════════════════════════════════
class _LocationFab extends StatelessWidget {
  final bool         isLocating;
  final VoidCallback onTap;
  const _LocationFab({required this.isLocating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocating ? null : onTap,
      child: Container(
        width:  44,
        height: 44,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color:      Colors.black26,
                blurRadius: 8,
                offset:     Offset(0, 3)),
          ],
        ),
        child: isLocating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location,
                color: Color(0xFFE53935), size: 22),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Bottom address card
// ══════════════════════════════════════════════════════════
class _BottomCard extends StatelessWidget {
  final String        address;
  final bool          isGeocoding;
  final VoidCallback? onConfirm;

  const _BottomCard({
    required this.address,
    required this.isGeocoding,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black26,
              blurRadius: 20,
              offset:     Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize:        MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width:  40, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Selected Location',
            style: TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.w600,
                color:         Colors.grey,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        const Color(0xFFE53935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on,
                    color: Color(0xFFE53935), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isGeocoding
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color:       Color(0xFFE53935)),
                          ),
                          SizedBox(width: 8),
                          Text('Finding address…',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                        ]),
                      )
                    : Text(
                        address,
                        style: const TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w600,
                            color:      Colors.black87,
                            height:     1.4),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 52),
            child: Text(
              'Drag the map to adjust the pin',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: onConfirm != null
                    ? const Color(0xFFE53935)
                    : Colors.grey[300],
                foregroundColor: Colors.white,
                elevation:   onConfirm != null ? 4 : 0,
                shadowColor: const Color(0xFFE53935).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: onConfirm != null ? Colors.white : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Confirm This Location',
                    style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold,
                        color: onConfirm != null
                            ? Colors.white
                            : Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Locating overlay
// ══════════════════════════════════════════════════════════
class _LocatingOverlay extends StatelessWidget {
  const _LocatingOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color:        Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Getting your location…',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}