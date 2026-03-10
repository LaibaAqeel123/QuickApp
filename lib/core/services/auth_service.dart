import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════
//  API CONSTANTS
// ══════════════════════════════════════════════════════════
class ApiConstants {
  static const String baseUrl = 'https://api.neptasolutions.co.uk';

  // ── Auth ───────────────────────────────────────────────
  static const String register           = '$baseUrl/api/auth/register';
  static const String login              = '$baseUrl/api/auth/login';
  static const String logout             = '$baseUrl/api/auth/logout';
  static const String refresh            = '$baseUrl/api/auth/refresh';
  static const String me                 = '$baseUrl/api/auth/me';
  static const String verifyEmail        = '$baseUrl/api/auth/verify-email';
  static const String resendVerification = '$baseUrl/api/auth/resend-verification';

  // ── Driver ─────────────────────────────────────────────
  static String driverById(String id)      => '$baseUrl/api/Drivers/$id';
  static String driverToggle(String id)    => '$baseUrl/api/Drivers/$id/toggle-availability';
  static String driverStatus(String id)    => '$baseUrl/api/Drivers/$id/status';
  static String driverLocation(String id)  => '$baseUrl/api/Drivers/$id/location';
  static String driverUploadDoc(String id) => '$baseUrl/api/Drivers/$id/upload-document';

  // ── Cart ───────────────────────────────────────────────
  static const String cart          = '$baseUrl/api/cart';
  static const String cartItems     = '$baseUrl/api/cart/items';
  static String cartItem(String id) => '$baseUrl/api/cart/items/$id';

  // ── Orders (Buyer) ─────────────────────────────────────
  static const String ordersCheckout      = '$baseUrl/api/orders/checkout';
  static const String myOrders            = '$baseUrl/api/orders/my';
  static String myOrderById(String id)    => '$baseUrl/api/orders/my/$id';
  static String cancelOrder(String id)    => '$baseUrl/api/orders/my/$id/cancel';
  static const String myOrdersAnalytics   = '$baseUrl/api/orders/my/analytics';

  // ── Orders (Supplier) ──────────────────────────────────
  static const String supplierOrders                              = '$baseUrl/api/orders/supplier';
  static String supplierOrderById(String id)                      => '$baseUrl/api/orders/supplier/$id';
  static String supplierOrderItemStatus(String oId, String iId)  => '$baseUrl/api/orders/supplier/$oId/items/$iId/status';
  static const String supplierOrdersAnalytics                     = '$baseUrl/api/orders/supplier/analytics';

  // ── Categories ─────────────────────────────────────────
  static const String categories     = '$baseUrl/api/categories';
  static String categoryById(int id) => '$baseUrl/api/categories/$id';

  // ── Addresses ──────────────────────────────────────────
  static const String addresses              = '$baseUrl/api/addresses';
  static String addressById(String id)       => '$baseUrl/api/addresses/$id';
  static String addressDefault(String id)    => '$baseUrl/api/addresses/$id/default';

  // ── Catalog ────────────────────────────────────────────
  static const String catalogProducts         = '$baseUrl/api/catalog/products';
  static String catalogProductById(String id) => '$baseUrl/api/catalog/products/$id';
  static const String catalogFilters          = '$baseUrl/api/catalog/filters';

  // ── Product Images (Supplier) ──────────────────────────
  static String productImages(String productId) =>
      '$baseUrl/api/products/$productId/images';
  static String productImage(String productId, int imageId) =>
      '$baseUrl/api/products/$productId/images/$imageId';
}

// ══════════════════════════════════════════════════════════
//  RESULT TYPES
// ══════════════════════════════════════════════════════════
class AuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  const AuthResult({required this.success, this.message, this.data});
}

class ApiResult<T> {
  final bool success;
  final String? message;
  final T? data;
  const ApiResult({required this.success, this.message, this.data});
}

// ══════════════════════════════════════════════════════════
//  PREF KEYS
// ══════════════════════════════════════════════════════════
class _PrefKeys {
  static const String accessToken  = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userRole     = 'user_role';
  static const String userId       = 'user_id';
  static const String driverId     = 'driver_id';
}

// ══════════════════════════════════════════════════════════
//  AUTH SERVICE
// ══════════════════════════════════════════════════════════
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Headers ────────────────────────────────────────────
  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      };

  Future<Map<String, String>> get _authHeaders async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── JSON helpers ───────────────────────────────────────
  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      if (body.trim().isEmpty) return {};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) { return {}; }
  }

  dynamic _safeJsonDecodeAny(String body) {
    try {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    } catch (_) { return null; }
  }

  String? _extract(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      if (key.contains('.')) {
        final parts = key.split('.');
        dynamic node = body;
        for (final p in parts) {
          node = (node is Map<String, dynamic>) ? node[p] : null;
        }
        if (node != null) return node.toString();
      } else if (body[key] != null) {
        return body[key].toString();
      }
    }
    return null;
  }

  String _errorMessage(Map<String, dynamic> body, int statusCode) {
    final msg = _extract(body, ['message', 'error', 'detail', 'title']);
    if (msg != null && msg.isNotEmpty) return msg;
    switch (statusCode) {
      case 400: return 'Invalid request. Please check your details.';
      case 401: return 'Session expired. Please log in again.';
      case 403: return 'Access denied.';
      case 404: return 'Not found.';
      case 409: return 'Conflict. Please try again.';
      case 422: return 'Validation failed. Please check your details.';
      case 500: return 'Server error. Please try again later.';
      default:  return 'Something went wrong (code $statusCode).';
    }
  }

  String _friendlyNetworkError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Failed host lookup'))
      return 'No internet connection. Please check your network.';
    if (raw.contains('TimeoutException')) return 'Request timed out. Please try again.';
    if (raw.contains('HandshakeException')) return 'Secure connection failed.';
    return 'Network error. Please try again.';
  }

  void _log(String section, String url,
      {int? status, String? body, String? extra}) {
    debugPrint('\n╔══════════════════════════════════════╗');
    debugPrint('║  $section');
    debugPrint('║  URL   : $url');
    if (extra  != null) debugPrint('║  $extra');
    if (status != null) debugPrint('║  STATUS: $status');
    if (body   != null) debugPrint('║  BODY  : ${body.isEmpty ? "(EMPTY)" : body}');
    debugPrint('╚══════════════════════════════════════╝');
  }

  // ══════════════════════════════════════════════════════
  //  TOKEN HELPERS
  // ══════════════════════════════════════════════════════
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? role,
    String? userId,
    String? driverId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.accessToken, accessToken);
    if (refreshToken != null) await prefs.setString(_PrefKeys.refreshToken, refreshToken);
    if (role     != null) await prefs.setString(_PrefKeys.userRole, role);
    if (userId   != null) await prefs.setString(_PrefKeys.userId, userId);
    if (driverId != null) await prefs.setString(_PrefKeys.driverId, driverId);
  }

  Future<String?> getAccessToken()   async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.accessToken);
  Future<String?> getRefreshToken()  async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.refreshToken);
  Future<String?> getSavedRole()     async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.userRole);
  Future<String?> getSavedUserId()   async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.userId);
  Future<String?> getSavedDriverId() async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.driverId);

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefKeys.accessToken);
    await prefs.remove(_PrefKeys.refreshToken);
    await prefs.remove(_PrefKeys.userRole);
    await prefs.remove(_PrefKeys.userId);
    await prefs.remove(_PrefKeys.driverId);
  }

  // ══════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════
  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    required String userType,
    String? businessName,
    String? licenseNumber,
    String? licensePlate,
  }) async {
    try {
      final body = {
        'email': email, 'password': password,
        'firstName': firstName, 'lastName': lastName,
        'phoneNumber': phoneNumber, 'userType': userType,
        'businessName': businessName ?? '',
        'licenseNumber': licenseNumber ?? '',
        'licensePlate': licensePlate ?? '',
      };
      _log('REGISTER REQUEST', ApiConstants.register);
      final response = await http
          .post(Uri.parse(ApiConstants.register),
              headers: _jsonHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      _log('REGISTER RESPONSE', ApiConstants.register,
          status: response.statusCode, body: response.body);
      final resBody = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = _extract(resBody, ['token', 'access_token', 'accessToken']);
        if (token != null) {
          await saveTokens(
            accessToken: token,
            refreshToken: _extract(resBody, ['refreshToken', 'refresh_token']),
            role: _extract(resBody, ['role', 'userType'])?.toLowerCase(),
            userId: _extract(resBody, ['id', 'userId', 'sub']),
          );
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false,
          message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> uploadDriverDocument({
    required String driverId,
    required String documentType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse(
          '${ApiConstants.driverUploadDoc(driverId)}?documentType=$documentType');

      debugPrint('║ UPLOAD DOC URL: $uri');
      debugPrint('║ UPLOAD DOC fileName: $fileName');
      debugPrint('║ UPLOAD DOC fileSize: ${fileBytes.length} bytes');

      final request = http.MultipartRequest('POST', uri);
      final token = await getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
      }

      final ext = fileName.split('.').last.toLowerCase();
      String mimeType;
      String mimeSubtype;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image'; mimeSubtype = 'jpeg'; break;
        case 'png':
          mimeType = 'image'; mimeSubtype = 'png'; break;
        case 'pdf':
          mimeType = 'application'; mimeSubtype = 'pdf'; break;
        default:
          mimeType = 'image'; mimeSubtype = 'jpeg';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType(mimeType, mimeSubtype),
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      debugPrint('║ UPLOAD DOC STATUS: ${response.statusCode}');
      debugPrint('║ UPLOAD DOC RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const AuthResult(success: true);
      }
      return AuthResult(
        success: false,
        message: _errorMessage(_safeJsonDecode(response.body), response.statusCode),
      );
    } on Exception catch (e) {
      debugPrint('║ UPLOAD DOC EXCEPTION: $e');
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      _log('LOGIN REQUEST', ApiConstants.login, extra: 'email: $email');
      final response = await http
          .post(Uri.parse(ApiConstants.login),
              headers: _jsonHeaders,
              body: jsonEncode({'email': email, 'password': password}))
          .timeout(const Duration(seconds: 30));
      _log('LOGIN RESPONSE', ApiConstants.login,
          status: response.statusCode, body: response.body);
      final resBody = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = _extract(resBody,
            ['token', 'access_token', 'accessToken', 'data.token']);
        if (token != null) {
          await saveTokens(
            accessToken: token,
            refreshToken: _extract(resBody, ['refreshToken', 'refresh_token']),
            role: _extract(resBody, ['role', 'userType', 'user.role', 'data.role'])
                ?.toLowerCase(),
            userId: _extract(resBody, ['id', 'userId', 'user.id', 'sub']),
          );
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false,
          message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.me), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('PROFILE RESPONSE', ApiConstants.me,
          status: response.statusCode, body: response.body);
      final resBody = _safeJsonDecode(response.body);
      if (response.statusCode == 200) {
        final role = _extract(resBody, ['role', 'userType', 'user.role']);
        if (role != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_PrefKeys.userRole, role.toLowerCase());
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false,
          message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> resendVerification() async {
    try {
      final response = await http
          .post(Uri.parse(ApiConstants.resendVerification),
              headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return const AuthResult(success: true);
      }
      return AuthResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<void> logout() async {
    try {
      final rt = await getRefreshToken();
      await http
          .post(Uri.parse(ApiConstants.logout),
              headers: await _authHeaders,
              body: jsonEncode({'refreshToken': rt ?? ''}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      await clearTokens();
    }
  }

  // ══════════════════════════════════════════════════════
  //  DRIVER
  // ══════════════════════════════════════════════════════
  Future<AuthResult> getDriverProfile(String driverId) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.driverById(driverId)),
              headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      final resBody = _safeJsonDecode(response.body);
      if (response.statusCode == 200) {
        final id = _extract(resBody, ['id', 'driverId', 'data.id']);
        if (id != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_PrefKeys.driverId, id);
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false,
          message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> toggleDriverAvailability(String driverId) async {
    try {
      final response = await http
          .patch(Uri.parse(ApiConstants.driverToggle(driverId)),
              headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      final resBody = _safeJsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false,
          message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<AuthResult> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    double? speedKmh,
    double? headingDegrees,
    bool isActiveDelivery = false,
  }) async {
    try {
      final body = {
        'latitude': latitude, 'longitude': longitude,
        'accuracyMeters': accuracyMeters ?? 0,
        'speedKmh': speedKmh ?? 0,
        'headingDegrees': headingDegrees ?? 0,
        'isActiveDelivery': isActiveDelivery,
      };
      final response = await http
          .post(Uri.parse(ApiConstants.driverLocation(driverId)),
              headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const AuthResult(success: true);
      }
      return AuthResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  CART
  // ══════════════════════════════════════════════════════
  Future<ApiResult<Map<String, dynamic>>> getCart() async {
    try {
      _log('GET CART REQUEST', ApiConstants.cart);
      final response = await http
          .get(Uri.parse(ApiConstants.cart), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET CART RESPONSE', ApiConstants.cart,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<ApiResult<void>> clearCart() async {
    try {
      final response = await http
          .delete(Uri.parse(ApiConstants.cart), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> addCartItem({
    required String productId,
    required int quantity,
    String? specialInstructions,
  }) async {
    try {
      final body = {
        'productId': productId,
        'quantity': quantity,
        'specialInstructions': specialInstructions ?? '',
      };
      _log('ADD CART ITEM REQUEST', ApiConstants.cartItems,
          extra: 'productId: $productId | qty: $quantity');
      final response = await http
          .post(Uri.parse(ApiConstants.cartItems),
              headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      _log('ADD CART ITEM RESPONSE', ApiConstants.cartItems,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<ApiResult<Map<String, dynamic>>> updateCartItem({
    required String cartItemId,
    required int quantity,
    String? specialInstructions,
  }) async {
    try {
      final url = ApiConstants.cartItem(cartItemId);
      final body = {
        'quantity': quantity,
        'specialInstructions': specialInstructions ?? '',
      };
      final response = await http
          .put(Uri.parse(url), headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  Future<ApiResult<void>> removeCartItem(String cartItemId) async {
    try {
      final url = ApiConstants.cartItem(cartItemId);
      final response = await http
          .delete(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  ORDERS — BUYER
  // ══════════════════════════════════════════════════════

  /// POST /api/orders/checkout
  Future<ApiResult<Map<String, dynamic>>> checkout({
    required String deliveryAddressId,
    String? billingAddressId,
    String? specialInstructions,
    String? discountCode,
  }) async {
    try {
      final body = {
        'deliveryAddressId':   deliveryAddressId,
        'billingAddressId':    billingAddressId ?? deliveryAddressId,
        'specialInstructions': specialInstructions ?? '',
        'discountCode':        discountCode ?? '',
      };
      _log('CHECKOUT REQUEST', ApiConstants.ordersCheckout,
          extra: 'deliveryAddressId: $deliveryAddressId');
      final response = await http
          .post(Uri.parse(ApiConstants.ordersCheckout),
              headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      _log('CHECKOUT RESPONSE', ApiConstants.ordersCheckout,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/orders/my
  Future<ApiResult<Map<String, dynamic>>> getMyOrders({
    int? status,
    String? dateFrom,
    String? dateTo,
    int page     = 1,
    int pageSize = 10,
  }) async {
    try {
      final params = {
        'page': page.toString(), 'pageSize': pageSize.toString(),
        if (status   != null) 'status':   status.toString(),
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo   != null) 'dateTo':   dateTo,
      };
      final uri = Uri.parse(ApiConstants.myOrders).replace(queryParameters: params);
      _log('GET MY ORDERS REQUEST', uri.toString());
      final response = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET MY ORDERS RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/orders/my/{orderId}
  Future<ApiResult<Map<String, dynamic>>> getMyOrderById(String orderId) async {
    try {
      final url = ApiConstants.myOrderById(orderId);
      _log('GET ORDER DETAIL REQUEST', url);
      final response = await http
          .get(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET ORDER DETAIL RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// POST /api/orders/my/{orderId}/cancel
  Future<ApiResult<void>> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final url = ApiConstants.cancelOrder(orderId);
      _log('CANCEL ORDER REQUEST', url, extra: 'reason: $reason');
      final response = await http
          .post(Uri.parse(url),
              headers: await _authHeaders,
              body: jsonEncode({'reason': reason}))
          .timeout(const Duration(seconds: 30));
      _log('CANCEL ORDER RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/orders/my/analytics
  Future<ApiResult<Map<String, dynamic>>> getMyOrdersAnalytics() async {
    try {
      _log('GET MY ORDERS ANALYTICS REQUEST', ApiConstants.myOrdersAnalytics);
      final response = await http
          .get(Uri.parse(ApiConstants.myOrdersAnalytics),
              headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET MY ORDERS ANALYTICS RESPONSE', ApiConstants.myOrdersAnalytics,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  ORDERS — SUPPLIER
  // ══════════════════════════════════════════════════════

  /// GET /api/orders/supplier
  Future<ApiResult<Map<String, dynamic>>> getSupplierOrders({
    int? status,
    String? dateFrom,
    String? dateTo,
    int page     = 1,
    int pageSize = 10,
  }) async {
    try {
      final params = {
        'page': page.toString(), 'pageSize': pageSize.toString(),
        if (status   != null) 'status':   status.toString(),
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo   != null) 'dateTo':   dateTo,
      };
      final uri = Uri.parse(ApiConstants.supplierOrders)
          .replace(queryParameters: params);
      _log('GET SUPPLIER ORDERS REQUEST', uri.toString());
      final response = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET SUPPLIER ORDERS RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/orders/supplier/{orderId}
  Future<ApiResult<Map<String, dynamic>>> getSupplierOrderById(
      String orderId) async {
    try {
      final url = ApiConstants.supplierOrderById(orderId);
      _log('GET SUPPLIER ORDER DETAIL REQUEST', url);
      final response = await http
          .get(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET SUPPLIER ORDER DETAIL RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// PATCH /api/orders/supplier/{orderId}/items/{orderItemId}/status
  Future<ApiResult<void>> updateSupplierOrderItemStatus({
    required String orderId,
    required String orderItemId,
    required int    status,
  }) async {
    try {
      final url = ApiConstants.supplierOrderItemStatus(orderId, orderItemId);
      _log('UPDATE ORDER ITEM STATUS REQUEST', url,
          extra: 'status: $status');
      final response = await http
          .patch(Uri.parse(url),
              headers: await _authHeaders,
              body: jsonEncode({'status': status}))
          .timeout(const Duration(seconds: 30));
      _log('UPDATE ORDER ITEM STATUS RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/orders/supplier/analytics
  Future<ApiResult<Map<String, dynamic>>> getSupplierOrdersAnalytics({
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = <String, String>{
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo   != null) 'dateTo':   dateTo,
      };
      final uri = Uri.parse(ApiConstants.supplierOrdersAnalytics)
          .replace(queryParameters: params.isEmpty ? null : params);
      _log('GET SUPPLIER ANALYTICS REQUEST', uri.toString());
      final response = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET SUPPLIER ANALYTICS RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  CATEGORIES
  // ══════════════════════════════════════════════════════

  /// GET /api/categories
  Future<ApiResult<List<dynamic>>> getCategories({
    bool includeInactive = false,
    int? parentId,
  }) async {
    try {
      final params = {
        'includeInactive': includeInactive.toString(),
        if (parentId != null) 'parentId': parentId.toString(),
      };
      final uri = Uri.parse(ApiConstants.categories)
          .replace(queryParameters: params);
      _log('GET CATEGORIES REQUEST', uri.toString());
      final response = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET CATEGORIES RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        final decoded = _safeJsonDecodeAny(response.body);
        if (decoded is List) return ApiResult(success: true, data: decoded);
        if (decoded is Map<String, dynamic>) {
          final list = decoded['data'] ?? decoded['items'] ?? decoded['categories'];
          if (list is List) return ApiResult(success: true, data: list);
        }
        return const ApiResult(success: true, data: []);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/categories/{id}
  Future<ApiResult<Map<String, dynamic>>> getCategoryById(int id) async {
    try {
      final url = ApiConstants.categoryById(id);
      final response = await http
          .get(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  ADDRESSES
  // ══════════════════════════════════════════════════════

  /// GET /api/addresses
  Future<ApiResult<List<dynamic>>> getAddresses() async {
    try {
      _log('GET ADDRESSES REQUEST', ApiConstants.addresses);
      final response = await http
          .get(Uri.parse(ApiConstants.addresses), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET ADDRESSES RESPONSE', ApiConstants.addresses,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        final decoded = _safeJsonDecodeAny(response.body);
        if (decoded is List) return ApiResult(success: true, data: decoded);
        if (decoded is Map<String, dynamic>) {
          final list = decoded['data'] ?? decoded['items'] ?? decoded['addresses'];
          if (list is List) return ApiResult(success: true, data: list);
        }
        return const ApiResult(success: true, data: []);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// POST /api/addresses
  Future<ApiResult<Map<String, dynamic>>> createAddress({
    required String streetAddress,
    String? apartment,
    required String city,
    String? state,
    required String postalCode,
    String? country,
    int addressType  = 0,
    bool isDefault   = false,
    String? label,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = {
        'streetAddress': streetAddress, 'apartment': apartment ?? '',
        'city': city, 'state': state ?? '', 'postalCode': postalCode,
        'country': country ?? 'UK', 'addressType': addressType,
        'isDefault': isDefault, 'label': label ?? '',
        'latitude': latitude ?? 0.0, 'longitude': longitude ?? 0.0,
      };
      _log('CREATE ADDRESS REQUEST', ApiConstants.addresses);
      final response = await http
          .post(Uri.parse(ApiConstants.addresses),
              headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      _log('CREATE ADDRESS RESPONSE', ApiConstants.addresses,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// PUT /api/addresses/{id}
  Future<ApiResult<Map<String, dynamic>>> updateAddress({
    required String addressId,
    required String streetAddress,
    String? apartment,
    required String city,
    String? state,
    required String postalCode,
    String? country,
    int addressType  = 0,
    bool isDefault   = false,
    String? label,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final url  = ApiConstants.addressById(addressId);
      final body = {
        'streetAddress': streetAddress, 'apartment': apartment ?? '',
        'city': city, 'state': state ?? '', 'postalCode': postalCode,
        'country': country ?? 'UK', 'addressType': addressType,
        'isDefault': isDefault, 'label': label ?? '',
        'latitude': latitude ?? 0.0, 'longitude': longitude ?? 0.0,
      };
      _log('UPDATE ADDRESS REQUEST', url);
      final response = await http
          .put(Uri.parse(url), headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      _log('UPDATE ADDRESS RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// DELETE /api/addresses/{id}
  Future<ApiResult<void>> deleteAddress(String addressId) async {
    try {
      final url = ApiConstants.addressById(addressId);
      _log('DELETE ADDRESS REQUEST', url);
      final response = await http
          .delete(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('DELETE ADDRESS RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// PATCH /api/addresses/{id}/default
  Future<ApiResult<void>> setDefaultAddress(String addressId) async {
    try {
      final url = ApiConstants.addressDefault(addressId);
      _log('SET DEFAULT ADDRESS REQUEST', url);
      final response = await http
          .patch(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('SET DEFAULT ADDRESS RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  CATALOG
  // ══════════════════════════════════════════════════════

  /// GET /api/catalog/products
  Future<ApiResult<Map<String, dynamic>>> getCatalogProducts({
    String? search,
    int?    categoryId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? supplierId,
    int     page     = 1,
    int     pageSize = 10,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(), 'pageSize': pageSize.toString(),
        if (search     != null && search.isNotEmpty) 'search': search,
        if (categoryId != null) 'categoryId': categoryId.toString(),
        if (minPrice   != null) 'minPrice':   minPrice.toString(),
        if (maxPrice   != null) 'maxPrice':   maxPrice.toString(),
        if (minRating  != null) 'minRating':  minRating.toString(),
        if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
      };
      final uri = Uri.parse(ApiConstants.catalogProducts)
          .replace(queryParameters: params);
      _log('GET CATALOG PRODUCTS REQUEST', uri.toString());
      final response = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET CATALOG PRODUCTS RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        final decoded = _safeJsonDecodeAny(response.body);
        if (decoded is List) {
          return ApiResult(
              success: true,
              data: {'items': decoded, 'total': decoded.length});
        }
        if (decoded is Map<String, dynamic>) {
          return ApiResult(success: true, data: decoded);
        }
        return const ApiResult(
            success: true, data: {'items': [], 'total': 0});
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/catalog/products/{id}
  Future<ApiResult<Map<String, dynamic>>> getCatalogProductById(
      String id) async {
    try {
      final url = ApiConstants.catalogProductById(id);
      _log('GET CATALOG PRODUCT BY ID REQUEST', url);
      final response = await http
          .get(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET CATALOG PRODUCT BY ID RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// GET /api/catalog/filters
  Future<ApiResult<Map<String, dynamic>>> getCatalogFilters() async {
    try {
      _log('GET CATALOG FILTERS REQUEST', ApiConstants.catalogFilters);
      final response = await http
          .get(Uri.parse(ApiConstants.catalogFilters),
              headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('GET CATALOG FILTERS RESPONSE', ApiConstants.catalogFilters,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ══════════════════════════════════════════════════════
  //  PRODUCT IMAGES (Supplier)
  // ══════════════════════════════════════════════════════

  /// POST /api/products/{productId}/images
  /// Uploads an image for a product. Set [isPrimary] = true to make it
  /// the main display image.
  Future<ApiResult<Map<String, dynamic>>> uploadProductImage({
    required String productId,
    required List<int> fileBytes,
    required String fileName,
    String? altText,
    bool isPrimary = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'isPrimary': isPrimary.toString(),
        if (altText != null && altText.isNotEmpty) 'altText': altText,
      };
      final uri = Uri.parse(ApiConstants.productImages(productId))
          .replace(queryParameters: queryParams);

      _log('UPLOAD PRODUCT IMAGE REQUEST', uri.toString(),
          extra: 'fileName: $fileName | isPrimary: $isPrimary');

      final request = http.MultipartRequest('POST', uri);
      final token = await getAccessToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
      }

      final ext = fileName.split('.').last.toLowerCase();
      String mimeSubtype;
      switch (ext) {
        case 'png':  mimeSubtype = 'png';  break;
        case 'gif':  mimeSubtype = 'gif';  break;
        case 'webp': mimeSubtype = 'webp'; break;
        default:     mimeSubtype = 'jpeg';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', mimeSubtype),
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      _log('UPLOAD PRODUCT IMAGE RESPONSE', uri.toString(),
          status: response.statusCode, body: response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResult(success: true, data: _safeJsonDecode(response.body));
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  /// DELETE /api/products/{productId}/images/{imageId}
  Future<ApiResult<void>> deleteProductImage({
    required String productId,
    required int imageId,
  }) async {
    try {
      final url = ApiConstants.productImage(productId, imageId);
      _log('DELETE PRODUCT IMAGE REQUEST', url);
      final response = await http
          .delete(Uri.parse(url), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));
      _log('DELETE PRODUCT IMAGE RESPONSE', url,
          status: response.statusCode, body: response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return const ApiResult(success: true);
      }
      return ApiResult(success: false,
          message: _errorMessage(_safeJsonDecode(response.body), response.statusCode));
    } on Exception catch (e) {
      return ApiResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }
}