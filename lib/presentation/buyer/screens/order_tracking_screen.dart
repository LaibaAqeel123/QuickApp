import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  String? _error;
  bool _isFullScreen = false;

  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng? _deliveryLocation;
  double? _etaMinutes;
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  HubConnection? _hubConnection;
  bool _isConnected = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _pulseController.dispose();
    _hubConnection?.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _fmtTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (_) {
      return raw.toString();
    }
  }

  String get _statusLabel {
    final raw = _src['status'] ?? _src['orderStatus'];
    if (raw is String) return raw;
    if (raw is int) switch (raw) {
      case 1: return 'Processing';
      case 2: return 'Processing';
      case 3: return 'Processing';
      case 4: return 'Out for Delivery';
      case 5: return 'Delivered';
      case 6: return 'Delivered';
      case 7: return 'Cancelled';
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
      ((_src['total'] ?? _src['totalAmount'] ?? _src['grandTotal'] ?? 0) as num)
          .toDouble();

  bool _isAtLeast(String min) {
    const order = ['processing', 'out for delivery', 'delivered'];
    final cur = order.indexOf(_statusLabel.toLowerCase());
    final m = order.indexOf(min.toLowerCase());
    return cur >= m && cur != -1;
  }

  // ── ETA Format Helper ────────────────────────────────
  String _formatEta(double minutes) {
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).toStringAsFixed(0);
      return '${hours}h ${mins}min';
    }
  }

  // ── OSRM Route Fetch ─────────────────────────────────
  Future<void> _fetchRoute() async {
    if (_driverLocation == null || _deliveryLocation == null) return;
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;

    try {
      // Try multiple OSRM servers for reliability
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
            if (data['code'] == 'Ok' && data['routes'] != null &&
                (data['routes'] as List).isNotEmpty) {
              final coords =
              data['routes'][0]['geometry']['coordinates'] as List;
              points = coords
                  .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
                  .toList();
              debugPrint(' Route fetched: ${points.length} points from $server');
              break;
            }
          }
        } catch (e) {
          debugPrint(' Server $server failed: $e');
          continue;
        }
      }

      if (mounted) {
        if (points != null && points.length >= 2) {
          setState(() => _routePoints = points!);
        } else {
          // Fallback — straight line
          debugPrint('⚠ Using straight line fallback');
          setState(() => _routePoints = [_driverLocation!, _deliveryLocation!]);
        }
      }
    } catch (e) {
      debugPrint(' Route fetch error: $e');
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
      setState(() { _detail = r.data; _isLoading = false; });

      final addr = _detail?['deliveryAddress'];
      if (addr != null) {
        final lat = (addr['latitude'] as num?)?.toDouble();
        final lng = (addr['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _deliveryLocation = LatLng(lat, lng));
          debugPrint(' Delivery location set: $lat, $lng');
        } else {
          debugPrint(' Delivery address has no coordinates: $addr');
        }
      }

      final deliveryResult =
      await AuthService.instance.getDeliveryByOrderId(_orderId);
      if (deliveryResult.success && deliveryResult.data != null) {
        final dId = deliveryResult.data!['deliveryId']?.toString() ?? '';
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
    try {
      final token = await AuthService.instance.getAccessToken();
      if (token == null) return;

      final hubUrl =
          'https://api.neptasolutions.co.uk/hubs/delivery-tracking?access_token=$token';

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl,
          options: HttpConnectionOptions(
            transport: HttpTransportType.WebSockets,
            skipNegotiation: true,
          ))
          .withAutomaticReconnect()
          .build();

      _hubConnection!.serverTimeoutInMilliseconds = 60000;
      _hubConnection!.keepAliveIntervalInMilliseconds = 15000;

      _hubConnection!.on('LocationUpdated', (args) {
        if (args == null || args.isEmpty) return;
        try {
          final data = args[0] as Map<String, dynamic>;
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final eta = (data['etaMinutes'] as num?)?.toDouble();
          if (lat != null && lng != null && mounted) {
            setState(() {
              _driverLocation = LatLng(lat, lng);
              // Cap ETA to reasonable value max 600 min = 10 hours
              if (eta != null && eta > 0 && eta < 600) {
                _etaMinutes = eta;
              } else if (eta != null && eta >= 600) {
                // Calculate manually if too high
                _etaMinutes = null;
              }
            });
            _fetchRoute();
          }
        } catch (_) {}
      });

      _hubConnection!.onclose(({error}) {
        if (mounted) setState(() => _isConnected = false);
      });
      _hubConnection!.onreconnecting(({error}) {
        if (mounted) setState(() => _isConnected = false);
      });
      _hubConnection!.onreconnected(({connectionId}) {
        if (mounted) setState(() => _isConnected = true);
        _hubConnection!.invoke('SubscribeToDelivery', args: [_deliveryId]);
      });

      await _hubConnection!.start();
      if (mounted) setState(() => _isConnected = true);
      await _hubConnection!.invoke('SubscribeToDelivery', args: [_deliveryId]);
    } catch (e) {
      if (mounted) setState(() => _isConnected = false);
      _hubConnection = null;
    }
  }

  LatLng get _mapCenter {
    if (_driverLocation != null && _deliveryLocation != null) {
      return LatLng(
        (_driverLocation!.latitude + _deliveryLocation!.latitude) / 2,
        (_driverLocation!.longitude + _deliveryLocation!.longitude) / 2,
      );
    }
    if (_driverLocation != null) return _driverLocation!;
    if (_deliveryLocation != null) return _deliveryLocation!;
    return const LatLng(31.5204, 74.3587);
  }

  double get _mapZoom {
    if (_driverLocation == null || _deliveryLocation == null) return 14;
    final latDiff =
    (_driverLocation!.latitude - _deliveryLocation!.latitude).abs();
    final lngDiff =
    (_driverLocation!.longitude - _deliveryLocation!.longitude).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff > 5) return 6;
    if (maxDiff > 2) return 8;
    if (maxDiff > 1) return 9;
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
    final height =
    fullScreen ? MediaQuery.of(context).size.height : 300.0;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
            ),
            children: [

              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.food_delivery_app',
                additionalOptions: const {'s': 'abcd'},
              ),


              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6.0,
                      color: Colors.black.withOpacity(0.12),
                    ),
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: AppColors.primary,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(markers: [
                if (_deliveryLocation != null)
                  Marker(
                    point: _deliveryLocation!,
                    width: 60,
                    height: 70,
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.home,
                              color: Colors.white, size: 24),
                        ),
                        Container(width: 3, height: 10,
                            color: AppColors.success),
                      ],
                    ),
                  ),

                if (_driverLocation != null)
                  Marker(
                    point: _driverLocation!,
                    width: 70,
                    height: 70,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60 * _pulseAnimation.value,
                              height: 60 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(
                                    0.2 / _pulseAnimation.value),
                              ),
                            ),
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.delivery_dining,
                                  color: Colors.white, size: 24),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ]),
            ],
          ),

          // Waiting overlay
          if (_driverLocation == null)
            Positioned(
              bottom: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text('Waiting for driver location...',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // Live badge
          Positioned(
            top: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withOpacity(0.9)
                    : Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2), blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'Live' : 'Connecting...',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Full screen toggle
          Positioned(
            top: 10, left: 10,
            child: GestureDetector(
              onTap: _toggleFullScreen,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2), blurRadius: 4),
                  ],
                ),
                child: Icon(
                  fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ),

          // Driver → Destination bar
          if (_driverLocation != null && _deliveryLocation != null)
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
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
                          colors: [AppColors.primary, AppColors.success],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Destination',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
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
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error))),
                  ]),
                ),

              // ETA in hours/minutes format
              if (_etaMinutes != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated Arrival',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(
                          _formatEta(_etaMinutes!),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ]),
                ),

              // MAP
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMap(),
                ),
              ),

              // Order Status
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
                        title: _statusLabel.toLowerCase() == 'processing'
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

              // Order Details
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]),
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

class _Step extends StatelessWidget {
  final String title, subtitle;
  final bool completed, active, isLast;
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
    if (completed) {
      c = AppColors.success;
    } else if (active) {
      c = AppColors.primary;
    } else {
      c = AppColors.textHint;
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: (completed || active)
                    ? c.withOpacity(0.1)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2)),
            child: Icon(icon, size: 18, color: c)),
        if (!isLast)
          Container(
              width: 2,
              height: 50,
              color: completed ? AppColors.success : AppColors.border),
      ]),
      const SizedBox(width: 12),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ]))),
    ]);
  }
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _DRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 17, color: AppColors.textSecondary),
    const SizedBox(width: 10),
    Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary))),
    Flexible(
        child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis)),
  ]);
}