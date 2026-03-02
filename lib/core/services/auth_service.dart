import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
//  API constants
// ─────────────────────────────────────────────────────────
class ApiConstants {
  static const String baseUrl = 'https://api.neptasolutions.co.uk';

  // Auth
  static const String register           = '$baseUrl/api/auth/register';
  static const String login              = '$baseUrl/api/auth/login';
  static const String logout             = '$baseUrl/api/auth/logout';
  static const String refresh            = '$baseUrl/api/auth/refresh';
  static const String me                 = '$baseUrl/api/auth/me';
  static const String verifyEmail        = '$baseUrl/api/auth/verify-email';
  static const String resendVerification = '$baseUrl/api/auth/resend-verification';

  // Driver
  static String driverById(String id)      => '$baseUrl/api/Drivers/$id';
  static String driverToggle(String id)    => '$baseUrl/api/Drivers/$id/toggle-availability';
  static String driverStatus(String id)    => '$baseUrl/api/Drivers/$id/status';
  static String driverLocation(String id)  => '$baseUrl/api/Drivers/$id/location';
  static String driverUploadDoc(String id) => '$baseUrl/api/Drivers/$id/upload-document';
}

class _PrefKeys {
  static const String accessToken  = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userRole     = 'user_role';
  static const String userId       = 'user_id';
  static const String driverId     = 'driver_id';
}

class AuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const AuthResult({required this.success, this.message, this.data});
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

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

  Map<String, dynamic> _safeJsonDecode(String body) {
    try {
      if (body.trim().isEmpty) return {};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
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
      case 401: return 'Incorrect email or password.';
      case 403: return 'Access denied.';
      case 404: return 'Not found.';
      case 409: return 'An account with this email already exists.';
      case 422: return 'Validation failed. Please check your details.';
      case 500: return 'Server error. Please try again later.';
      default:  return 'Something went wrong (code $statusCode).';
    }
  }

  String _friendlyNetworkError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('TimeoutException')) return 'Request timed out. Please try again.';
    if (raw.contains('HandshakeException')) return 'Secure connection failed. Please try again.';
    return 'Network error. Please try again.';
  }

  // ── Token helpers ──────────────────────────────────────
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

  Future<String?> getAccessToken()  async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.accessToken);

  Future<String?> getRefreshToken() async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.refreshToken);

  Future<String?> getSavedRole()    async =>
      (await SharedPreferences.getInstance()).getString(_PrefKeys.userRole);

  Future<String?> getSavedUserId()  async =>
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

  // ── Register ───────────────────────────────────────────
  // API contract: email, password, firstName, lastName, phoneNumber,
  //               userType, businessName, licenseNumber, licensePlate
  //
  // CHANGES from previous version:
  //  • Removed licenseExpiryDate — not part of the API contract
  //  • Added businessName — always sent (empty string for non-suppliers)
  //  • licenseNumber and licensePlate always sent (empty string for non-drivers)
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
      // Always send every field the API expects — empty string if not applicable.
      // Sending unknown fields (like licenseExpiryDate) caused silent 500 crashes.
      final Map<String, dynamic> body = {
        'email':         email,
        'password':      password,
        'firstName':     firstName,
        'lastName':      lastName,
        'phoneNumber':   phoneNumber,
        'userType':      userType,
        'businessName':  businessName  ?? '',
        'licenseNumber': licenseNumber ?? '',
        'licensePlate':  licensePlate  ?? '',
      };

      final jsonString = jsonEncode(body);

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║         REGISTER REQUEST             ║');
      debugPrint('╠══════════════════════════════════════╣');
      debugPrint('║ URL : ${ApiConstants.register}');
      debugPrint('║ JSON: $jsonString');
      debugPrint('╚══════════════════════════════════════╝');

      final response = await http
          .post(
            Uri.parse(ApiConstants.register),
            headers: _jsonHeaders,
            body: jsonString,
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║         REGISTER RESPONSE            ║');
      debugPrint('║ STATUS : ${response.statusCode}');
      debugPrint('║ HEADERS: ${response.headers}');
      debugPrint('║ BODY   : "${response.body}"');
      debugPrint('╚══════════════════════════════════════╝');

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token        = _extract(resBody, ['token', 'access_token', 'accessToken', 'data.token', 'data.accessToken']);
        final refreshToken = _extract(resBody, ['refreshToken', 'refresh_token', 'data.refreshToken']);
        final role         = _extract(resBody, ['role', 'userType', 'data.role']);
        final userId       = _extract(resBody, ['id', 'userId', 'sub', 'data.id']);

        if (token != null) {
          await saveTokens(
            accessToken:  token,
            refreshToken: refreshToken,
            role:         role?.toLowerCase(),
            userId:       userId,
          );
        }
        return AuthResult(success: true, data: resBody);
      }

      if (response.statusCode == 500) {
        final serverMsg = _extract(resBody, ['message', 'error', 'detail', 'title']);
        final hint = serverMsg ??
            'Possible causes:\n'
            '• Email already registered\n'
            '• Phone number already in use\n'
            '• License plate / number already registered';
        return AuthResult(success: false, message: 'Server error (500).\n$hint');
      }

      return AuthResult(
        success: false,
        message: _errorMessage(resBody, response.statusCode),
      );
    } on Exception catch (e) {
      debugPrint('║ REGISTER EXCEPTION: $e');
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Login ──────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║           LOGIN REQUEST              ║');
      debugPrint('║   email: $email');
      debugPrint('╚══════════════════════════════════════╝');

      final response = await http
          .post(
            Uri.parse(ApiConstants.login),
            headers: _jsonHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║           LOGIN RESPONSE             ║');
      debugPrint('║ STATUS: ${response.statusCode}');
      debugPrint('║ BODY  : ${response.body.isEmpty ? "(EMPTY)" : response.body}');
      debugPrint('╚══════════════════════════════════════╝');

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token        = _extract(resBody, ['token', 'access_token', 'accessToken', 'data.token', 'data.accessToken']);
        final refreshToken = _extract(resBody, ['refreshToken', 'refresh_token', 'data.refreshToken']);
        final role         = _extract(resBody, ['role', 'userType', 'user.role', 'data.role']);
        final userId       = _extract(resBody, ['id', 'userId', 'user.id', 'sub']);

        debugPrint('║ TOKEN : $token');
        debugPrint('║ ROLE  : $role');

        if (token != null) {
          await saveTokens(
            accessToken:  token,
            refreshToken: refreshToken,
            role:         role?.toLowerCase(),
            userId:       userId,
          );
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      debugPrint('║ LOGIN EXCEPTION: $e');
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Get Profile (/api/auth/me) ─────────────────────────
  Future<AuthResult> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.me), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║          PROFILE RESPONSE            ║');
      debugPrint('║ STATUS: ${response.statusCode}');
      debugPrint('║ BODY  : ${response.body.isEmpty ? "(EMPTY)" : response.body}');
      debugPrint('╚══════════════════════════════════════╝');

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final role = _extract(resBody, ['role', 'userType', 'user.role', 'data.role']);
        if (role != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_PrefKeys.userRole, role.toLowerCase());
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Resend Verification ────────────────────────────────
  Future<AuthResult> resendVerification() async {
    try {
      final response = await http
          .post(Uri.parse(ApiConstants.resendVerification), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));

      debugPrint('║ RESEND STATUS: ${response.statusCode}');
      debugPrint('║ RESEND BODY  : ${response.body.isEmpty ? "(EMPTY)" : response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const AuthResult(success: true);
      }
      final resBody = _safeJsonDecode(response.body);
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      await http
          .post(
            Uri.parse(ApiConstants.logout),
            headers: await _authHeaders,
            body: jsonEncode({'refreshToken': refreshToken ?? ''}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      await clearTokens();
    }
  }

  // ── Driver Profile ─────────────────────────────────────
  Future<AuthResult> getDriverProfile(String driverId) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.driverById(driverId)), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║       DRIVER PROFILE RESPONSE        ║');
      debugPrint('║ STATUS: ${response.statusCode}');
      debugPrint('║ BODY  : ${response.body.isEmpty ? "(EMPTY)" : response.body}');
      debugPrint('╚══════════════════════════════════════╝');

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final id = _extract(resBody, ['id', 'driverId', 'data.id']);
        if (id != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_PrefKeys.driverId, id);
        }
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Toggle Driver Availability ─────────────────────────
  Future<AuthResult> toggleDriverAvailability(String driverId) async {
    try {
      final response = await http
          .patch(Uri.parse(ApiConstants.driverToggle(driverId)), headers: await _authHeaders)
          .timeout(const Duration(seconds: 30));

      debugPrint('\n╔══════════════════════════════════════╗');
      debugPrint('║      TOGGLE AVAILABILITY RESPONSE    ║');
      debugPrint('║ STATUS: ${response.statusCode}');
      debugPrint('║ BODY  : ${response.body.isEmpty ? "(EMPTY)" : response.body}');
      debugPrint('╚══════════════════════════════════════╝');

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return AuthResult(success: true, data: resBody);
      }
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }

  // ── Update Driver Location ─────────────────────────────
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
        'latitude':         latitude,
        'longitude':        longitude,
        'accuracyMeters':   accuracyMeters ?? 0,
        'speedKmh':         speedKmh ?? 0,
        'headingDegrees':   headingDegrees ?? 0,
        'isActiveDelivery': isActiveDelivery,
      };

      final response = await http
          .post(
            Uri.parse(ApiConstants.driverLocation(driverId)),
            headers: await _authHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final resBody = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return const AuthResult(success: true);
      }
      return AuthResult(success: false, message: _errorMessage(resBody, response.statusCode));
    } on Exception catch (e) {
      return AuthResult(success: false, message: _friendlyNetworkError(e.toString()));
    }
  }
}