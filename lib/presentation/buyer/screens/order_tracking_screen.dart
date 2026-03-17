import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/itransport.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  String? _error;

  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng? _deliveryLocation;
  double? _etaMinutes;

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool _isDriverEnRoute = false;

  // ── HTTP polling fallback ──────────────────────────────
  // Fires every 10s. Stops automatically if SignalR starts delivering.
  Timer? _pollTimer;
  bool _signalRDeliveredLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _hubConnection?.stop();
    super.dispose();
  }

  Map<String, dynamic> get _src => _detail ?? widget.order;

  String get _orderId =>
      (_src['id'] ?? _src['orderId'] ?? _src['orderNumber'] ?? '').toString();

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
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) { return raw.toString(); }
  }

  String get _statusLabel {
    final raw = _src['status'] ?? _src['orderStatus'];
    if (raw is String) return raw;
    if (raw is int) switch (raw) {
      case 1: return 'Processing';
      case 2: return 'Out for Delivery';
      case 3: return 'Delivered';
      case 4: return 'Cancelled';
    }
    return 'Processing';
  }

  String get _supplierName =>
      (_src['supplierName'] ?? _src['supplier']?['name'] ?? 'Supplier').toString();

  int get _itemCount {
    final items = _src['items'] ?? _src['orderItems'];
    if (items is List) return items.length;
    final c = _src['itemCount'] ?? _src['totalItems'];
    return c is num ? c.toInt() : 0;
  }

  double get _total =>
      ((_src['total'] ?? _src['totalAmount'] ?? _src['grandTotal'] ?? 0) as num).toDouble();

  Map<String, dynamic>? get _driver => _src['driver'] as Map<String, dynamic>?;

  bool _isAtLeast(String min) {
    const order = ['processing', 'out for delivery', 'delivered'];
    final cur = order.indexOf(_statusLabel.toLowerCase());
    final m = order.indexOf(min.toLowerCase());
    return cur >= m && cur != -1;
  }

  bool _computeDriverEnRoute() {
    final s = _statusLabel.toLowerCase();
    return s == 'out for delivery' || s == '2';
  }

  bool _isPickedUpFromDelivery(Map<String, dynamic>? d) {
    if (d == null) return false;
    final raw = (d['deliveryStatus'] ?? d['status'] ?? '').toString().toLowerCase();
    return raw == 'pickedup' || raw == 'picked_up' || raw == '4' ||
        raw == 'outfordelivery' || raw == 'out_for_delivery';
  }

  // ══════════════════════════════════════════════════════
  //  LOAD
  // ══════════════════════════════════════════════════════
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
        _detail = r.data;
        _isLoading = false;
        _isDriverEnRoute = _computeDriverEnRoute();
      });

      final addr = _detail?['deliveryAddress'];
      if (addr != null) {
        final lat = (addr['latitude'] as num?)?.toDouble();
        final lng = (addr['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _deliveryLocation = LatLng(lat, lng));
        }
      }

      final deliveryResult = await AuthService.instance.getDeliveryByOrderId(_orderId);
      debugPrint('🔍 DeliveryResult: ${deliveryResult.success} | data: ${deliveryResult.data}');

      if (deliveryResult.success && deliveryResult.data != null) {
        final delivery = deliveryResult.data!;
        final dId = delivery['deliveryId']?.toString() ?? '';

        if (dId.isNotEmpty) {
          setState(() => _detail = {...?_detail, 'deliveryId': dId});
        }

        // Read any embedded lat/lng from the delivery response immediately
        _tryUpdateLocationFromDelivery(delivery);

        final driverPickedUp = _isPickedUpFromDelivery(delivery);
        debugPrint('🚗 Driver picked up: $driverPickedUp');

        if (driverPickedUp && dId.isNotEmpty) {
          setState(() => _isDriverEnRoute = true);
          // Start HTTP polling FIRST so map shows something right away
          _startPolling();
          // Then also try SignalR for real-time updates
          await _connectSignalR();
        }
      }
    } else {
      setState(() { _isLoading = false; _error = r.message; });
    }
  }

  // ── Read driver lat/lng directly from the delivery API response ──────────
  void _tryUpdateLocationFromDelivery(Map<String, dynamic> delivery) {
    final lat = (delivery['driverLatitude'] ??
            delivery['currentLatitude'] ??
            delivery['latitude'] as num?)?.toDouble();
    final lng = (delivery['driverLongitude'] ??
            delivery['currentLongitude'] ??
            delivery['longitude'] as num?)?.toDouble();

    if (lat != null && lng != null && mounted) {
      debugPrint('📍 [HTTP] Got driver location: $lat, $lng');
      setState(() {
        _driverLocation = LatLng(lat, lng);
        _isDriverEnRoute = true;
      });
      try { _mapController.move(_driverLocation!, 15); } catch (_) {}
    } else {
      debugPrint('📍 [HTTP] No lat/lng in delivery response (keys: ${delivery.keys.toList()})');
    }
  }

  // ── HTTP polling: every 10s, falls back if SignalR hub doesn't broadcast ─
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !_isDriverEnRoute) return;
      if (_signalRDeliveredLocation) {
        debugPrint('🔄 [Poll] SignalR active — skipping HTTP poll');
        return;
      }
      debugPrint('🔄 [HTTP Poll] Fetching driver location...');
      final result = await AuthService.instance.getDeliveryByOrderId(_orderId);
      if (!mounted) return;
      if (result.success && result.data != null) {
        final delivery = result.data!;
        final status = (delivery['deliveryStatus'] ?? '').toString().toLowerCase();
        if (status == 'delivered' || status == '5') {
          setState(() {
            _isDriverEnRoute = false;
            _driverLocation = null;
            _etaMinutes = null;
          });
          _pollTimer?.cancel();
          return;
        }
        _tryUpdateLocationFromDelivery(delivery);
      }
    });
  }

  // ══════════════════════════════════════════════════════
  //  SIGNALR
  // ══════════════════════════════════════════════════════
  void _handleLocationArgs(String eventName, List<Object?>? args) {
    debugPrint('📍 [$eventName] raw args: $args');
    if (args == null || args.isEmpty) return;
    try {
      double? lat;
      double? lng;
      double? eta;
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

      debugPrint('📍 [$eventName] → lat: $lat, lng: $lng, eta: $eta');

      if (lat != null && lng != null && mounted) {
        _signalRDeliveredLocation = true;
        setState(() {
          _driverLocation = LatLng(lat!, lng!);
          if (eta != null) _etaMinutes = eta;
          _isDriverEnRoute = true;
        });
        try { _mapController.move(_driverLocation!, 15); } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ [$eventName] parse error: $e');
    }
  }

  void _registerHubListeners(HubConnection hub) {
    const locationEvents = [
      'LocationUpdated', 'ReceiveLocation', 'DriverLocationUpdated',
      'UpdateLocation', 'SendLocation', 'location', 'driverLocation',
      'DriverLocation', 'TrackingUpdate',
    ];
    for (final name in locationEvents) {
      hub.on(name, (args) {
        debugPrint('🔔 HIT: event "$name" fired! args=$args');
        _handleLocationArgs(name, args);
      });
    }
    for (final name in ['DeliveryStatusChanged', 'StatusUpdated', 'DeliveryUpdated']) {
      hub.on(name, (args) {
        if (args == null || args.isEmpty) return;
        try {
          final data = args[0];
          if (data is Map<String, dynamic>) {
            final s = (data['status'] ?? data['deliveryStatus'] ?? '').toString().toLowerCase();
            if ((s == 'delivered' || s == '5') && mounted) {
              setState(() { _isDriverEnRoute = false; _driverLocation = null; _etaMinutes = null; });
              _pollTimer?.cancel();
            }
          }
        } catch (e) { debugPrint('❌ [$name] error: $e'); }
      });
    }
  }

  Future<void> _resubscribe(HubConnection hub, String delivId) async {
    for (final method in ['SubscribeToDelivery', 'JoinDeliveryGroup', 'JoinGroup']) {
      try {
        await hub.invoke(method, args: [delivId]);
        debugPrint('✅ Subscribed via $method: $delivId');
        return;
      } catch (e) { debugPrint('⚠️ $method failed: $e'); }
    }
  }

  Future<bool> _tryConnect({
    required String token, required String delivId,
    required HttpTransportType transport,
    required bool skipNegotiation, required String label,
  }) async {
    HubConnection? hub;
    try {
      hub = HubConnectionBuilder()
          .withUrl(
            'https://api.neptasolutions.co.uk/hubs/delivery-tracking?access_token=$token',
            options: HttpConnectionOptions(transport: transport, skipNegotiation: skipNegotiation),
          )
          .withAutomaticReconnect()
          .build();
      hub.serverTimeoutInMilliseconds = 30000;
      hub.keepAliveIntervalInMilliseconds = 15000;
      _registerHubListeners(hub);
      hub.onreconnected(({connectionId}) => _resubscribe(hub!, delivId));
      hub.onclose(({error}) { if (mounted) setState(() => _isConnected = false); });
      await hub.start();
      debugPrint('✅ Connected via $label!');
      _hubConnection = hub;
      if (mounted) setState(() => _isConnected = true);
      await _resubscribe(hub, delivId);
      return true;
    } catch (e, stack) {
      debugPrint('❌ $label FAILED: $e\n$stack');
      try { await hub?.stop(); } catch (_) {}
      return false;
    }
  }

  Future<void> _connectSignalR() async {
    final delivId = _deliveryId;
    if (delivId.isEmpty) return;
    final token = await AuthService.instance.getAccessToken();
    if (token == null) return;
    await _tryConnect(token: token, delivId: delivId, transport: HttpTransportType.WebSockets, skipNegotiation: true, label: 'WebSockets+skipNeg') ||
    await _tryConnect(token: token, delivId: delivId, transport: HttpTransportType.WebSockets, skipNegotiation: false, label: 'WebSockets') ||
    await _tryConnect(token: token, delivId: delivId, transport: HttpTransportType.LongPolling, skipNegotiation: false, label: 'LongPolling');
  }

  LatLng get _mapCenter {
    if (_driverLocation != null) return _driverLocation!;
    if (_deliveryLocation != null) return _deliveryLocation!;
    return const LatLng(31.5204, 74.3587);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order $_orderId', overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.circle, size: 12,
                  color: _isConnected ? Colors.greenAccent : Colors.grey)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error))),
                      ]),
                    ),
                  if (_isDriverEnRoute && _etaMinutes != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Driver arriving in ${_etaMinutes!.toStringAsFixed(0)} minutes',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ]),
                    ),
                  Container(
                    height: 280,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildMapContent()),
                  ),
                  if (_driver != null || _statusLabel.toLowerCase() == 'out for delivery')
                    _DriverCard(driver: _driver),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      _Step(title: 'Order Placed', subtitle: '${_fmtDate(_src['createdAt'] ?? _src['date'])} • ${_fmtTime(_src['createdAt'] ?? _src['date'])}', completed: true, active: false, icon: Icons.check_circle),
                      _Step(title: 'Order Confirmed', subtitle: 'Confirmed by supplier', completed: _isAtLeast('processing'), active: false, icon: Icons.verified),
                      _Step(title: _statusLabel.toLowerCase() == 'processing' ? 'Preparing Order' : 'Order Prepared', subtitle: 'Being prepared by supplier', completed: _isAtLeast('out for delivery'), active: _statusLabel.toLowerCase() == 'processing', icon: Icons.inventory_2),
                      _Step(title: 'Out for Delivery', subtitle: 'Driver is on the way', completed: _statusLabel.toLowerCase() == 'delivered', active: _statusLabel.toLowerCase() == 'out for delivery', icon: Icons.local_shipping),
                      _Step(title: 'Delivered', subtitle: 'Order has been delivered', completed: _statusLabel.toLowerCase() == 'delivered', active: false, icon: Icons.check_circle, isLast: true),
                    ]),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      _DRow(icon: Icons.receipt, label: 'Order ID', value: _orderId),
                      const SizedBox(height: 10),
                      _DRow(icon: Icons.store, label: 'Supplier', value: _supplierName),
                      const SizedBox(height: 10),
                      _DRow(icon: Icons.shopping_basket, label: 'Items', value: '$_itemCount items'),
                      const SizedBox(height: 10),
                      _DRow(icon: Icons.attach_money, label: 'Total', value: '£${_total.toStringAsFixed(2)}'),
                    ]),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _buildMapContent() {
    if (!_isDriverEnRoute) return _MapPlaceholder(statusLabel: _statusLabel);
    if (_driverLocation == null) {
      return Container(
        color: AppColors.surfaceLight,
        child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(height: 12),
          Text('Connecting to driver location...', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          SizedBox(height: 6),
          Text('Updating every 10 seconds', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ])),
      );
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _mapCenter, initialZoom: 14),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.food_delivery_app'),
        MarkerLayer(markers: [
          if (_driverLocation != null)
            Marker(point: _driverLocation!, width: 50, height: 50, child: Container(
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]),
              child: const Icon(Icons.delivery_dining, color: Colors.white, size: 26),
            )),
          if (_deliveryLocation != null)
            Marker(point: _deliveryLocation!, width: 50, height: 50, child: Container(
              decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
              child: const Icon(Icons.home, color: Colors.white, size: 26),
            )),
        ]),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final String statusLabel;
  const _MapPlaceholder({required this.statusLabel});
  String get _message { switch (statusLabel.toLowerCase()) { case 'processing': return 'Order is being prepared'; case 'delivered': return 'Order has been delivered'; case 'cancelled': return 'Order was cancelled'; default: return 'Waiting for driver pickup...'; } }
  IconData get _icon { switch (statusLabel.toLowerCase()) { case 'processing': return Icons.inventory_2_outlined; case 'delivered': return Icons.check_circle_outline; case 'cancelled': return Icons.cancel_outlined; default: return Icons.local_shipping_outlined; } }
  @override
  Widget build(BuildContext context) => Container(color: AppColors.surfaceLight, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_icon, size: 60, color: AppColors.primary), const SizedBox(height: 12), Text(_message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center), const SizedBox(height: 6), const Text('Live tracking starts when\ndriver picks up your order', style: TextStyle(fontSize: 12, color: AppColors.textHint), textAlign: TextAlign.center)])));
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic>? driver;
  const _DriverCard({required this.driver});
  @override
  Widget build(BuildContext context) {
    final name = (driver?['name'] ?? driver?['fullName'] ?? 'Your Driver').toString();
    final rating = driver?['rating']?.toString() ?? '—';
    final trips = driver?['totalDeliveries']?.toString() ?? '';
    final vehicle = (driver?['vehicle'] ?? driver?['vehicleType'] ?? 'Van').toString();
    final plate = (driver?['licensePlate'] ?? driver?['plate'] ?? '').toString();
    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person, size: 30, color: AppColors.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Row(children: [const Icon(Icons.star, size: 13, color: AppColors.warning), const SizedBox(width: 4), Text(trips.isNotEmpty ? '$rating ($trips deliveries)' : rating, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]), const SizedBox(height: 4), Text(plate.isNotEmpty ? '$vehicle • $plate' : vehicle, style: const TextStyle(fontSize: 11, color: AppColors.textHint))])), IconButton(icon: const Icon(Icons.phone, color: AppColors.primary), onPressed: () {}, style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)))]));
  }
}

class _Step extends StatelessWidget {
  final String title, subtitle;
  final bool completed, active, isLast;
  final IconData icon;
  const _Step({required this.title, required this.subtitle, required this.completed, required this.active, required this.icon, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    Color c = AppColors.textHint;
    if (completed) c = AppColors.success;
    if (active) c = AppColors.primary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Column(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: (completed || active) ? c.withOpacity(0.1) : AppColors.surfaceLight, shape: BoxShape.circle, border: Border.all(color: c, width: 2)), child: Icon(icon, size: 18, color: c)), if (!isLast) Container(width: 2, height: 50, color: completed ? AppColors.success : AppColors.border)]), const SizedBox(width: 12), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8, top: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: (active || completed) ? AppColors.textPrimary : AppColors.textSecondary)), const SizedBox(height: 3), 
    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])))]);
  }
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 17, color: AppColors.textSecondary), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))), Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis))]);
}