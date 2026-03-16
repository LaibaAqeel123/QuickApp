import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:food_delivery_app/core/constants/app_colors.dart';
import 'package:food_delivery_app/core/services/auth_service.dart';
import 'package:signalr_netcore/signalr_client.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hubConnection?.stop();
    super.dispose();
  }

  Map<String, dynamic> get _src => _detail ?? widget.order;

  String get _orderId =>
      (_src['id'] ?? _src['orderId'] ?? _src['orderNumber'] ?? '').toString();

  String get _deliveryId =>
      (_src['deliveryId'] ?? '').toString();

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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

  Map<String, dynamic>? get _driver =>
      _src['driver'] as Map<String, dynamic>?;

  bool _isAtLeast(String min) {
    const order = ['processing', 'out for delivery', 'delivered'];
    final cur = order.indexOf(_statusLabel.toLowerCase());
    final m = order.indexOf(min.toLowerCase());
    return cur >= m && cur != -1;
  }

  Color _statusColor() {
    switch (_statusLabel.toLowerCase()) {
      case 'processing': return AppColors.warning;
      case 'out for delivery': return AppColors.info;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
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
      setState(() { _detail = r.data; _isLoading = false; });

      // Set delivery location from address
      final addr = _detail?['deliveryAddress'];
      if (addr != null) {
        final lat = (addr['latitude'] as num?)?.toDouble();
        final lng = (addr['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _deliveryLocation = LatLng(lat, lng));
        }
      }

      // Get deliveryId from separate API
      final deliveryResult = await AuthService.instance
          .getDeliveryByOrderId(_orderId);
      debugPrint(' DeliveryResult: ${deliveryResult.success} | data: ${deliveryResult.data}');

      if (deliveryResult.success && deliveryResult.data != null) {
        final dId = deliveryResult.data!['deliveryId']?.toString() ?? '';
        debugPrint(' DeliveryId found: $dId');
        if (dId.isNotEmpty) {
          setState(() => _detail = {...?_detail, 'deliveryId': dId});
          await _connectSignalR();
        }
      }
    } else {
      setState(() { _isLoading = false; _error = r.message; });
    }
  }
  Future<void> _connectSignalR() async {
    debugPrint('🔌 SignalR connecting... deliveryId: $_deliveryId');
    try {
      final token = await AuthService.instance.getAccessToken();
      debugPrint(' Token: ${token != null ? "EXISTS" : "NULL"}');
      if (token == null) return;

      final hubUrl =
          'https://api.neptasolutions.co.uk/hubs/delivery-tracking?access_token=$token';

      _hubConnection = HubConnectionBuilder()
          .withUrl(
        hubUrl,
        options: HttpConnectionOptions(
          transport: HttpTransportType.LongPolling,
          skipNegotiation: true,
        ),
      )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.serverTimeoutInMilliseconds = 60000;
      _hubConnection!.keepAliveIntervalInMilliseconds = 15000;

      _hubConnection!.on('LocationUpdated', (args) {
        debugPrint(' LocationUpdated received: $args');
        if (args == null || args.isEmpty) return;
        try {
          final data = args[0] as Map<String, dynamic>;
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final eta = (data['etaMinutes'] as num?)?.toDouble();
          if (lat != null && lng != null && mounted) {
            setState(() {
              _driverLocation = LatLng(lat, lng);
              _etaMinutes = eta;
            });
            try { _mapController.move(_driverLocation!, 15); } catch (_) {}
          }
        } catch (e) {
          debugPrint(' Parse error: $e');
        }
      });

      debugPrint('🔌 Starting...');
      await _hubConnection!.start();
      debugPrint(' SignalR connected!');

      if (mounted) setState(() => _isConnected = true);

      await _hubConnection!.invoke(
        'SubscribeToDelivery',
        args: [_deliveryId],
      );
      debugPrint(' Subscribed: $_deliveryId');

    } catch (e) {
      debugPrint(' SignalR error: $e');
      _hubConnection = null;
    }
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.circle,
              size: 12,
              color: _isConnected ? Colors.greenAccent : Colors.grey,
            ),
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
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.error))),
                  ]),
                ),

              if (_etaMinutes != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.access_time,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Driver arriving in ${_etaMinutes!.toStringAsFixed(0)} minutes',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ]),
                ),

              Container(
                height: 280,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _driverLocation == null
                      ? Container(
                    color: AppColors.surfaceLight,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping,
                              size: 60,
                              color: AppColors.primary),
                          SizedBox(height: 12),
                          Text(
                              'Waiting for driver location...',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors
                                      .textSecondary)),
                        ],
                      ),
                    ),
                  )
                      : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                        'com.example.food_delivery_app',
                      ),
                      MarkerLayer(markers: [
                        if (_driverLocation != null)
                          Marker(
                            point: _driverLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        if (_deliveryLocation != null)
                          Marker(
                            point: _deliveryLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 3),
                              ),
                              child: const Icon(
                                Icons.home,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),

              if (_driver != null ||
                  _statusLabel.toLowerCase() == 'out for delivery')
                _DriverCard(driver: _driver),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        '${_fmtDate(_src['createdAt'] ?? _src['date'])} • ${_fmtTime(_src['createdAt'] ?? _src['date'])}',
                        completed: true,
                        active: false,
                        icon: Icons.check_circle),
                    _Step(
                        title: 'Order Confirmed',
                        subtitle: 'Confirmed by supplier',
                        completed: _isAtLeast('processing'),
                        active: false,
                        icon: Icons.verified),
                    _Step(
                        title: _statusLabel.toLowerCase() ==
                            'processing'
                            ? 'Preparing Order'
                            : 'Order Prepared',
                        subtitle: 'Being prepared by supplier',
                        completed: _isAtLeast('out for delivery'),
                        active:
                        _statusLabel.toLowerCase() == 'processing',
                        icon: Icons.inventory_2),
                    _Step(
                        title: 'Out for Delivery',
                        subtitle: 'Driver is on the way',
                        completed:
                        _statusLabel.toLowerCase() == 'delivered',
                        active: _statusLabel.toLowerCase() ==
                            'out for delivery',
                        icon: Icons.local_shipping),
                    _Step(
                        title: 'Delivered',
                        subtitle: 'Order has been delivered',
                        completed:
                        _statusLabel.toLowerCase() == 'delivered',
                        active: false,
                        icon: Icons.check_circle,
                        isLast: true),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    _DRow(
                        icon: Icons.receipt,
                        label: 'Order ID',
                        value: _orderId),
                    const SizedBox(height: 10),
                    _DRow(
                        icon: Icons.store,
                        label: 'Supplier',
                        value: _supplierName),
                    const SizedBox(height: 10),
                    _DRow(
                        icon: Icons.shopping_basket,
                        label: 'Items',
                        value: '$_itemCount items'),
                    const SizedBox(height: 10),
                    _DRow(
                        icon: Icons.attach_money,
                        label: 'Total',
                        value: '£${_total.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 30, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.star, size: 13, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(trips.isNotEmpty ? '$rating ($trips deliveries)' : rating,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          Text(plate.isNotEmpty ? '$vehicle • $plate' : vehicle,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ])),
        IconButton(
            icon: const Icon(Icons.phone, color: AppColors.primary),
            onPressed: () {},
            style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1))),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final String title, subtitle;
  final bool completed, active, isLast;
  final IconData icon;

  const _Step({required this.title, required this.subtitle,
    required this.completed, required this.active,
    required this.icon, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    Color c = AppColors.textHint;
    if (completed) c = AppColors.success;
    if (active) c = AppColors.primary;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: (completed || active)
                    ? c.withOpacity(0.1) : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2)),
            child: Icon(icon, size: 18, color: c)),
        if (!isLast)
          Container(width: 2, height: 50,
              color: completed ? AppColors.success : AppColors.border),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: (active || completed)
                    ? AppColors.textPrimary : AppColors.textSecondary)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
          ]))),
    ]);
  }
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _DRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 17, color: AppColors.textSecondary),
    const SizedBox(width: 10),
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    Flexible(child: Text(value, textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        overflow: TextOverflow.ellipsis)),
  ]);
}