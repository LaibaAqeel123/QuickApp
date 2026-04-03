import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:food_delivery_app/presentation/buyer/screens/dispute_form_screen.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/itransport.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool    _isLoading = true;
  String? _error;
  bool    _isFullScreen = false;

  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng? _deliveryLocation;
  double? _etaMinutes;
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  HubConnection? _hubConnection;
  bool _isConnected    = false;
  bool _isDriverEnRoute = false;

  Timer? _pollTimer;
  bool _signalRDeliveredLocation = false;

  // ── FIX 2: track the effective display status separately ──
  // This allows delivery-record status to override order status
  // for the "Out for Delivery" midpoint that the order status API
  // misses when the driver confirms pickup.
  String? _effectiveStatus; // null = use _statusLabel from order data

  late AnimationController _pulseController;
  late Animation<double>    _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    _hubConnection?.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Map<String, dynamic> get _src => _detail ?? widget.order;

  String get _orderId =>
      (_src['id'] ?? _src['orderId'] ?? _src['orderNumber'] ?? '').toString();

  String get _orderNumber =>
      (_src['orderNumber'] ?? _src['id'] ?? _src['orderId'] ?? '').toString();

  String get _deliveryId => (_src['deliveryId'] ?? '').toString();

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return raw.toString(); }
  }

  String _fmtTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h  = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
    } catch (_) { return raw.toString(); }
  }

  String get _statusLabel {
    final raw = _src['status'] ?? _src['orderStatus'];
    if (raw is String) return raw;
    if (raw is int) {
      switch (raw) {
        case 1: return 'Processing';
        case 2: return 'Confirmed';
        case 3: return 'Processing';
        case 4: return 'Sent to Driver';
        case 5: return 'Delivered';
        case 6: return 'Delivered';
        case 7: return 'Cancelled';
        case 8: return 'Out for Delivery';
      }
    }
    return 'Processing';
  }

  // ── FIX 2: This is what we actually show in the UI.
  // If the delivery record says the driver picked up (Out for Delivery),
  // we show that even if the order status API hasn't caught up yet.
  String get _displayStatus => _effectiveStatus ?? _statusLabel;

  String get _supplierName {
    final top = _src['supplierName']?.toString() ?? '';
    if (top.isNotEmpty) return top;

    final supplierObj = _src['supplier'];
    if (supplierObj is Map) {
      final n = supplierObj['name']?.toString() ?? '';
      if (n.isNotEmpty) return n;
    }

    for (final key in ['items', 'orderItems']) {
      final list = _src[key];
      if (list is List && list.isNotEmpty) {
        final firstItem = list.first;
        if (firstItem is Map) {
          final n = firstItem['supplierName']?.toString() ?? '';
          if (n.isNotEmpty) {
            debugPrint('🏪 [supplierName] found in $key[0].supplierName: $n');
            return n;
          }
          final itemSupplier = firstItem['supplier'];
          if (itemSupplier is Map) {
            final ns = itemSupplier['name']?.toString() ?? '';
            if (ns.isNotEmpty) return ns;
          }
        }
      }
    }

    final vendor = _src['vendor']?.toString() ?? '';
    if (vendor.isNotEmpty) return vendor;

    return 'Supplier';
  }

  List<Map<String, dynamic>> get _orderItems {
    final items = _src['items'] ?? _src['orderItems'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  int get _itemCount {
    if (_orderItems.isNotEmpty) return _orderItems.length;
    final c = _src['itemCount'] ?? _src['totalItems'];
    return c is num ? c.toInt() : 0;
  }

  double get _total =>
      ((_src['total'] ?? _src['totalAmount'] ?? _src['grandTotal'] ?? 0) as num)
          .toDouble();

  double get _subtotal =>
      ((_src['subtotal'] ?? _src['subtotalAmount'] ?? 0) as num).toDouble();

  double get _deliveryFee =>
      ((_src['deliveryFee'] ?? _src['delivery_fee'] ?? 0) as num).toDouble();

  double get _tax =>
      ((_src['tax'] ?? _src['taxAmount'] ?? 0) as num).toDouble();

  String? get _deliveryAddress {
    final addr = _src['deliveryAddress'];
    if (addr == null) return null;
    if (addr is String) return addr;
    if (addr is Map) {
      final parts = [
        addr['streetAddress'],
        addr['apartment'],
        addr['city'],
        addr['postalCode'],
        addr['country'],
      ].where((p) => p != null && p.toString().isNotEmpty);
      return parts.join(', ');
    }
    return null;
  }

  Map<String, dynamic>? get _driver =>
      _src['driver'] as Map<String, dynamic>?;

  bool get _isSupplierDelivery =>
      _src['isSupplierDelivery'] == true;

  String? get _estimatedDeliveryTime =>
      _src['estimatedDeliveryTime']?.toString();

  String _fmtDateTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h  = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m  = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}, $h:$m $ampm';
    } catch (_) { return raw.toString(); }
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  bool _isAtLeast(String min) {
    const order = ['processing', 'out for delivery', 'delivered'];
    var curLabel = _displayStatus.toLowerCase();
    if (curLabel == 'completed' || curLabel == 'sent to driver') {
      curLabel = 'processing';
    }
    final cur = order.indexOf(curLabel);
    final m   = order.indexOf(min.toLowerCase());
    if (cur == -1 || m == -1) return false;
    return cur >= m;
  }

  bool _computeDriverEnRoute() {
    if (_isSupplierDelivery) return false;
    final s = _displayStatus.toLowerCase();
    return s == 'out for delivery';
  }

  // ── FIX 2: Expanded pickup detection ──────────────────
  // Checks both the delivery status string AND numeric codes
  // so that when the driver confirms pickup, we immediately
  // surface "Out for Delivery" even before the order-status
  // API reflects it.
  bool _isPickedUpFromDelivery(Map<String, dynamic>? d) {
    if (d == null) return false;
    final raw =
    (d['deliveryStatus'] ?? d['status'] ?? '').toString().toLowerCase().trim();

    // Numeric string check
    if (raw == '4') return true;

    // Normalised string check
    final normalised = raw.replaceAll(RegExp(r'[\s_\-]'), '');
    return normalised == 'pickedup'   ||
           normalised == 'pickeddup'  ||
           normalised == 'intransit'  ||
           normalised == 'ontheway'   ||
           normalised == 'enroute'    ||
           normalised == 'outfordelivery' ||
           normalised == 'out_for_delivery';
  }

  // ── FIX 2: Check if delivery record says "delivered" ──
  bool _isDeliveredFromDelivery(Map<String, dynamic>? d) {
    if (d == null) return false;
    final raw =
    (d['deliveryStatus'] ?? d['status'] ?? '').toString().toLowerCase().trim();
    if (raw == '5') return true;
    final normalised = raw.replaceAll(RegExp(r'[\s_\-]'), '');
    return normalised == 'delivered' ||
           normalised == 'completed' ||
           normalised == 'done';
  }

  String _formatEta(double minutes) {
    if (minutes < 60) return '${minutes.toStringAsFixed(0)} min';
    final hours = (minutes / 60).floor();
    final mins  = (minutes % 60).toStringAsFixed(0);
    return '${hours}h ${mins}min';
  }

  Future<void> _fetchRoute() async {
    if (_driverLocation == null || _deliveryLocation == null) return;
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;
    try {
      final servers = [
        'https://router.project-osrm.org',
        'https://routing.openstreetmap.de',
      ];
      List<LatLng>? points;
      for (final server in servers) {
        try {
          final url = '$server/route/v1/driving/'
              '${_driverLocation!.longitude},${_driverLocation!.latitude};'
              '${_deliveryLocation!.longitude},${_deliveryLocation!.latitude}'
              '?overview=full&geometries=geojson';
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['code'] == 'Ok' &&
                (data['routes'] as List).isNotEmpty) {
              final coords =
              data['routes'][0]['geometry']['coordinates'] as List;
              points = coords
                  .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
                  .toList();
              break;
            }
          }
        } catch (e) { continue; }
      }
      if (mounted) {
        setState(() => _routePoints =
        (points != null && points.length >= 2)
            ? points
            : [_driverLocation!, _deliveryLocation!]);
      }
    } catch (e) {
      if (_driverLocation != null && _deliveryLocation != null && mounted) {
        setState(() => _routePoints = [_driverLocation!, _deliveryLocation!]);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  Future<void> _load() async {
    if (_orderId.isEmpty) {
      setState(() { _isLoading = false; _error = 'Invalid order ID.'; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    final r = await AuthService.instance.getMyOrderById(_orderId);
    if (!mounted) return;

    if (r.success && r.data != null) {
      setState(() {
        _detail    = r.data;
        _isLoading = false;
      });

      final addr = _detail?['deliveryAddress'];
      if (addr != null && addr is Map) {
        final lat = (addr['latitude'] as num?)?.toDouble();
        final lng = (addr['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          setState(() => _deliveryLocation = LatLng(lat, lng));
        }
      }

      // ── FIX 2: Always fetch the delivery record so we can
      // detect the pickup/out-for-delivery status even when the
      // order-status API hasn't updated yet.
      final deliveryResult =
      await AuthService.instance.getDeliveryByOrderId(_orderId);
      if (deliveryResult.success && deliveryResult.data != null) {
        final delivery = deliveryResult.data!;
        final dId = delivery['deliveryId']?.toString() ?? '';
        if (dId.isNotEmpty) {
          setState(() => _detail = {...?_detail, 'deliveryId': dId});
        }

        // Determine effective display status from delivery record
        _applyDeliveryStatus(delivery);

        final driverPickedUp = _isPickedUpFromDelivery(delivery);
        _tryUpdateLocationFromDelivery(delivery);

        if (driverPickedUp && dId.isNotEmpty) {
          setState(() => _isDriverEnRoute = true);
          _startPolling();
          await _connectSignalR();
        } else {
          // Even if not yet picked up, recompute enRoute from effective status
          setState(() => _isDriverEnRoute = _computeDriverEnRoute());
        }
      } else {
        setState(() => _isDriverEnRoute = _computeDriverEnRoute());
      }
    } else {
      setState(() { _isLoading = false; _error = r.message; });
    }
  }

  // ── FIX 2: Apply the delivery record's status as the effective
  // display status so "Out for Delivery" appears immediately when
  // the driver confirms pickup, without waiting for the order API.
  void _applyDeliveryStatus(Map<String, dynamic> delivery) {
    if (_isDeliveredFromDelivery(delivery)) {
      if (mounted) {
        setState(() {
          _effectiveStatus = 'Delivered';
          _isDriverEnRoute = false;
          _driverLocation  = null;
          _etaMinutes      = null;
          _routePoints     = [];
        });
      }
      return;
    }

    if (_isPickedUpFromDelivery(delivery)) {
      if (mounted) {
        setState(() {
          _effectiveStatus = 'Out for Delivery';
          _isDriverEnRoute = !_isSupplierDelivery;
        });
      }
      return;
    }

    // Otherwise keep the order's own status (don't set _effectiveStatus)
  }

  void _tryUpdateLocationFromDelivery(Map<String, dynamic> delivery) {
    final lat = (delivery['driverLatitude'] ??
        delivery['currentLatitude'] ??
        delivery['latitude'] as num?)
        ?.toDouble();
    final lng = (delivery['driverLongitude'] ??
        delivery['currentLongitude'] ??
        delivery['longitude'] as num?)
        ?.toDouble();
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0 && mounted) {
      setState(() {
        _driverLocation  = LatLng(lat, lng);
        _isDriverEnRoute = true;
      });
      _fetchRoute();
      try { _mapController.move(_driverLocation!, 15); } catch (_) {}
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !_isDriverEnRoute) return;
      if (_signalRDeliveredLocation) return;
      final result = await AuthService.instance.getDeliveryByOrderId(_orderId);
      if (!mounted) return;
      if (result.success && result.data != null) {
        final delivery = result.data!;
        _applyDeliveryStatus(delivery);

        if (_isDeliveredFromDelivery(delivery)) {
          _pollTimer?.cancel();
          return;
        }
        _tryUpdateLocationFromDelivery(delivery);
      }
    });
  }

  void _handleLocationArgs(String eventName, List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    try {
      double? lat, lng, eta;
      final first = args[0];
      if (first is Map<String, dynamic>) {
        lat = (first['latitude'] as num?)?.toDouble();
        lng = (first['longitude'] as num?)?.toDouble();
        eta = (first['etaMinutes'] as num?)?.toDouble();
        if (lat == null) {
          final loc = first['location'];
          if (loc is Map<String, dynamic>) {
            lat = (loc['latitude'] as num?)?.toDouble();
            lng = (loc['longitude'] as num?)?.toDouble();
          }
        }
      } else if (first is num) {
        lat = first.toDouble();
        lng = args.length > 1 ? (args[1] as num?)?.toDouble() : null;
      }
      if (lat != null && lng != null && mounted) {
        _signalRDeliveredLocation = true;
        final prev = _driverLocation;
        setState(() {
          _driverLocation  = LatLng(lat!, lng!);
          if (eta != null && eta > 0 && eta < 600) _etaMinutes = eta;
          _isDriverEnRoute = true;
          // ── FIX 2: SignalR sending location = driver is en-route
          if (_effectiveStatus != 'Delivered') {
            _effectiveStatus = 'Out for Delivery';
          }
        });
        if (prev == null ||
            (_driverLocation!.latitude - prev.latitude).abs() > 0.001 ||
            (_driverLocation!.longitude - prev.longitude).abs() > 0.001) {
          _fetchRoute();
        }
        try { _mapController.move(_driverLocation!, 15); } catch (_) {}
      }
    } catch (e) { debugPrint('❌ [$eventName] parse error: $e'); }
  }

  void _registerHubListeners(HubConnection hub) {
    const locationEvents = [
      'LocationUpdated','ReceiveLocation','DriverLocationUpdated',
      'UpdateLocation','SendLocation','location','driverLocation',
      'DriverLocation','TrackingUpdate','BroadcastLocation',
      'LocationBroadcast','DriverUpdate','LiveLocation','GpsUpdate',
    ];
    for (final name in locationEvents) {
      hub.on(name, (args) => _handleLocationArgs(name, args));
    }
    for (final name in ['DeliveryStatusChanged','StatusUpdated','DeliveryUpdated']) {
      hub.on(name, (args) {
        if (args == null || args.isEmpty) return;
        try {
          final data = args[0];
          if (data is Map<String, dynamic>) {
            final s = (data['status'] ?? data['deliveryStatus'] ?? '')
                .toString().toLowerCase();
            if ((s == 'delivered' || s == '5') && mounted) {
              setState(() {
                _effectiveStatus = 'Delivered';
                _isDriverEnRoute = false;
                _driverLocation  = null;
                _etaMinutes      = null;
                _routePoints     = [];
              });
              _pollTimer?.cancel();
            } else if ((s == 'pickedup' || s == 'outfordelivery' ||
                        s == 'intransit' || s == '4') && mounted) {
              // ── FIX 2: Catch pickup event from SignalR too
              setState(() {
                _effectiveStatus = 'Out for Delivery';
                _isDriverEnRoute = !_isSupplierDelivery;
              });
            }
          }
        } catch (e) { debugPrint('❌ [$name] error: $e'); }
      });
    }
  }

  Future<void> _resubscribe(HubConnection hub, String delivId) async {
    final orderId = _orderId;
    const methods = [
      'SubscribeToDelivery','JoinDeliveryGroup','JoinGroup',
      'Subscribe','JoinRoom','TrackDelivery','WatchDelivery',
    ];
    for (final method in methods) {
      try { await hub.invoke(method, args: [delivId]); } catch (_) {}
    }
    if (orderId.isNotEmpty && orderId != delivId) {
      for (final method in methods) {
        try { await hub.invoke(method, args: [orderId]); } catch (_) {}
      }
    }
  }

  Future<bool> _tryConnect({
    required String            token,
    required String            delivId,
    required HttpTransportType transport,
    required bool              skipNegotiation,
    required String            label,
  }) async {
    HubConnection? hub;
    try {
      hub = HubConnectionBuilder()
          .withUrl(
        'https://api.neptasolutions.co.uk/hubs/delivery-tracking'
            '?access_token=$token',
        options: HttpConnectionOptions(
          transport:       transport,
          skipNegotiation: skipNegotiation,
        ),
      )
          .withAutomaticReconnect()
          .build();
      hub.serverTimeoutInMilliseconds     = 30000;
      hub.keepAliveIntervalInMilliseconds = 15000;
      _registerHubListeners(hub);
      hub.onreconnected(({connectionId}) => _resubscribe(hub!, delivId));
      hub.onclose(({error}) {
        if (mounted) setState(() => _isConnected = false);
      });
      await hub.start();
      _hubConnection = hub;
      if (mounted) setState(() => _isConnected = true);
      await _resubscribe(hub, delivId);
      return true;
    } catch (e) {
      try { await hub?.stop(); } catch (_) {}
      return false;
    }
  }

  Future<void> _connectSignalR() async {
    final delivId = _deliveryId;
    if (delivId.isEmpty) return;
    final token = await AuthService.instance.getAccessToken();
    if (token == null) return;

    await _tryConnect(
        token: token, delivId: delivId,
        transport: HttpTransportType.WebSockets,
        skipNegotiation: true, label: 'WebSockets+skipNeg') ||
        await _tryConnect(
            token: token, delivId: delivId,
            transport: HttpTransportType.WebSockets,
            skipNegotiation: false, label: 'WebSockets') ||
        await _tryConnect(
            token: token, delivId: delivId,
            transport: HttpTransportType.LongPolling,
            skipNegotiation: false, label: 'LongPolling');
  }

  LatLng get _mapCenter {
    if (_driverLocation != null && _deliveryLocation != null) {
      return LatLng(
        (_driverLocation!.latitude  + _deliveryLocation!.latitude)  / 2,
        (_driverLocation!.longitude + _deliveryLocation!.longitude) / 2,
      );
    }
    if (_driverLocation   != null) return _driverLocation!;
    if (_deliveryLocation != null) return _deliveryLocation!;
    return const LatLng(31.5204, 74.3587);
  }

  double get _mapZoom {
    if (_driverLocation == null || _deliveryLocation == null) return 14;
    final latDiff = (_driverLocation!.latitude  - _deliveryLocation!.latitude).abs();
    final lngDiff = (_driverLocation!.longitude - _deliveryLocation!.longitude).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff > 5)   return 6;
    if (maxDiff > 2)   return 8;
    if (maxDiff > 1)   return 9;
    if (maxDiff > 0.5) return 11;
    if (maxDiff > 0.1) return 13;
    return 14;
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _buildMap({bool fullScreen = false}) {
    final height = fullScreen ? MediaQuery.of(context).size.height : 300.0;
    return SizedBox(
      height: height,
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
              initialCenter: _mapCenter, initialZoom: _mapZoom),
          children: [
            TileLayer(
              urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.food_delivery_app',
              additionalOptions: const {'s': 'abcd'},
            ),
            if (_routePoints.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                    points: _routePoints,
                    strokeWidth: 6.0,
                    color: Colors.black.withOpacity(0.12)),
                Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: AppColors.primary),
              ]),
            MarkerLayer(markers: [
              if (_deliveryLocation != null)
                Marker(
                  point: _deliveryLocation!,
                  width: 60, height: 70,
                  child: Column(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: AppColors.success.withOpacity(0.4),
                            blurRadius: 10, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.home,
                          color: Colors.white, size: 24),
                    ),
                    Container(width: 3, height: 10, color: AppColors.success),
                  ]),
                ),
              if (_driverLocation != null)
                Marker(
                  point: _driverLocation!,
                  width: 70, height: 70,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width:  60 * _pulseAnimation.value,
                          height: 60 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(
                                0.2 / _pulseAnimation.value),
                          ),
                        ),
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 10, spreadRadius: 2)],
                          ),
                          child: const Icon(Icons.delivery_dining,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ],
        ),
        if (_driverLocation == null)
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text('Waiting for driver location...',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
        Positioned(
          top: 10, right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isConnected
                  ? Colors.green.withOpacity(0.9)
                  : Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.2), blurRadius: 4)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isConnected ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(_isConnected ? 'Live' : 'Connecting...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        Positioned(
          top: 10, left: 10,
          child: GestureDetector(
            onTap: _toggleFullScreen,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2), blurRadius: 4)],
              ),
              child: Icon(
                fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white, size: 20,
              ),
            ),
          ),
        ),
        if (_driverLocation != null && _deliveryLocation != null)
          Positioned(
            bottom: 12, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Driver',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ]),
                    Container(
                      width: 40, height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.success]),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Destination',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ]),
                  ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildSupplierTimelineCard() {
    final isDelivered = _displayStatus.toLowerCase() == 'delivered' ||
        _displayStatus.toLowerCase() == 'completed';
    final isOutForDelivery = _displayStatus.toLowerCase() == 'out for delivery';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDelivered
              ? [AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05)]
              : [AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDelivered
              ? AppColors.success.withOpacity(0.4)
              : AppColors.primary.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDelivered
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDelivered ? Icons.check_circle : Icons.delivery_dining,
              color: isDelivered ? AppColors.success : AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelivered ? 'Order Delivered!' : 'Out for Delivery',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDelivered ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isDelivered
                      ? 'Your order has been delivered successfully.'
                      : 'Your order is on the way!',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ])),
        ]),

        if (_estimatedDeliveryTime != null && !isDelivered) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.access_time,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Expected Delivery',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  _fmtDateTime(_estimatedDeliveryTime),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ]),
            ]),
          ),
        ],

        if (isOutForDelivery) ...[
          const SizedBox(height: 12),
          Row(children: const [
            Icon(Icons.info_outline,
                size: 13, color: AppColors.textHint),
            SizedBox(width: 6),
            Text(
              'Live tracking not available for this delivery.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ]),
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        body: GestureDetector(
          onTap: _toggleFullScreen,
          child: _buildMap(fullScreen: true),
        ),
      );
    }

    // ── FIX 2: Use _displayStatus everywhere in build ──
    final displayStatus = _displayStatus;
    final isDelivered   = displayStatus.toLowerCase() == 'delivered';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:           const Text('Track Order'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation:       0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.circle,
                size: 12,
                color: _isConnected ? Colors.greenAccent : Colors.grey),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // Error banner
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.error))),
                    ]),
                  ),

                // ETA banner
                if (_isDriverEnRoute && _etaMinutes != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.access_time,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Arrival',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text(_formatEta(_etaMinutes!),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ]),
                    ]),
                  ),

                // Map or supplier timeline card
                if (_isSupplierDelivery)
                  _buildSupplierTimelineCard()
                else
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _isDriverEnRoute
                          ? _buildMap()
                          : _MapPlaceholder(statusLabel: displayStatus),
                    ),
                  ),

                // Driver card — only for driver delivery
                if (!_isSupplierDelivery &&
                    (_driver != null ||
                        displayStatus.toLowerCase() == 'out for delivery'))
                  _DriverCard(driver: _driver),

                // ── FIX 1: Order Status steps — REMOVED duplicate steps.
                // The original code had two "_Step(Out for Delivery)" and
                // two "_Step(Delivered)" widgets. Now there is exactly one
                // of each, driven by _displayStatus / _isAtLeast().
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Status',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        _Step(
                            title: 'Order Placed',
                            subtitle:
                            '${_fmtDate(_src['createdAt'] ?? _src['date'])} • '
                                '${_fmtTime(_src['createdAt'] ?? _src['date'])}',
                            completed: true,
                            active: false,
                            icon: Icons.check_circle),
                        _Step(
                            title:    'Out for Delivery',
                            subtitle: 'Driver is on the way',
                            completed: _isAtLeast('delivered'),
                            active:    displayStatus.toLowerCase() == 'out for delivery',
                            icon: Icons.local_shipping),
                        _Step(
                            title:    'Delivered',
                            subtitle: 'Order has been delivered',
                            completed: _isAtLeast('delivered'),
                            active: false,
                            icon: Icons.check_circle,
                            isLast: true),
                      ]),
                ),

                // ── Order Details card ─────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:       Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Header row with optional Raise Dispute button
                        Row(children: [
                          const Icon(Icons.receipt_long,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Order Details',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          if (isDelivered)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DisputeFormScreen(
                                    orderId:     _orderId,
                                    orderNumber: _orderNumber,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.warning.withOpacity(0.6)),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.gavel,
                                          size: 14, color: AppColors.warning),
                                      SizedBox(width: 4),
                                      Text('Raise Dispute',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.warning)),
                                    ]),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 14),

                        _DRow(
                            icon:  Icons.tag,
                            label: 'Order ID',
                            value: _orderNumber.isNotEmpty
                                ? _orderNumber
                                : _orderId),
                        const SizedBox(height: 10),
                        _DRow(
                            icon:  Icons.store,
                            label: 'Supplier',
                            value: _supplierName),
                        if (_deliveryAddress != null) ...[
                          const SizedBox(height: 10),
                          _DRow(
                              icon:  Icons.location_on_outlined,
                              label: 'Deliver to',
                              value: _deliveryAddress!),
                        ],
                        const SizedBox(height: 16),

                        if (_orderItems.isNotEmpty) ...[
                          const Text('Items Ordered',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          ..._orderItems.map((item) => _ItemRow(item: item)),
                          const SizedBox(height: 4),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                        ] else if (_itemCount > 0) ...[
                          _DRow(
                              icon:  Icons.shopping_basket,
                              label: 'Items',
                              value: '$_itemCount items'),
                          const SizedBox(height: 10),
                        ],

                        const Text('Price Breakdown',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 10),

                        if (_subtotal > 0) ...[
                          _PriceRow(label: 'Subtotal',
                              value: '£${_subtotal.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                        ],
                        if (_deliveryFee > 0) ...[
                          _PriceRow(label: 'Delivery Fee',
                              value: '£${_deliveryFee.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                        ],
                        if (_tax > 0) ...[
                          _PriceRow(label: 'Tax',
                              value: '£${_tax.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                        ],
                        const Divider(height: 16),
                        _PriceRow(
                          label:  'Total',
                          value:  '£${_total.toStringAsFixed(2)}',
                          isBold: true,
                          color:  AppColors.primary,
                        ),
                      ]),
                ),

                const SizedBox(height: 24),
              ]),
        ),
      ),
    );
  }
}

// ── Item row ─────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['productName'] ??
        item['name'] ??
        item['product']?['name'] ??
        'Item')
        .toString();
    final qty       = ((item['quantity'] ?? 1) as num).toInt();
    final unitPrice = ((item['unitPrice'] ??
        item['price'] ??
        item['product']?['price'] ??
        0) as num)
        .toDouble();
    final subtotal    = qty * unitPrice;
    final imgUrl      = item['imageUrl']?.toString() ??
        item['productImage']?.toString() ??
        item['product']?['imageUrl']?.toString() ??
        item['image']?.toString();
    final specialNote =
    (item['specialInstructions'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imgUrl != null && imgUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imgUrl,
              width: 52, height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _itemIconBox(),
            ),
          )
        else
          _itemIconBox(),
        const SizedBox(width: 12),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (specialNote.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Note: $specialNote',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text(
                '${unitPrice > 0 ? '£${unitPrice.toStringAsFixed(2)} × ' : ''}$qty',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ])),

        Text(
          subtotal > 0 ? '£${subtotal.toStringAsFixed(2)}' : '×$qty',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
      ]),
    );
  }

  Widget _itemIconBox() => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.shopping_basket,
        color: AppColors.textHint, size: 22),
  );
}

// ── Price row ─────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  final String title, value;
  final bool   isBold;
  final Color? color;

  const _PriceRow({
    String? label,
    String? title,
    required this.value,
    this.isBold = false,
    this.color,
  })  : title = label ?? title ?? '';

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textPrimary)),
      Text(value,
          style: TextStyle(
              fontSize: isBold ? 17 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary)),
    ],
  );
}

// ── Map placeholder ────────────────────────────────────────
class _MapPlaceholder extends StatelessWidget {
  final String statusLabel;
  const _MapPlaceholder({required this.statusLabel});

  String get _message {
    switch (statusLabel.toLowerCase()) {
      case 'processing':       return 'Order is being prepared';
      case 'delivered':        return 'Order has been delivered';
      case 'cancelled':        return 'Order was cancelled';
      case 'out for delivery': return 'Order is out for delivery';
      default:                 return 'Waiting for driver pickup...';
    }
  }

  IconData get _icon {
    switch (statusLabel.toLowerCase()) {
      case 'processing': return Icons.inventory_2_outlined;
      case 'delivered':  return Icons.check_circle_outline;
      case 'cancelled':  return Icons.cancel_outlined;
      default:           return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 60, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(_message,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text(
                'Live tracking starts when\ndriver picks up your order',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ]),
      ),
    ),
  );
}

// ── Driver card ────────────────────────────────────────────
class _DriverCard extends StatelessWidget {
  final Map<String, dynamic>? driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final name    = (driver?['name'] ?? driver?['fullName'] ?? 'Your Driver').toString();
    final rating  = driver?['rating']?.toString() ?? '—';
    final trips   = driver?['totalDeliveries']?.toString() ?? '';
    final vehicle = (driver?['vehicle'] ?? driver?['vehicleType'] ?? 'Van').toString();
    final plate   = (driver?['licensePlate'] ?? driver?['plate'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.person, size: 30, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star, size: 13, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(trips.isNotEmpty
                    ? '$rating ($trips deliveries)'
                    : rating,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Text(plate.isNotEmpty ? '$vehicle • $plate' : vehicle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
            ])),
        IconButton(
          icon:      const Icon(Icons.phone, color: AppColors.primary),
          onPressed: () {},
          style:     IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1)),
        ),
      ]),
    );
  }
}

// ── Status step ────────────────────────────────────────────
class _Step extends StatelessWidget {
  final String   title, subtitle;
  final bool     completed, active, isLast;
  final IconData icon;

  const _Step({
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.active,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color c;
    if (completed)   c = AppColors.success;
    else if (active) c = AppColors.primary;
    else             c = AppColors.textHint;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (completed || active)
                ? c.withOpacity(0.1)
                : AppColors.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: c, width: 2),
          ),
          child: Icon(icon, size: 18, color: c),
        ),
        if (!isLast)
          Container(
              width: 2, height: 50,
              color: completed ? AppColors.success : AppColors.border),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: (active || completed)
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
      )),
    ]);
  }
}

// ── Detail row ─────────────────────────────────────────────
class _DRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _DRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 17, color: AppColors.textSecondary),
    const SizedBox(width: 10),
    Expanded(child: Text(label,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary))),
    Flexible(child: Text(value,
        textAlign: TextAlign.right,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        overflow: TextOverflow.ellipsis)),
  ]);
}